# -*- coding: utf-8 -*-
"""
Kimberley N5 — terminal local de análisis táctico-sociológico en video.
Todo corre en localhost, sin servicios externos. El video nunca sale del
navegador: se carga con la File API y se reproduce como blob local: la app
solo guarda su nombre de archivo en la sesión para referencia y export.
"""
import csv
import io
import json
import os
import re
import shutil
import subprocess
import tempfile
import unicodedata
import zipfile

from flask import Flask, jsonify, render_template, request, Response

import database as db

app = Flask(__name__)

# Única carpeta donde se buscan videos para cortar clips con FFmpeg.
VIDEO_DIR = os.path.join(os.path.dirname(__file__), "videos")


@app.route("/")
def index():
    return render_template("index.html")


# --- Taxonomía ---------------------------------------------------------

@app.route("/api/taxonomia")
def api_taxonomia():
    return jsonify({
        "categorias": db.CATEGORIAS,
        "resultados": db.RESULTADOS,
        "contextos": db.CONTEXTOS,
    })


# --- Sesiones ------------------------------------------------------------

@app.route("/api/sesiones", methods=["GET", "POST"])
def api_sesiones():
    if request.method == "POST":
        datos = request.get_json(force=True)
        for campo in ("partido", "fecha", "rival"):
            if not datos.get(campo):
                return jsonify({"error": f"Falta el campo '{campo}'"}), 400
        sesion_id = db.crear_sesion(
            datos["partido"], datos["fecha"], datos["rival"],
            datos.get("video_archivo", ""),
        )
        return jsonify({"id": sesion_id}), 201
    return jsonify(db.listar_sesiones())


@app.route("/api/sesiones/<int:sesion_id>")
def api_sesion_detalle(sesion_id):
    sesion = db.obtener_sesion(sesion_id)
    if not sesion:
        return jsonify({"error": "Sesión no encontrada"}), 404
    eventos = db.listar_eventos(sesion_id)
    return jsonify({
        "sesion": sesion,
        "eventos": eventos,
        "contadores_categoria": db.contar_por_categoria(sesion_id),
        "contadores_zona": db.contar_por_zona(sesion_id),
    })


@app.route("/api/sesiones/<int:sesion_id>/video", methods=["PUT"])
def api_sesion_video(sesion_id):
    datos = request.get_json(force=True)
    db.actualizar_video_sesion(sesion_id, datos.get("video_archivo", ""))
    return jsonify({"ok": True})


# --- Eventos ------------------------------------------------------------

def _validar_evento(datos):
    requeridos = ["timestamp_seg", "timestamp_fmt", "categoria", "subcategoria", "resultado", "contexto"]
    faltantes = [c for c in requeridos if not str(datos.get(c, "")).strip() and datos.get(c) != 0]
    return faltantes


@app.route("/api/sesiones/<int:sesion_id>/eventos", methods=["POST"])
def api_crear_evento(sesion_id):
    if not db.obtener_sesion(sesion_id):
        return jsonify({"error": "Sesión no encontrada"}), 404
    datos = request.get_json(force=True)
    faltantes = _validar_evento(datos)
    if faltantes:
        return jsonify({"error": f"Faltan campos: {', '.join(faltantes)}"}), 400
    evento_id = db.crear_evento(sesion_id, datos)
    return jsonify({"id": evento_id}), 201


@app.route("/api/eventos/<int:evento_id>", methods=["PUT", "DELETE"])
def api_evento(evento_id):
    if not db.obtener_evento(evento_id):
        return jsonify({"error": "Evento no encontrado"}), 404
    if request.method == "DELETE":
        db.eliminar_evento(evento_id)
        return jsonify({"ok": True})
    datos = request.get_json(force=True)
    db.actualizar_evento(evento_id, datos)
    return jsonify({"ok": True})


# --- Exportación ----------------------------------------------------------

def _rival_seguro(rival):
    return re.sub(r"[^A-Za-z0-9_-]+", "_", rival).strip("_") or "Rival"


def _nombre_archivo(rival, fecha, extension):
    return f"Kimberley_N5_{_rival_seguro(rival)}_{fecha}.{extension}"


COLUMNAS_CSV = [
    "sesion_id", "partido", "fecha", "rival", "video_archivo",
    "timestamp_seg", "timestamp_fmt", "minuto_partido",
    "categoria", "subcategoria", "zona", "resultado", "contexto", "memo",
    "creado_en",
]


@app.route("/api/sesiones/<int:sesion_id>/export/csv")
def api_export_csv(sesion_id):
    sesion = db.obtener_sesion(sesion_id)
    if not sesion:
        return jsonify({"error": "Sesión no encontrada"}), 404
    eventos = db.listar_eventos(sesion_id)

    buffer = io.StringIO()
    writer = csv.DictWriter(buffer, fieldnames=COLUMNAS_CSV)
    writer.writeheader()
    for ev in eventos:
        fila = {
            "sesion_id": sesion_id, "partido": sesion["partido"], "fecha": sesion["fecha"],
            "rival": sesion["rival"], "video_archivo": sesion["video_archivo"],
            "timestamp_seg": ev["timestamp_seg"], "timestamp_fmt": ev["timestamp_fmt"],
            "minuto_partido": ev["minuto_partido"], "categoria": ev["categoria"],
            "subcategoria": ev["subcategoria"], "zona": ev["zona"], "resultado": ev["resultado"],
            "contexto": ev["contexto"], "memo": ev["memo"], "creado_en": ev["creado_en"],
        }
        writer.writerow(fila)

    # utf-8-sig antepone el BOM que espera read.csv() en R para acentos/ñ.
    cuerpo = buffer.getvalue().encode("utf-8-sig")
    nombre = _nombre_archivo(sesion["rival"], sesion["fecha"], "csv")
    return Response(
        cuerpo, mimetype="text/csv",
        headers={"Content-Disposition": f'attachment; filename="{nombre}"'},
    )


@app.route("/api/sesiones/<int:sesion_id>/export/json")
def api_export_json(sesion_id):
    sesion = db.obtener_sesion(sesion_id)
    if not sesion:
        return jsonify({"error": "Sesión no encontrada"}), 404
    eventos = db.listar_eventos(sesion_id)
    respaldo = {"sesion": sesion, "eventos": eventos}
    nombre = _nombre_archivo(sesion["rival"], sesion["fecha"], "json")
    return Response(
        json.dumps(respaldo, ensure_ascii=False, indent=2).encode("utf-8"),
        mimetype="application/json",
        headers={"Content-Disposition": f'attachment; filename="{nombre}"'},
    )


# --- Clips de video (FFmpeg) ------------------------------------------

def _ffmpeg_disponible():
    return shutil.which("ffmpeg") is not None


def _resolver_video_sesion(sesion_id):
    """Busca el video de una sesión en VIDEO_DIR. Devuelve (ruta, error)."""
    sesion = db.obtener_sesion(sesion_id)
    if not sesion or not sesion.get("video_archivo"):
        return None, "Esta sesión no tiene un archivo de video asociado."
    ruta = os.path.join(VIDEO_DIR, sesion["video_archivo"])
    if not os.path.isfile(ruta):
        return None, "Video no encontrado en videos/. Mueve el archivo ahí."
    return ruta, None


MENSAJE_SIN_DURACION = (
    "Este evento no tiene duración marcada. "
    "Usa las teclas I y O para marcar entrada y salida."
)


def _duracion_evento(evento):
    """
    Devuelve (in_point, out_point, duracion, error). `error` viene con el
    mensaje listo para el usuario si el evento no tiene in/out marcados o
    si out no quedó después de in (evento puntual, sin duración).
    """
    in_point = evento["in_point_seg"]
    out_point = evento["out_point_seg"]
    if in_point is None or out_point is None or float(in_point) == float(out_point):
        return None, None, None, MENSAJE_SIN_DURACION
    in_point, out_point = float(in_point), float(out_point)
    if out_point < in_point:
        return None, None, None, MENSAJE_SIN_DURACION
    return in_point, out_point, out_point - in_point, None


def _quitar_acentos(texto):
    return "".join(c for c in unicodedata.normalize("NFKD", texto) if not unicodedata.combining(c))


def _nombre_clip(evento):
    # Espacios, /, : y . se reemplazan por guiones en la categoría, como
    # se pidió; además se quitan tildes para que el nombre del archivo
    # quede prolijo y sin sorpresas de encoding en la descarga.
    categoria_segura = re.sub(r"[\s/:.]+", "-", _quitar_acentos(evento["categoria"] or ""))
    categoria_segura = re.sub(r"[^A-Za-z0-9-]+", "", categoria_segura).strip("-") or "cat"
    zona_segura = re.sub(r"[^A-Za-z0-9_-]+", "_", evento["zona"] or "").strip("_") or "sz"
    in_fmt_seguro = re.sub(r"[:.]", "-", evento["timestamp_fmt"])
    return f"clip_{evento['id']}_{categoria_segura}_{zona_segura}_{in_fmt_seguro}.mp4"


def _cortar_clip_ffmpeg(ruta_video, in_point, duracion, ruta_salida):
    """
    Corta un clip con FFmpeg. Lanza RuntimeError con mensaje legible si falla.

    Re-codifica en vez de usar "-c copy": probado contra el video real de
    Kimberley, "-c copy" no puede arrancar a mitad de un GOP, así que el
    clip empezaba en el keyframe anterior (hasta ~5s antes de lo pedido)
    y terminaba igual de largo, dando duraciones de ~10s en vez de 5s.
    Re-codificar con preset rápido sí respeta el timestamp exacto, y para
    un clip de unos segundos el costo es menor a un segundo de CPU.
    """
    comando = [
        "ffmpeg", "-y",
        "-ss", str(in_point),
        "-i", ruta_video,
        "-t", str(duracion),
        "-c:v", "libx264", "-preset", "veryfast", "-crf", "20",
        "-c:a", "aac",
        "-avoid_negative_ts", "make_zero",
        ruta_salida,
    ]
    try:
        resultado = subprocess.run(comando, capture_output=True, text=True, timeout=60)
    except subprocess.TimeoutExpired:
        raise RuntimeError("FFmpeg tardó demasiado y se canceló el corte del clip.")
    if resultado.returncode != 0:
        lineas = resultado.stderr.strip().splitlines()
        detalle = lineas[-1] if lineas else "error desconocido"
        raise RuntimeError(f"FFmpeg no pudo cortar el clip ({detalle}).")


@app.route("/api/eventos/<int:evento_id>/clip")
def api_evento_clip(evento_id):
    if not _ffmpeg_disponible():
        return jsonify({"error": "FFmpeg no está disponible en este sistema. Instalalo y reiniciá la app."}), 503

    evento = db.obtener_evento(evento_id)
    if not evento:
        return jsonify({"error": "Evento no encontrado"}), 404

    in_point, out_point, duracion, error = _duracion_evento(evento)
    if error:
        return jsonify({"error": error}), 400

    ruta_video, error = _resolver_video_sesion(evento["sesion_id"])
    if error:
        return jsonify({"error": error}), 404

    carpeta_clips = os.path.join(VIDEO_DIR, "clips")
    os.makedirs(carpeta_clips, exist_ok=True)
    nombre_salida = _nombre_clip(evento)
    ruta_salida = os.path.join(carpeta_clips, nombre_salida)

    try:
        _cortar_clip_ffmpeg(ruta_video, in_point, duracion, ruta_salida)
        with open(ruta_salida, "rb") as f:
            contenido = f.read()
    except RuntimeError as e:
        return jsonify({"error": str(e)}), 500
    finally:
        if os.path.exists(ruta_salida):
            os.remove(ruta_salida)

    return Response(
        contenido, mimetype="video/mp4",
        headers={"Content-Disposition": f'attachment; filename="{nombre_salida}"'},
    )


@app.route("/api/sesiones/<int:sesion_id>/clips/zip")
def api_sesion_clips_zip(sesion_id):
    if not _ffmpeg_disponible():
        return jsonify({"error": "FFmpeg no está disponible en este sistema. Instalalo y reiniciá la app."}), 503

    sesion = db.obtener_sesion(sesion_id)
    if not sesion:
        return jsonify({"error": "Sesión no encontrada"}), 404

    ruta_video, error = _resolver_video_sesion(sesion_id)
    if error:
        return jsonify({"error": error}), 404

    # Solo entran los eventos con salida marcada después de la entrada.
    todos = db.listar_eventos(sesion_id)
    eventos_con_clip = []
    for ev in todos:
        in_point, out_point, duracion, error_dur = _duracion_evento(ev)
        if not error_dur:
            eventos_con_clip.append((ev, in_point, duracion))
    if not eventos_con_clip:
        return jsonify({"error": "Ningún evento tiene duración marcada."}), 400

    buffer_zip = io.BytesIO()
    errores = []
    with zipfile.ZipFile(buffer_zip, "w", zipfile.ZIP_DEFLATED) as zf:
        for ev, in_point, duracion in eventos_con_clip:
            nombre_clip = _nombre_clip(ev)

            fd, ruta_tmp = tempfile.mkstemp(suffix=".mp4")
            os.close(fd)
            try:
                _cortar_clip_ffmpeg(ruta_video, in_point, duracion, ruta_tmp)
                with open(ruta_tmp, "rb") as f:
                    zf.writestr(nombre_clip, f.read())
            except RuntimeError as e:
                errores.append(f"{nombre_clip}: {e}")
            finally:
                if os.path.exists(ruta_tmp):
                    os.remove(ruta_tmp)
        if errores:
            zf.writestr("_errores.txt", "\n".join(errores))

    buffer_zip.seek(0)
    nombre_zip = f"Kimberley_N5_{_rival_seguro(sesion['rival'])}_{sesion['fecha']}_clips.zip"
    return Response(
        buffer_zip.getvalue(), mimetype="application/zip",
        headers={"Content-Disposition": f'attachment; filename="{nombre_zip}"'},
    )


if __name__ == "__main__":
    db.init_db()
    app.run(debug=True, port=int(os.environ.get("PORT", 5000)))

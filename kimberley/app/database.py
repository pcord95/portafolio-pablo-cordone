# -*- coding: utf-8 -*-
"""
Capa de persistencia SQLite para Kimberley N5.
Una sesión = un partido analizado. Cada sesión tiene N eventos.
"""
import sqlite3
import os
from datetime import datetime

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
DB_PATH = os.path.join(BASE_DIR, "data", "sessions.db")

# ---------------------------------------------------------------------------
# TAXONOMÍA DE EVENTOS
# Reconciliada con la pizarra de ETData y con las columnas
# que usa el índice de acciones de ETData (IAV) (interceptions, aerial_won, clearances,
# tackles, ball_recoveries, possession_lost, dispossessed, passes_acc,
# passes_total, duels_won, shots_on_target). Las variantes exitoso/fallido y
# ganado/perdido de la pizarra se capturan en el campo `resultado`, no en la
# subcategoría, para no duplicar información.
# ---------------------------------------------------------------------------
CATEGORIAS = {
    "1": {
        "nombre": "Acciones Defensivas",
        "subcategorias": [
            "Tackle", "Intercepción", "Duelo aéreo", "Duelo terrestre",
            "Despeje", "Bloqueo",
        ],
    },
    "2": {
        "nombre": "Acciones con Balón",
        "subcategorias": [
            "Pase corto", "Pase largo", "Pase filtrado",
            "Recepción libre", "Recepción bajo presión",
            "Conducción", "Pérdida de balón", "Remate",
        ],
    },
    "3": {
        "nombre": "Posicionamiento sin Balón",
        "subcategorias": [
            "Cobertura defensiva", "Marca al hombre",
            "Ajuste de línea defensiva",
            "Posición adelantada respecto al bloque",
            "Posición retrasada respecto al bloque",
        ],
    },
    "4": {
        "nombre": "Comunicación y Liderazgo",
        "subcategorias": [
            "Indicación verbal a compañeros",
            "Organización defensiva (gestos)",
            "Reacción tras error propio",
            "Reacción tras error de compañero",
        ],
    },
    "5": {
        "nombre": "Pressing y Transiciones",
        "subcategorias": [
            "Pressing trigger", "Transición defensa → ataque",
            "Transición ataque → defensa", "Recuperación de posición",
        ],
    },
}

RESULTADOS = ["positivo", "neutro", "negativo"]
CONTEXTOS = ["con balón propio", "sin balón", "balón dividido", "pelota parada"]

# Mapeo de referencia para una futura agregación hacia el motor de ETData.
# No se usa en el registro de eventos; documenta cómo cada subcategoría
# alimentaría las columnas del IAV (motor de ETData) cuando se agreguen
# los eventos crudos a nivel de sesión/partido.
MAPEO_IAV_FUTURO = {
    "Tackle": "tackles",
    "Intercepción": "interceptions",
    "Duelo aéreo": "aerial_won",
    "Duelo terrestre": "duels_won",
    "Despeje": "clearances",
    "Pase corto": "passes_total", "Pase largo": "passes_total",
    "Pase filtrado": "key_passes",
    "Pérdida de balón": "possession_lost",
    "Remate": "shots_on_target",
    "Recuperación de posición": "ball_recoveries",
}


def get_db():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON")
    return conn


def init_db():
    os.makedirs(os.path.dirname(DB_PATH), exist_ok=True)
    conn = get_db()
    conn.executescript(
        """
        CREATE TABLE IF NOT EXISTS sesiones (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            partido TEXT NOT NULL,
            fecha TEXT NOT NULL,
            rival TEXT NOT NULL,
            video_archivo TEXT,
            creado_en TEXT NOT NULL,
            actualizado_en TEXT NOT NULL
        );

        CREATE TABLE IF NOT EXISTS eventos (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            sesion_id INTEGER NOT NULL,
            timestamp_seg REAL NOT NULL,
            timestamp_fmt TEXT NOT NULL,
            minuto_partido TEXT,
            categoria TEXT NOT NULL,
            subcategoria TEXT NOT NULL,
            zona TEXT,
            resultado TEXT NOT NULL,
            contexto TEXT NOT NULL,
            memo TEXT,
            creado_en TEXT NOT NULL,
            in_point_seg REAL,
            out_point_seg REAL,
            FOREIGN KEY (sesion_id) REFERENCES sesiones(id) ON DELETE CASCADE
        );
        """
    )
    conn.commit()
    # Migración para bases ya existentes (creadas antes de in_point_seg/
    # out_point_seg): la sentencia CREATE TABLE de arriba no las agrega
    # porque IF NOT EXISTS no toca una tabla que ya existe. Se agregan acá
    # a mano, ignorando el error si ya estuvieran (SQLite no soporta
    # "ADD COLUMN IF NOT EXISTS"). Los eventos ya guardados quedan con
    # NULL en estos campos — no se pierde ni se rompe nada existente.
    _agregar_columna_si_falta(conn, "eventos", "in_point_seg", "REAL")
    _agregar_columna_si_falta(conn, "eventos", "out_point_seg", "REAL")
    conn.close()


def _agregar_columna_si_falta(conn, tabla, columna, tipo):
    try:
        conn.execute(f"ALTER TABLE {tabla} ADD COLUMN {columna} {tipo}")
        conn.commit()
    except sqlite3.OperationalError as e:
        if "duplicate column name" not in str(e):
            raise


def _now():
    return datetime.now().isoformat(timespec="seconds")


# --- Sesiones ---------------------------------------------------------------

def crear_sesion(partido, fecha, rival, video_archivo):
    conn = get_db()
    cur = conn.execute(
        "INSERT INTO sesiones (partido, fecha, rival, video_archivo, creado_en, actualizado_en) "
        "VALUES (?, ?, ?, ?, ?, ?)",
        (partido, fecha, rival, video_archivo, _now(), _now()),
    )
    conn.commit()
    sesion_id = cur.lastrowid
    conn.close()
    return sesion_id


def listar_sesiones():
    conn = get_db()
    filas = conn.execute(
        """
        SELECT s.*, COUNT(e.id) AS total_eventos
        FROM sesiones s
        LEFT JOIN eventos e ON e.sesion_id = s.id
        GROUP BY s.id
        ORDER BY s.actualizado_en DESC
        """
    ).fetchall()
    conn.close()
    return [dict(f) for f in filas]


def obtener_sesion(sesion_id):
    conn = get_db()
    fila = conn.execute("SELECT * FROM sesiones WHERE id = ?", (sesion_id,)).fetchone()
    conn.close()
    return dict(fila) if fila else None


def actualizar_video_sesion(sesion_id, video_archivo):
    conn = get_db()
    conn.execute(
        "UPDATE sesiones SET video_archivo = ?, actualizado_en = ? WHERE id = ?",
        (video_archivo, _now(), sesion_id),
    )
    conn.commit()
    conn.close()


# --- Eventos ------------------------------------------------------------

def crear_evento(sesion_id, datos):
    conn = get_db()
    cur = conn.execute(
        """
        INSERT INTO eventos (
            sesion_id, timestamp_seg, timestamp_fmt, minuto_partido,
            categoria, subcategoria, zona, resultado, contexto, memo, creado_en,
            in_point_seg, out_point_seg
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        (
            sesion_id, datos["timestamp_seg"], datos["timestamp_fmt"],
            datos.get("minuto_partido", ""), datos["categoria"], datos["subcategoria"],
            datos.get("zona", ""), datos["resultado"], datos["contexto"],
            datos.get("memo", ""), _now(),
            datos.get("in_point_seg"), datos.get("out_point_seg"),
        ),
    )
    conn.execute(
        "UPDATE sesiones SET actualizado_en = ? WHERE id = ?", (_now(), sesion_id)
    )
    conn.commit()
    evento_id = cur.lastrowid
    conn.close()
    return evento_id


def listar_eventos(sesion_id):
    conn = get_db()
    filas = conn.execute(
        "SELECT * FROM eventos WHERE sesion_id = ? ORDER BY timestamp_seg ASC",
        (sesion_id,),
    ).fetchall()
    conn.close()
    return [dict(f) for f in filas]


def obtener_evento(evento_id):
    conn = get_db()
    fila = conn.execute("SELECT * FROM eventos WHERE id = ?", (evento_id,)).fetchone()
    conn.close()
    return dict(fila) if fila else None


def actualizar_evento(evento_id, datos):
    conn = get_db()
    campos = [
        "timestamp_seg", "timestamp_fmt", "minuto_partido", "categoria",
        "subcategoria", "zona", "resultado", "contexto", "memo",
        "in_point_seg", "out_point_seg",
    ]
    asignaciones = ", ".join(f"{c} = ?" for c in campos if c in datos)
    valores = [datos[c] for c in campos if c in datos]
    if not asignaciones:
        conn.close()
        return
    valores.append(evento_id)
    conn.execute(f"UPDATE eventos SET {asignaciones} WHERE id = ?", valores)
    conn.commit()
    conn.close()


def eliminar_evento(evento_id):
    conn = get_db()
    conn.execute("DELETE FROM eventos WHERE id = ?", (evento_id,))
    conn.commit()
    conn.close()


def contar_por_categoria(sesion_id):
    conn = get_db()
    filas = conn.execute(
        "SELECT categoria, COUNT(*) AS total FROM eventos WHERE sesion_id = ? GROUP BY categoria",
        (sesion_id,),
    ).fetchall()
    conn.close()
    return {f["categoria"]: f["total"] for f in filas}


def contar_por_zona(sesion_id):
    conn = get_db()
    filas = conn.execute(
        "SELECT zona, COUNT(*) AS total FROM eventos WHERE sesion_id = ? AND zona != '' GROUP BY zona",
        (sesion_id,),
    ).fetchall()
    conn.close()
    return {f["zona"]: f["total"] for f in filas}

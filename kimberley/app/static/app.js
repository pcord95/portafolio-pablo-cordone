// Lógica de la terminal: sesiones, video, formulario de eventos, atajos, tabla.

let TAXONOMIA = null;
let sesionActual = null;
let eventosCache = [];
let editandoEventoId = null;
let videoEstabaReproduciendo = false;
let videoFilePendiente = null; // File capturado en la creación de sesión, para auto-bindear

// Estado del selector de rango (manijas del seekbar). Vive fuera del
// formulario a propósito: se puede seguir arrastrando/marcando con I y O
// aunque el panel de "nuevo evento" esté abierto (PASO 6).
let handleIn = 0;
let handleOut = 0;
let previewActivo = false;
let pausadoPorPreview = false; // distingue "pausó el preview" de "pausó el usuario"

const $ = (sel) => document.querySelector(sel);
const $$ = (sel) => document.querySelectorAll(sel);

// ---------------------------------------------------------------------
// Arranque
// ---------------------------------------------------------------------
document.addEventListener("DOMContentLoaded", async () => {
    TAXONOMIA = await (await fetch("/api/taxonomia")).json();
    poblarSelectCategoria();
    poblarSelectContexto();
    await cargarListaSesiones();
    crearCancha($("#pitch-container"), onZonaSeleccionada);

    document.getElementById("form-nueva-sesion").addEventListener("submit", crearSesion);
    document.getElementById("btn-volver").addEventListener("click", volverASesiones);
    document.getElementById("input-video-local").addEventListener("change", (e) => bindearVideo(e.target.files[0]));

    document.getElementById("btn-play-pause").addEventListener("click", togglePlayPause);
    document.getElementById("select-velocidad").addEventListener("change", (e) => {
        video().playbackRate = parseFloat(e.target.value);
    });
    document.getElementById("btn-back1").addEventListener("click", () => saltar(-1));
    document.getElementById("btn-fwd1").addEventListener("click", () => saltar(1));
    document.getElementById("btn-back5").addEventListener("click", () => saltar(-5));
    document.getElementById("btn-fwd5").addEventListener("click", () => saltar(5));
    document.getElementById("btn-nuevo-evento").addEventListener("click", () => abrirFormulario());

    document.getElementById("form-evento").addEventListener("submit", guardarEvento);
    document.getElementById("btn-cancelar-evento").addEventListener("click", cerrarFormulario);
    document.getElementById("ev-categoria").addEventListener("change", poblarSelectSubcategoria);
    $$(".opcion-btn").forEach((btn) => btn.addEventListener("click", () => seleccionarResultado(btn.dataset.valor)));
    inicializarSeekbar();

    document.getElementById("btn-export-csv").addEventListener("click", () => {
        if (sesionActual) window.location.href = `/api/sesiones/${sesionActual.id}/export/csv`;
    });
    document.getElementById("btn-export-json").addEventListener("click", () => {
        if (sesionActual) window.location.href = `/api/sesiones/${sesionActual.id}/export/json`;
    });
    document.getElementById("btn-descargar-clips").addEventListener("click", async (e) => {
        if (!sesionActual) return;
        await descargarConEstado(e.currentTarget, `/api/sesiones/${sesionActual.id}/clips/zip`, "clips.zip");
    });

    document.addEventListener("keydown", manejarAtajos);
});

function video() {
    return document.getElementById("video-player");
}

// ---------------------------------------------------------------------
// Pantalla de sesiones
// ---------------------------------------------------------------------
async function cargarListaSesiones() {
    const sesiones = await (await fetch("/api/sesiones")).json();
    const cont = document.getElementById("lista-sesiones");
    if (sesiones.length === 0) {
        cont.innerHTML = '<p class="muted">Todavía no hay sesiones. Creá la primera a la derecha.</p>';
        return;
    }
    cont.innerHTML = "";
    sesiones.forEach((s) => {
        const div = document.createElement("div");
        div.className = "sesion-item";
        div.innerHTML = `
            <div>
                <strong>${escapeHtml(s.partido)}</strong>
                <div class="muted">${escapeHtml(s.fecha)} · vs ${escapeHtml(s.rival)} · ${s.total_eventos} eventos</div>
                <div class="muted mini">video: ${escapeHtml(s.video_archivo || "—")}</div>
            </div>
            <button class="btn-secondary">Continuar</button>
        `;
        div.querySelector("button").addEventListener("click", () => abrirSesion(s.id));
        cont.appendChild(div);
    });
}

async function crearSesion(e) {
    e.preventDefault();
    const archivo = document.getElementById("ns-video").files[0];
    const body = {
        partido: document.getElementById("ns-partido").value,
        fecha: document.getElementById("ns-fecha").value,
        rival: document.getElementById("ns-rival").value,
        video_archivo: archivo ? archivo.name : "",
    };
    const resp = await fetch("/api/sesiones", {
        method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(body),
    });
    if (!resp.ok) { alert("No se pudo crear la sesión."); return; }
    const { id } = await resp.json();
    videoFilePendiente = archivo || null;
    e.target.reset();
    await abrirSesion(id);
}

async function abrirSesion(id) {
    await cargarSesion(id);
    document.getElementById("screen-sesiones").classList.add("hidden");
    document.getElementById("screen-analisis").classList.remove("hidden");

    document.getElementById("video-loader").classList.remove("hidden");
    document.getElementById("video-wrapper").classList.add("hidden");
    if (videoFilePendiente) {
        bindearVideo(videoFilePendiente);
        videoFilePendiente = null;
    }
}

function volverASesiones() {
    video().pause();
    video().removeAttribute("src");
    document.getElementById("screen-analisis").classList.add("hidden");
    document.getElementById("screen-sesiones").classList.remove("hidden");
    cargarListaSesiones();
}

// ---------------------------------------------------------------------
// Carga de datos de sesión
// ---------------------------------------------------------------------
async function cargarSesion(id) {
    const data = await (await fetch(`/api/sesiones/${id}`)).json();
    sesionActual = data.sesion;
    eventosCache = data.eventos;
    document.getElementById("titulo-sesion").textContent =
        `${sesionActual.partido} · ${sesionActual.fecha} vs ${sesionActual.rival}`;
    renderContadores(data.contadores_categoria);
    actualizarContadoresZona(data.contadores_zona);
    renderTabla();
}

async function refrescarSesion() {
    if (sesionActual) await cargarSesion(sesionActual.id);
}

function renderContadores(contadoresCategoria) {
    const total = eventosCache.length;
    document.getElementById("contador-total").textContent = `${total} evento${total === 1 ? "" : "s"}`;
    const hayAlgunClip = eventosCache.some((ev) => duracionSegundos(ev) != null);
    document.getElementById("btn-descargar-clips").classList.toggle("hidden", !hayAlgunClip);

    const cont = document.getElementById("contadores-categoria");
    cont.innerHTML = "";
    Object.entries(TAXONOMIA.categorias).forEach(([key, cat]) => {
        const n = contadoresCategoria[cat.nombre] || 0;
        const row = document.createElement("div");
        row.className = "contador-fila";
        row.innerHTML = `<span>${key}. ${cat.nombre}</span><strong>${n}</strong>`;
        cont.appendChild(row);
    });
}

function renderTabla() {
    const body = document.getElementById("tabla-eventos-body");
    body.innerHTML = "";
    eventosCache.forEach((ev) => {
        const duracion = duracionSegundos(ev);
        const tr = document.createElement("tr");
        tr.innerHTML = `
            <td class="mono celda-time">${ev.timestamp_fmt}</td>
            <td>${escapeHtml(ev.minuto_partido || "")}</td>
            <td>${escapeHtml(ev.categoria)}</td>
            <td>${escapeHtml(ev.subcategoria)}</td>
            <td>${escapeHtml(ev.zona || "")}</td>
            <td><span class="badge-${ev.resultado}">${ev.resultado}</span></td>
            <td>${escapeHtml(ev.contexto)}</td>
            <td class="mono">${duracion != null ? formatearDuracionCorta(duracion) : "—"}</td>
            <td>
                <button class="btn-mini" data-accion="clip" title="${duracion != null ? "Descargar clip" : "Sin rango marcado"}" ${duracion != null ? "" : "disabled"}>✂</button>
            </td>
            <td class="acciones-celda">
                <button class="btn-mini" data-accion="editar">✎</button>
                <button class="btn-mini btn-mini-danger" data-accion="borrar">×</button>
            </td>
        `;
        tr.querySelector("td.celda-time").addEventListener("click", () => { video().currentTime = ev.timestamp_seg; });
        tr.querySelector('[data-accion="editar"]').addEventListener("click", (e) => {
            e.stopPropagation();
            abrirFormulario(ev);
        });
        tr.querySelector('[data-accion="borrar"]').addEventListener("click", async (e) => {
            e.stopPropagation();
            if (!confirm("¿Eliminar este evento?")) return;
            await fetch(`/api/eventos/${ev.id}`, { method: "DELETE" });
            await refrescarSesion();
        });
        if (duracion != null) {
            tr.querySelector('[data-accion="clip"]').addEventListener("click", async (e) => {
                e.stopPropagation();
                await descargarConEstado(e.currentTarget, `/api/eventos/${ev.id}/clip`, `clip_${ev.id}.mp4`);
            });
        }
        body.appendChild(tr);
    });
}

// ---------------------------------------------------------------------
// Duración de eventos (in_point_seg / out_point_seg)
// ---------------------------------------------------------------------

// null si el evento no tiene entrada/salida marcadas (o out <= in).
function duracionSegundos(ev) {
    if (ev.in_point_seg == null || ev.out_point_seg == null) return null;
    const d = ev.out_point_seg - ev.in_point_seg;
    return d > 0 ? d : null;
}

function formatearDuracionCorta(segundos) {
    const m = Math.floor(segundos / 60);
    const s = Math.floor(segundos % 60);
    return `${m}:${String(s).padStart(2, "0")}`;
}

// ---------------------------------------------------------------------
// Notificaciones (reemplazan alert() para errores de clip)
// ---------------------------------------------------------------------
function mostrarError(mensaje) {
    const cont = document.getElementById("toast-container");
    const toast = document.createElement("div");
    toast.className = "toast";
    toast.textContent = mensaje;
    cont.appendChild(toast);
    setTimeout(() => toast.remove(), 6000);
}

// ---------------------------------------------------------------------
// Clips (corte con FFmpeg en el backend)
// ---------------------------------------------------------------------

// Descarga el archivo que devuelve `url`, mostrando "..." y deshabilitando
// el botón mientras dura el pedido. Si el backend responde con un error
// JSON (video no encontrado, FFmpeg no disponible, etc.) lo muestra en un
// aviso propio (no alert() nativo), sin tracebacks de Python.
async function descargarConEstado(boton, url, nombrePorDefecto) {
    const textoOriginal = boton.textContent;
    boton.disabled = true;
    boton.textContent = "...";
    try {
        const resp = await fetch(url);
        if (!resp.ok) {
            let mensaje = "No se pudo generar el clip.";
            try {
                const data = await resp.json();
                if (data.error) mensaje = data.error;
            } catch (_) { /* la respuesta de error no era JSON */ }
            mostrarError(mensaje);
            return;
        }
        const blob = await resp.blob();
        const disposition = resp.headers.get("Content-Disposition") || "";
        const match = disposition.match(/filename="([^"]+)"/);
        const nombre = match ? match[1] : nombrePorDefecto;

        const urlBlob = URL.createObjectURL(blob);
        const a = document.createElement("a");
        a.href = urlBlob;
        a.download = nombre;
        document.body.appendChild(a);
        a.click();
        a.remove();
        URL.revokeObjectURL(urlBlob);
    } catch (err) {
        mostrarError("No se pudo conectar con el servidor para generar el clip.");
    } finally {
        boton.disabled = false;
        boton.textContent = textoOriginal;
    }
}

// ---------------------------------------------------------------------
// Seekbar: barra de progreso + selector de rango dual (in/out)
// ---------------------------------------------------------------------
const DISTANCIA_MINIMA = 1; // segundos mínimos entre manija izquierda y derecha

function duracionTotalVideo() {
    const d = video().duration;
    return isFinite(d) && d > 0 ? d : 0;
}

function pctDeSegundos(seg) {
    const total = duracionTotalVideo();
    return total > 0 ? Math.max(0, Math.min(100, (seg / total) * 100)) : 0;
}

function segundosDePct(pct) {
    return (pct / 100) * duracionTotalVideo();
}

function formatearTimecodeCorto(segundosTotales) {
    const h = Math.floor(segundosTotales / 3600);
    const m = Math.floor((segundosTotales % 3600) / 60);
    const s = Math.floor(segundosTotales % 60);
    const pad = (n) => String(n).padStart(2, "0");
    return `${pad(h)}:${pad(m)}:${pad(s)}`;
}

function actualizarProgreso() {
    document.getElementById("seek-progreso-relleno").style.width = `${pctDeSegundos(video().currentTime)}%`;
}

// Repinta manijas, zona ámbar y etiqueta de duración; y si el panel de
// evento está abierto, también actualiza el renglón "Segmento:" ahí.
function actualizarSeleccionVisual() {
    const pIn = pctDeSegundos(handleIn);
    const pOut = pctDeSegundos(handleOut);
    document.getElementById("manija-in").style.left = `${pIn}%`;
    document.getElementById("manija-out").style.left = `${pOut}%`;
    document.getElementById("seek-seleccion-zona").style.left = `${pIn}%`;
    document.getElementById("seek-seleccion-zona").style.width = `${Math.max(0, pOut - pIn)}%`;

    const dur = handleOut - handleIn;
    const label = document.getElementById("seek-duracion-label");
    const btnPreview = document.getElementById("btn-preview");
    if (dur > 0) {
        label.textContent = `Dur: ${formatearDuracionCorta(dur)}`;
        btnPreview.disabled = false;
        btnPreview.title = "Reproducir el rango marcado";
    } else {
        label.textContent = "Sin rango";
        btnPreview.disabled = true;
        btnPreview.title = "Primero marca un rango";
        detenerPreview();
    }
    actualizarSegmentoFormulario();
}

function actualizarSegmentoFormulario() {
    const display = document.getElementById("ev-segmento-display");
    if (!display) return;
    display.textContent = handleOut > handleIn
        ? `Segmento: ${formatearTimecodeCorto(handleIn)} → ${formatearTimecodeCorto(handleOut)} (${formatearDuracionCorta(handleOut - handleIn)})`
        : "Sin rango — arrastra las manijas o usa I y O";
}

function resetearSeleccion() {
    handleIn = 0;
    handleOut = 0;
    actualizarSeleccionVisual();
}

function flashManija(el) {
    el.classList.add("flash");
    setTimeout(() => el.classList.remove("flash"), 150);
}

// Tecla I / manija izquierda: marca la entrada en el momento actual.
// Si el panel todavía está cerrado, además lo abre (PASO 6).
function marcarEntrada() {
    handleIn = Math.max(0, Math.min(video().currentTime, duracionTotalVideo()));
    if (handleOut < handleIn + DISTANCIA_MINIMA) {
        handleOut = Math.min(duracionTotalVideo(), handleIn + DISTANCIA_MINIMA);
    }
    actualizarSeleccionVisual();
    flashManija(document.getElementById("manija-in"));
    if (document.getElementById("overlay-formulario").classList.contains("hidden")) {
        abrirFormulario();
    }
}

// Tecla O / manija derecha: marca la salida en el momento actual.
function marcarSalida() {
    handleOut = Math.max(0, Math.min(video().currentTime, duracionTotalVideo()));
    if (handleIn > handleOut - DISTANCIA_MINIMA) {
        handleIn = Math.max(0, handleOut - DISTANCIA_MINIMA);
    }
    actualizarSeleccionVisual();
    flashManija(document.getElementById("manija-out"));
}

// Arrastre de una manija con Pointer Events: fluido, sin que el video
// salte (nunca se toca video().currentTime acá, solo handleIn/handleOut).
function iniciarArrastreManija(cual, elManija) {
    elManija.addEventListener("pointerdown", (e) => {
        e.preventDefault();
        e.stopPropagation();
        elManija.setPointerCapture(e.pointerId);
        const rect = document.getElementById("seek-seleccion").getBoundingClientRect();

        const mover = (ev) => {
            const pct = ((ev.clientX - rect.left) / rect.width) * 100;
            let seg = segundosDePct(Math.max(0, Math.min(100, pct)));
            if (cual === "in") {
                handleIn = Math.max(0, Math.min(seg, duracionTotalVideo()));
                if (handleOut < handleIn + DISTANCIA_MINIMA) {
                    handleOut = Math.min(duracionTotalVideo(), handleIn + DISTANCIA_MINIMA);
                }
            } else {
                handleOut = Math.max(0, Math.min(seg, duracionTotalVideo()));
                if (handleIn > handleOut - DISTANCIA_MINIMA) {
                    handleIn = Math.max(0, handleOut - DISTANCIA_MINIMA);
                }
            }
            actualizarSeleccionVisual();
        };
        const soltar = () => {
            elManija.releasePointerCapture(e.pointerId);
            elManija.removeEventListener("pointermove", mover);
            elManija.removeEventListener("pointerup", soltar);
        };
        elManija.addEventListener("pointermove", mover);
        elManija.addEventListener("pointerup", soltar);
    });
}

// Clic en la barra (fuera de una manija) mueve el playhead; las manijas
// no se tocan.
function manejarClicBarra(e) {
    if (e.target.classList.contains("seek-manija")) return;
    const rect = e.currentTarget.getBoundingClientRect();
    const pct = ((e.clientX - rect.left) / rect.width) * 100;
    video().currentTime = segundosDePct(Math.max(0, Math.min(100, pct)));
}

function detenerPreview() {
    if (!previewActivo) return;
    pausadoPorPreview = true;
    video().pause();
    video().currentTime = handleIn;
    previewActivo = false;
    document.getElementById("btn-preview").textContent = "▶ Preview";
}

function togglePreview() {
    if (previewActivo) { detenerPreview(); return; }
    if (handleOut <= handleIn) return;
    video().currentTime = handleIn;
    video().play();
    previewActivo = true;
    document.getElementById("btn-preview").textContent = "⏹ Detener";
}

function inicializarSeekbar() {
    iniciarArrastreManija("in", document.getElementById("manija-in"));
    iniciarArrastreManija("out", document.getElementById("manija-out"));
    document.getElementById("seek-progreso").addEventListener("click", manejarClicBarra);
    document.getElementById("seek-seleccion").addEventListener("click", manejarClicBarra);
    document.getElementById("btn-preview").addEventListener("click", togglePreview);
}

// ---------------------------------------------------------------------
// Video
// ---------------------------------------------------------------------
function bindearVideo(file) {
    if (!file) return;
    const url = URL.createObjectURL(file);
    video().src = url;
    document.getElementById("video-loader").classList.add("hidden");
    document.getElementById("video-wrapper").classList.remove("hidden");
    if (sesionActual && file.name !== sesionActual.video_archivo) {
        fetch(`/api/sesiones/${sesionActual.id}/video`, {
            method: "PUT", headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ video_archivo: file.name }),
        });
        sesionActual.video_archivo = file.name;
    }
    video().addEventListener("timeupdate", actualizarTimecode);
    video().addEventListener("timeupdate", actualizarProgreso);
    video().addEventListener("timeupdate", () => {
        if (previewActivo && video().currentTime >= handleOut) detenerPreview();
    });
    video().addEventListener("play", () => { document.getElementById("btn-play-pause").textContent = "⏸"; });
    video().addEventListener("pause", () => {
        document.getElementById("btn-play-pause").textContent = "▶";
        // Si el usuario pausa manualmente durante un preview (no por haber
        // llegado a la salida), cortamos el estado de preview también.
        if (previewActivo && !pausadoPorPreview) {
            previewActivo = false;
            document.getElementById("btn-preview").textContent = "▶ Preview";
        }
        pausadoPorPreview = false;
    });
    video().addEventListener("loadedmetadata", () => {
        resetearSeleccion(); // PASO 3: cada video empieza sin selección activa
        actualizarProgreso();
    }, { once: true });
}

function togglePlayPause() {
    const v = video();
    if (v.paused) v.play(); else v.pause();
}

function saltar(segundos) {
    const v = video();
    v.currentTime = Math.max(0, v.currentTime + segundos);
}

function actualizarTimecode() {
    document.getElementById("timecode").textContent = formatearTimecode(video().currentTime);
}

function formatearTimecode(segundosTotales) {
    const h = Math.floor(segundosTotales / 3600);
    const m = Math.floor((segundosTotales % 3600) / 60);
    const s = Math.floor(segundosTotales % 60);
    const ms = Math.floor((segundosTotales % 1) * 1000);
    const pad = (n, len = 2) => String(n).padStart(len, "0");
    return `${pad(h)}:${pad(m)}:${pad(s)}.${pad(ms, 3)}`;
}

// ---------------------------------------------------------------------
// Cancha
// ---------------------------------------------------------------------
function onZonaSeleccionada(zid) {
    document.getElementById("zona-actual").textContent = zid;
    const campoZona = document.getElementById("ev-zona");
    if (!document.getElementById("overlay-formulario").classList.contains("hidden")) {
        campoZona.value = zid;
    }
}

// ---------------------------------------------------------------------
// Formulario de evento
// ---------------------------------------------------------------------
function poblarSelectCategoria() {
    const sel = document.getElementById("ev-categoria");
    sel.innerHTML = "";
    Object.entries(TAXONOMIA.categorias).forEach(([key, cat]) => {
        const opt = document.createElement("option");
        opt.value = key;
        opt.textContent = `${key}. ${cat.nombre}`;
        sel.appendChild(opt);
    });
    poblarSelectSubcategoria();
}

function poblarSelectSubcategoria() {
    const key = document.getElementById("ev-categoria").value;
    const sel = document.getElementById("ev-subcategoria");
    sel.innerHTML = "";
    (TAXONOMIA.categorias[key]?.subcategorias || []).forEach((s) => {
        const opt = document.createElement("option");
        opt.value = s; opt.textContent = s;
        sel.appendChild(opt);
    });
}

function poblarSelectContexto() {
    const sel = document.getElementById("ev-contexto");
    sel.innerHTML = "";
    TAXONOMIA.contextos.forEach((c) => {
        const opt = document.createElement("option");
        opt.value = c; opt.textContent = c;
        sel.appendChild(opt);
    });
}

function seleccionarResultado(valor) {
    document.getElementById("ev-resultado").value = valor;
    $$(".opcion-btn").forEach((b) => b.classList.toggle("activo", b.dataset.valor === valor));
}

function abrirFormulario(eventoExistente = null) {
    const v = video();
    videoEstabaReproduciendo = !v.paused;
    v.pause();

    editandoEventoId = eventoExistente ? eventoExistente.id : null;

    if (eventoExistente) {
        // Cargar el rango guardado del evento en las manijas, para poder
        // verlo y ajustarlo en el seekbar mientras se edita (fallback a
        // timestamp_seg en eventos viejos, de antes de in_point_seg).
        handleIn = eventoExistente.in_point_seg ?? eventoExistente.timestamp_seg;
        handleOut = eventoExistente.out_point_seg ?? eventoExistente.timestamp_seg;
        actualizarSeleccionVisual();
    }
    // Si es un evento nuevo, se usa lo que ya esté marcado en las manijas
    // (PASO 6: "los campos se cargan desde las manijas").

    document.getElementById("ev-minuto").value =
        eventoExistente ? (eventoExistente.minuto_partido || "") : String(Math.floor(handleIn / 60));

    const catKey = eventoExistente
        ? Object.entries(TAXONOMIA.categorias).find(([, c]) => c.nombre === eventoExistente.categoria)?.[0] || "1"
        : "1";
    document.getElementById("ev-categoria").value = catKey;
    poblarSelectSubcategoria();
    if (eventoExistente) document.getElementById("ev-subcategoria").value = eventoExistente.subcategoria;

    document.getElementById("ev-zona").value = eventoExistente
        ? (eventoExistente.zona || "")
        : (zonaSeleccionadaActual() || "");

    seleccionarResultado(eventoExistente ? eventoExistente.resultado : "positivo");

    document.getElementById("ev-contexto").value = eventoExistente ? eventoExistente.contexto : TAXONOMIA.contextos[0];
    document.getElementById("ev-memo").value = eventoExistente ? (eventoExistente.memo || "") : "";

    actualizarSegmentoFormulario();
    document.getElementById("overlay-formulario").classList.remove("hidden");
    document.getElementById("ev-minuto").focus();
}

function cerrarFormulario() {
    document.getElementById("overlay-formulario").classList.add("hidden");
    editandoEventoId = null;
    if (videoEstabaReproduciendo) video().play();
}

async function guardarEvento(e) {
    e.preventDefault();
    const resultado = document.getElementById("ev-resultado").value;
    if (!resultado) { alert("Elegí un resultado."); return; }

    if (!editandoEventoId && handleIn === 0 && handleOut === 0) {
        mostrarError("Marcá un punto de entrada con la tecla I (o arrastrando una manija) antes de guardar.");
        return;
    }

    const catKey = document.getElementById("ev-categoria").value;
    // Salida sin marcar (handleOut <= handleIn) → evento puntual, sin
    // duración: se guarda igual a la entrada, misma condición de "sin
    // duración" que usa el backend para decidir si hay clip para cortar.
    const outFinal = handleOut > handleIn ? handleOut : handleIn;

    const datos = {
        timestamp_seg: handleIn,
        timestamp_fmt: formatearTimecode(handleIn),
        in_point_seg: handleIn,
        out_point_seg: outFinal,
        minuto_partido: document.getElementById("ev-minuto").value,
        categoria: TAXONOMIA.categorias[catKey].nombre,
        subcategoria: document.getElementById("ev-subcategoria").value,
        zona: document.getElementById("ev-zona").value,
        resultado,
        contexto: document.getElementById("ev-contexto").value,
        memo: document.getElementById("ev-memo").value,
    };

    if (editandoEventoId) {
        await fetch(`/api/eventos/${editandoEventoId}`, {
            method: "PUT", headers: { "Content-Type": "application/json" }, body: JSON.stringify(datos),
        });
    } else {
        await fetch(`/api/sesiones/${sesionActual.id}/eventos`, {
            method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(datos),
        });
    }
    cerrarFormulario();
    resetearSeleccion(); // PASO 6: al guardar, las manijas vuelven a 0
    await refrescarSesion();
}

// ---------------------------------------------------------------------
// Atajos de teclado
// ---------------------------------------------------------------------
function manejarAtajos(e) {
    const overlayAbierto = !document.getElementById("overlay-formulario").classList.contains("hidden");
    const enCampoLibre = ["INPUT", "TEXTAREA"].includes(e.target.tagName);

    if (overlayAbierto) {
        if (e.key === "Escape") { e.preventDefault(); cerrarFormulario(); return; }
        if (e.key === "Enter" && e.target.tagName !== "TEXTAREA") {
            e.preventDefault();
            document.getElementById("form-evento").requestSubmit();
            return;
        }
        if (["1", "2", "3", "4", "5"].includes(e.key) && !enCampoLibre) {
            document.getElementById("ev-categoria").value = e.key;
            poblarSelectSubcategoria();
        }
    }

    // I y O funcionan tanto con el panel abierto como cerrado: las manijas
    // siguen siendo arrastrables con el panel abierto (PASO 6), así que
    // también tiene sentido poder marcarlas por teclado en ese momento.
    if (enCampoLibre) return;
    if (document.getElementById("screen-analisis").classList.contains("hidden")) return;
    if (document.getElementById("video-wrapper").classList.contains("hidden")) return;

    if (e.key.toLowerCase() === "i") { e.preventDefault(); marcarEntrada(); return; }
    if (e.key.toLowerCase() === "o") { e.preventDefault(); marcarSalida(); return; }

    if (overlayAbierto) return; // espacio/flechas/1-5-abre solo con el panel cerrado

    if (e.key === " ") { e.preventDefault(); togglePlayPause(); return; }
    if (["1", "2", "3", "4", "5"].includes(e.key)) { abrirFormulario(); document.getElementById("ev-categoria").value = e.key; poblarSelectSubcategoria(); return; }
    if (e.key === "ArrowLeft") { e.preventDefault(); saltar(e.shiftKey ? -5 : -1); return; }
    if (e.key === "ArrowRight") { e.preventDefault(); saltar(e.shiftKey ? 5 : 1); return; }
}

function escapeHtml(str) {
    const div = document.createElement("div");
    div.textContent = str ?? "";
    return div.innerHTML;
}

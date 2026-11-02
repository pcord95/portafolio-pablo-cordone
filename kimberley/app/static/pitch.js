// Cancha SVG interactiva: 3 tercios (D/M/O) x 6 franjas verticales = 18 zonas.
// Tercios a lo largo de la cancha (eje X), franjas a lo ancho (eje Y).

const PITCH_TERCIOS = ["D", "M", "O"];
const PITCH_TERCIOS_LABEL = { D: "Defensivo", M: "Medio", O: "Ofensivo" };
const PITCH_BANDAS = 6; // 1=banda izq ... 6=banda der
const PITCH_W = 1050;
const PITCH_H = 680;

let _zonaSeleccionada = null;
let _onZonaClick = null;

function idZona(tercioIdx, bandaIdx) {
    return `${PITCH_TERCIOS[tercioIdx]}${bandaIdx + 1}`;
}

function crearCancha(container, onZonaClick) {
    _onZonaClick = onZonaClick;
    const anchoZona = PITCH_W / 3;
    const altoZona = PITCH_H / PITCH_BANDAS;

    const svgNS = "http://www.w3.org/2000/svg";
    const svg = document.createElementNS(svgNS, "svg");
    svg.setAttribute("viewBox", `0 0 ${PITCH_W} ${PITCH_H}`);
    svg.setAttribute("class", "pitch-svg");

    // Marcas de cancha (referencia visual, no interactivas)
    const marcas = document.createElementNS(svgNS, "g");
    marcas.setAttribute("class", "pitch-marcas");
    marcas.innerHTML = `
        <rect x="1" y="1" width="${PITCH_W - 2}" height="${PITCH_H - 2}" class="pitch-borde"></rect>
        <line x1="${PITCH_W / 2}" y1="0" x2="${PITCH_W / 2}" y2="${PITCH_H}" class="pitch-linea"></line>
        <circle cx="${PITCH_W / 2}" cy="${PITCH_H / 2}" r="${PITCH_H * 0.16}" class="pitch-linea"></circle>
        <rect x="0" y="${PITCH_H * 0.21}" width="${PITCH_W * 0.15}" height="${PITCH_H * 0.58}" class="pitch-linea"></rect>
        <rect x="${PITCH_W - PITCH_W * 0.15}" y="${PITCH_H * 0.21}" width="${PITCH_W * 0.15}" height="${PITCH_H * 0.58}" class="pitch-linea"></rect>
    `;
    svg.appendChild(marcas);

    const zonas = document.createElementNS(svgNS, "g");
    zonas.setAttribute("class", "pitch-zonas");

    for (let t = 0; t < 3; t++) {
        for (let b = 0; b < PITCH_BANDAS; b++) {
            const zid = idZona(t, b);
            const x = t * anchoZona;
            const y = b * altoZona;

            const g = document.createElementNS(svgNS, "g");
            g.setAttribute("class", "pitch-zona");
            g.setAttribute("data-zona", zid);
            g.style.cursor = "pointer";

            const rect = document.createElementNS(svgNS, "rect");
            rect.setAttribute("x", x + 2);
            rect.setAttribute("y", y + 2);
            rect.setAttribute("width", anchoZona - 4);
            rect.setAttribute("height", altoZona - 4);
            rect.setAttribute("class", "pitch-zona-rect");
            g.appendChild(rect);

            const label = document.createElementNS(svgNS, "text");
            label.setAttribute("x", x + 14);
            label.setAttribute("y", y + 22);
            label.setAttribute("class", "pitch-zona-label");
            label.textContent = zid;
            g.appendChild(label);

            const badge = document.createElementNS(svgNS, "text");
            badge.setAttribute("x", x + anchoZona - 14);
            badge.setAttribute("y", y + altoZona - 12);
            badge.setAttribute("text-anchor", "end");
            badge.setAttribute("class", "pitch-zona-badge");
            badge.setAttribute("data-badge-zona", zid);
            badge.textContent = "";
            g.appendChild(badge);

            g.addEventListener("click", () => seleccionarZona(zid));
            zonas.appendChild(g);
        }
    }
    svg.appendChild(zonas);

    container.innerHTML = "";
    container.appendChild(svg);
}

function seleccionarZona(zid) {
    _zonaSeleccionada = zid;
    document.querySelectorAll(".pitch-zona").forEach((g) => {
        g.classList.toggle("pitch-zona-activa", g.dataset.zona === zid);
    });
    if (_onZonaClick) _onZonaClick(zid);
}

function zonaSeleccionadaActual() {
    return _zonaSeleccionada;
}

function actualizarContadoresZona(contadores) {
    document.querySelectorAll("[data-badge-zona]").forEach((el) => {
        const total = contadores[el.dataset.badgeZona] || 0;
        el.textContent = total > 0 ? total : "";
    });
}

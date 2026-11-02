# Kimberley N5 · Terminal local de análisis en vídeo

Herramienta local para registrar y analizar partidos en vídeo, desarrollada para el trabajo con un club amateur de la Liga Marplatense (Argentina). Es el antecedente del módulo de videoanálisis de ETData.

## Qué hace

- Todo corre en el computador (localhost), sin servicios externos: el vídeo se carga desde el disco y nunca sale del equipo.
- Una sesión es un partido; cada evento se registra con una taxonomía táctico-sociológica de cinco categorías (acciones defensivas, acciones con balón, posicionamiento sin balón, comunicación y liderazgo, pressing y transiciones), su resultado y su contexto.
- Cancha interactiva de 18 zonas (3 tercios × 6 franjas) para ubicar cada acción.
- Exporta los eventos a CSV o JSON y corta los clips de cada evento con FFmpeg.

## Qué hay aquí

- `app/`: servidor Flask (`app.py`), capa de datos SQLite (`database.py`), interfaz (`templates/`, `static/`).
- No se incluyen vídeos ni registros de sesiones.

## Cómo correrlo

```bash
cd app
pip install -r requirements.txt
python app.py
```

Los vídeos se colocan en `app/videos/` y FFmpeg debe estar instalado para cortar clips.

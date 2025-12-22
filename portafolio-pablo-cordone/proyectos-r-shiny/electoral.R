library(shiny)
library(dplyr)
library(leaflet)
library(sf)
library(htmltools)
library(shinythemes)
library(viridis)

# ==============================================================================
# 1. CARGA Y PREPARACIÓN DE DATOS (Se ejecuta una vez al iniciar)
# ==============================================================================

# A. Cargar Datos Socioeconómicos (Tu "Cerebro")
if (!file.exists("datos_casen_los_lagos.rds")) {
  stop("❌ Error: No encuentro 'datos_casen_los_lagos.rds'. Asegúrate de que esté en la misma carpeta que este script.")
}
datos_casen <- readRDS("datos_casen_los_lagos.rds")

# B. Cargar Mapa Base (Tu "Cuerpo")
if (!file.exists("data/mapas/comunas_los_lagos_sf_base.rds")) {
  stop("❌ Error: No encuentro el mapa en 'data/mapas/comunas_los_lagos_sf_base.rds'")
}
mapa_raw <- readRDS("data/mapas/comunas_los_lagos_sf_base.rds")

# C. Fusión Nuclear (Unión Definitiva)
# Detectamos columna de código en el mapa (usualmente 'cod_comuna' o 'objectid')
col_mapa <- intersect(names(mapa_raw), c("cod_comuna", "COD_COMUNA", "cut_com", "objectid"))[1]
if(is.na(col_mapa)) col_mapa <- names(mapa_raw)[1] # Fallback

# Creamos el objeto espacial listo para pintar
mapa_territorial <- mapa_raw %>%
  mutate(codigo_enlace = as.numeric(.data[[col_mapa]])) %>% # Forzamos número
  left_join(datos_casen, by = c("codigo_enlace" = "codigo")) %>%
  st_transform(4326) # Proyección GPS

# ==============================================================================
# 2. INTERFAZ DE USUARIO (UI)
# ==============================================================================

ui <- fluidPage(
  theme = shinytheme("flatly"), # Mismo tema que tu web
  
  # Título más sobrio, enfocado en el análisis
  titlePanel("Inteligencia Territorial: Estructura de Clases y Materialidad"),
  
  sidebarLayout(
    sidebarPanel(
      width = 3,
      h4("Dimensión de Análisis", style = "color: #c0392b; font-weight: bold;"),
      
      # Selector con los nombres EXACTOS de tu base de datos
      selectInput("variable", "Seleccione Indicador:",
                  choices = c(
                    "--- ESTRUCTURA DE CLASE ---" = "header1",
                    "% Clase Trabajadora" = "pct_clase_trabajadora",
                    "% Cuenta Propia (Oficio)" = "pct_cuenta_propia",
                    "% Empresariado" = "pct_empresariado",
                    "% Profesionales/Técnicos" = "pct_profesionales",
                    
                    "--- CONDICIONES MATERIALES ---" = "header2",
                    "Pobreza por Ingresos (%)" = "tasa_pobreza",
                    "Pobreza Multidimensional (%)" = "tasa_pobreza_multi",
                    "Dependencia del Estado (%)" = "dep_estado_comunal",
                    "Ingreso Promedio del Trabajo ($)" = "ingreso_trabajo_prom",
                    "Hacinamiento (%)" = "pct_hacinamiento"
                  )
      ),
      
      hr(),
      div(class = "alert alert-info",
          icon("info-circle"),
          strong("Fuente:"), " Procesamiento propio en base a CASEN 2022.", br(),
          "Metodología: Clasificación marxista de ocupaciones + Ingresos corregidos."
      )
    ),
    
    mainPanel(
      width = 9,
      leafletOutput("mapa_casen", height = "85vh") # Mapa grande
    )
  )
)

# ==============================================================================
# 3. LÓGICA DEL SERVIDOR (SERVER)
# ==============================================================================

server <- function(input, output, session) {
  
  output$mapa_casen <- renderLeaflet({
    
    # 1. Obtener la variable seleccionada
    var_name <- input$variable
    datos_pintar <- mapa_territorial
    
    # 2. Extraer los valores de forma segura
    if (var_name %in% names(datos_pintar)) {
      valores <- as.numeric(datos_pintar[[var_name]]) # Asegurar numérico
    } else {
      valores <- rep(0, nrow(datos_pintar)) # Evitar crash si falla nombre
    }
    
    # Limpiar NAs (convertir a 0 para que el mapa no quede gris)
    valores[is.na(valores)] <- 0
    
    # 3. Definir Paleta de Colores
    # Usamos "Magma" invertida: Los colores oscuros representan mayor intensidad
    paleta <- colorNumeric(palette = "Magma", domain = valores, reverse = TRUE)
    
    # 4. Formato de Texto para el Popup
    es_dinero <- var_name == "ingreso_trabajo_prom" | var_name == "ingreso_hogar_prom"
    simbolo <- if(es_dinero) "$" else "%"
    
    texto_popup <- paste0(
      "<strong>Comuna: </strong>", datos_pintar$Comuna, "<br>", # Ajusta si tu columna de nombre es otra
      "<strong>Indicador: </strong>", 
      if(es_dinero) format(round(valores, 0), big.mark=".") else round(valores, 1),
      simbolo
    )
    
    # 5. Renderizar Mapa
    leaflet(datos_pintar) %>%
      addProviderTiles(providers$CartoDB.Positron) %>%
      addPolygons(
        fillColor = ~paleta(valores),
        weight = 1,
        opacity = 1,
        color = "white",
        dashArray = "3",
        fillOpacity = 0.7,
        highlightOptions = highlightOptions(
          weight = 3,
          color = "#666",
          dashArray = "",
          fillOpacity = 0.7,
          bringToFront = TRUE
        ),
        label = lapply(texto_popup, HTML), # Popup al pasar el mouse
        popup = lapply(texto_popup, HTML)  # Popup al hacer click
      ) %>%
      addLegend(
        pal = paleta,
        values = valores,
        opacity = 0.7,
        title = "Intensidad",
        position = "bottomright",
        labFormat = labelFormat(suffix = if(!es_dinero) "%" else "")
      ) %>%
      setView(lng = -72.9, lat = -41.5, zoom = 8) # Centrado en Los Lagos
  })
}

# Ejecutar App
shinyApp(ui, server)
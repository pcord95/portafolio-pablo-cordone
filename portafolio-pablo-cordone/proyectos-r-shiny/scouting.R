# --- SCRIPT ÚNICO: app.R (El Tripulante v0.1) ---

# --- 0. CARGAR LIBRERÍAS ---
library(shiny)
library(dplyr)
library(ggplot2)
library(ggrepel)      # Para etiquetas de gráficos
library(scales)       # Para formato de ejes (ej. €)
library(DT)           # Para tablas interactivas
library(forcats)      # Para reordenar en ggplot
library(ggsoccer)

# --- 1. CARGAR DATOS ---
# Leemos el archivo .rds que guardamos en el Paso 1.
# Usamos suppressWarnings para ocultar advertencias si la app se inicia
datos_app <- suppressWarnings(readRDS("datos_app.rds"))

# Creamos una lista de opciones para el filtro de posición
# Añadimos "Todas" al principio
opciones_posicion <- c("Todas", unique(datos_app$posicion))

# --- 2. DEFINIR LA INTERFAZ DE USUARIO (UI) ---
ui <- fluidPage(
  
  # Título de la Aplicación
  titlePanel("El Tripulante - Plataforma de Scouting v0.1"),
  
  sidebarLayout(
    
    # --- BARRA LATERAL (FILTROS) ---
    sidebarPanel(
      width = 3,
      h4("Radar de Búsqueda"),
      
      # Filtro por Posición
      selectInput(
        "posicion_filter", 
        "Posición:",
        choices = opciones_posicion, # Usamos la lista que creamos
        selected = "Todas",
        multiple = TRUE
      ),
      
      # Filtro por Edad
      sliderInput(
        "edad_filter",
        "Rango de Edad:",
        min = min(datos_app$edad, na.rm = TRUE),
        max = max(datos_app$edad, na.rm = TRUE),
        value = c(min(datos_app$edad, na.rm = TRUE), max(datos_app$edad, na.rm = TRUE)) # Valor inicial
      ),
      
      # Filtro por Valor de Mercado
      sliderInput(
        "valor_filter",
        "Valor de Mercado (max):",
        min = 0,
        max = max(datos_app$valor_mercado_num, na.rm = TRUE),
        value = max(datos_app$valor_mercado_num, na.rm = TRUE),
        step = 50000,
        pre = "€"
      ),
      
      hr(),
      helpText("Datos de Coquimbo Unido (Temporada 2024)")
    ),
    
    # --- PANEL PRINCIPAL (RESULTADOS) ---
    mainPanel(
      width = 9,
      tabsetPanel(
        type = "tabs",
        
        # Pestaña 1: Tabla Interactiva
        tabPanel(
          "Tabla de Jugadores", 
          br(),
          p("Jugadores que cumplen los criterios de búsqueda:"),
          DT::dataTableOutput("tabla_resultados")
        ),
        
        # Pestaña 2: Gráfico Moneyball (El que hicimos)
        tabPanel(
          "Análisis Moneyball",
          br(),
          h5("Gráfico de Eficiencia (Goles vs. Valor de Mercado)"),
          plotOutput("grafico_moneyball")
        ),
        
        # Pestaña 3: Gráfico Edad vs Valor (El que hicimos)
        tabPanel(
          "Análisis de Valor (Branding)",
          br(),
          h5("Gráfico de Edad vs. Valor de Mercado"),
          plotOutput("grafico_edad_valor")
        ),
        
        # Pestaña 4: Gráfico Prod. vs Minutos (El que hicimos)
        tabPanel(
          "Análisis de Producción",
          br(),
          h5("Gráfico de Minutos Jugados vs. Contribuciones de Gol (G+A)"),
          plotOutput("grafico_eficiencia_prod")
        )
      ) # Fin tabsetPanel
    ) # Fin mainPanel
  ) # Fin sidebarLayout
) # Fin fluidPage

# --- 3. DEFINIR LA LÓGICA DEL SERVIDOR (SERVER) ---
server <- function(input, output, session) {
  
  # --- DATOS REACTIVOS ---
  # Este bloque filtra los datos CADA VEZ que un filtro cambia
  datos_filtrados <- reactive({
    
    # Empezamos con la tabla completa
    df <- datos_app
    
    # 1. Filtrar por Posición
    if (!("Todas" %in% input$posicion_filter)) {
      df <- filter(df, posicion %in% input$posicion_filter)
    }
    
    # 2. Filtrar por Edad
    df <- filter(df, edad >= input$edad_filter[1] & edad <= input$edad_filter[2])
    
    # 3. Filtrar por Valor de Mercado
    df <- filter(df, valor_mercado_num <= input$valor_filter)
    
    return(df)
  })
  
  # --- SALIDAS (Outputs) ---
  
  # Salida 1: La Tabla
  output$tabla_resultados <- DT::renderDataTable({
    DT::datatable(
      datos_filtrados(), # Usamos los datos reactivos
      options = list(pageLength = 10, searching = TRUE, rownames = FALSE),
      filter = 'top',
      class = 'cell-border stripe'
    ) %>%
      # Formateamos las columnas de números
      formatCurrency(columns = "valor_mercado_num", currency = "€", interval = 3, mark = ".", digits = 0) %>%
      formatCurrency(columns = c("costo_por_gol", "costo_por_minuto"), currency = "€", interval = 3, mark = ".", digits = 0)
  })
  
  # Salida 2: Gráfico Moneyball
  output$grafico_moneyball <- renderPlot({
    # Filtramos solo para atacantes para este gráfico
    datos_grafico_moneyball <- datos_filtrados() %>%
      filter(total_goles > 0, valor_mercado_num > 0)
    
    # Mensaje si no hay datos
    if(nrow(datos_grafico_moneyball) == 0) {
      return(ggplot() + geom_text(aes(x=1, y=1, label="No hay jugadores con goles que cumplan este filtro."), size=6) + theme_void())
    }
    
    ggplot(datos_grafico_moneyball, aes(x = total_goles, y = valor_mercado_num)) +
      geom_point(aes(color = posicion, size = total_minutos), alpha = 0.8) +
      geom_text_repel(aes(label = nombre_jugador), size = 4, max.overlaps = 10) +
      scale_y_continuous(labels = label_dollar(prefix = "€", suffix = "")) + 
      scale_x_continuous(breaks = seq(0, max(datos_grafico_moneyball$total_goles, na.rm=T), by = 2)) +
      labs(x = "Goles Totales", y = "Valor de Mercado", color = "Posición", size = "Minutos") +
      theme_minimal(base_size = 14) +
      theme(legend.position = "bottom")
  })
  
  # Salida 3: Gráfico Edad vs Valor
  output$grafico_edad_valor <- renderPlot({
    datos_grafico_edad <- datos_filtrados() %>%
      filter(valor_mercado_num > 0)
    
    if(nrow(datos_grafico_edad) == 0) {
      return(ggplot() + geom_text(aes(x=1, y=1, label="No hay jugadores con valor de mercado que cumplan este filtro."), size=6) + theme_void())
    }
    
    ggplot(datos_grafico_edad, aes(x = edad, y = valor_mercado_num)) +
      geom_point(aes(color = posicion), size = 4, alpha = 0.7) +
      geom_text_repel(aes(label = nombre_jugador), size = 4, max.overlaps = 10) +
      geom_smooth(method = "loess", color = "blue", fill = "blue", alpha = 0.1) + 
      scale_y_continuous(labels = label_dollar(prefix = "€", suffix = "")) +
      scale_x_continuous(breaks = seq(15, 45, by = 2)) +
      labs(x = "Edad del Jugador", y = "Valor de Mercado", color = "Posición") +
      theme_minimal(base_size = 14) +
      theme(legend.position = "bottom")
  })
  
  # Salida 4: Gráfico Eficiencia de Producción
  output$grafico_eficiencia_prod <- renderPlot({
    datos_grafico_prod <- datos_filtrados() %>%
      mutate(contribuciones_gol = total_goles + total_asistencias) %>%
      filter(contribuciones_gol > 0)
    
    if(nrow(datos_grafico_prod) == 0) {
      return(ggplot() + geom_text(aes(x=1, y=1, label="No hay jugadores con goles o asistencias que cumplan este filtro."), size=6) + theme_void())
    }
    
    ggplot(datos_grafico_prod, aes(x = total_minutos, y = contribuciones_gol)) +
      geom_point(aes(color = posicion), size = 4, alpha = 0.7) +
      geom_text_repel(aes(label = nombre_jugador), size = 4, max.overlaps = 10) +
      geom_smooth(method = "lm", color = "red", linetype = "dashed", alpha = 0.1) +
      labs(x = "Minutos Totales Jugados", y = "Contribuciones de Gol (G+A)", color = "Posición") +
      theme_minimal(base_size = 14) +
      theme(legend.position = "bottom")
  })
  
} # Fin server

# --- 4. EJECUTAR LA APLICACIÓN ---
shinyApp(ui = ui, server = server)
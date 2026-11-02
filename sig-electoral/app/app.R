# app.R

library(shiny)
library(dplyr)
library(ggplot2)
library(DT)
library(RColorBrewer)
library(stringr)
library(scales)
library(leaflet)
library(sf)
library(htmltools)
library(shinythemes)
library(readr)
library(viridis)
library(tidyverse)
# --- CARGAR DATASETS PRE-PROCESADOS (desde .rds) ---

if (!file.exists("data/datos_elecciones_los_lagos_shiny.rds")) {
  stop("¡Error crítico! El archivo 'datos_elecciones_los_lagos_shiny.rds' no se encuentra.
        Asegúrate de que el script 'filtrado.R' lo haya generado correctamente en la carpeta 'data/'.")
}
datos_elecciones_los_lagos_shiny <- readRDS("data/datos_elecciones_los_lagos_shiny.rds")

if (!file.exists("data/mapas/comunas_los_lagos_sf_base.rds")) {
  stop("¡Error crítico! El archivo 'comunas_los_lagos_sf_base.rds' no se encuentra.
        Asegúrate de que el script 'filtrado.R' lo haya generado correctamente en la carpeta 'data/mapas/'.")
}
comunas_los_lagos_sf_base <- readRDS("data/mapas/comunas_los_lagos_sf_base.rds")

nombre_columna_comuna_sf <- "Comuna"

limpiar_nombre <- function(texto) {
  texto <- str_to_upper(texto)
  texto <- str_replace_all(texto, "Á", "A")
  texto <- str_replace_all(texto, "É", "E")
  texto <- str_replace_all(texto, "Í", "I")
  texto <- str_replace_all(texto, "Ó", "O")
  texto <- str_replace_all(texto, "Ú", "U")
  texto <- str_replace_all(texto, "Ñ", "N")
  texto <- str_replace_all(texto, "Ü", "U")
  return(texto)
}

tipos_eleccion_unicos <- sort(unique(datos_elecciones_los_lagos_shiny$tipo_eleccion))
años_eleccion_unicos <- sort(unique(datos_elecciones_los_lagos_shiny$año_eleccion), decreasing = TRUE)
partidos_unicos <- c("TODOS LOS PARTIDOS", sort(unique(datos_elecciones_los_lagos_shiny$Partido)))

primer_apellidos_presidenciales <- datos_elecciones_los_lagos_shiny %>%
  filter(str_detect(tipo_eleccion, "Presidencial|Alcalde|Concejal|Regional|Parlamentaria|Constitucionales")) %>%
  pull(`Primer apellido`) %>%
  unique() %>%
  na.omit() %>%
  sort()
primer_apellidos_unicos <- c("TODOS LOS CANDIDATOS", primer_apellidos_presidenciales)

coordenadas_locales_known <- tribble(
  ~Local, ~Latitud, ~Longitud,
  "ESCUELA 7 ARABE-SIRIA", -41.478584809896326, -72.9545968996832,
  "ESCUELA BASICA KIMUN LAWAL", -41.40301979582427, -72.91288217454579,
  "ESCUELA ESPAÑA", -41.470027797287166, -72.94025347779268,
  "ESCUELA MELIPULLI", -41.46269391037402, -72.92959404755454,
  "ESCUELA PADRE ALBERTO HURTADO", -41.475313424853454, -72.98546918988345,
  "ESCUELA REPUBLICA ARGENTINA", -41.46868888535289, -72.94238606289561,
  "ESCUELA RURAL CORRENTOSO", -41.45385253294892, -72.65726975021477,
  "ESCUELA RURAL HUELMO", -41.67252502242927, -73.06298670840711,
  "ESCUELA RURAL LA CHAMIZA", -41.483223871474415, -72.85434128803601,
  "ESCUELA RURAL LA VARA", -41.42350760110506, -72.91173212664245,
  "ESCUELA RURAL LENCA", -41.60510323943455, -72.69019804891228,
  "ESCUELA RURAL MAILLEN ESTERO", -41.583934171786545, -72.99795500337214,
  "LICEO ANDRES BELLO", -41.45952802433589, -72.95142545366068,
  "LICEO BENJAMIN VICUÑA MACKENNA", -41.47243512180781, -72.98258831253652,
  "LICEO DE HOMBRES MANUEL MONTT", -41.46929117360717, -72.94252828943988,
  "LICEO ISIDORA ZEGERS DE HUNEEUS", -41.471808393089326, -72.93331220337765,
  "LICEO RURAL LAS QUEMAS", -41.40185506729044, -73.17872476105184,
  "C.P. DE PUERTO MONTT", -41.48188714679558, -73.00837097788502,
  "COLEGIO BOSQUEMAR", -41.48574225737938, -73.00019635293063,
  "COLEGIO CREACIONES LA ARAUCANA", -41.459855451786794, -72.9941596681033,
  "COLEGIO DARIO SALAS", -41.463894121814434, -72.93146752021461,
  "COLEGIO DOMINGO SANTA MARIA", -41.47023310060819, -72.98506882206911,
  "COLEGIO LOS ALERCES", -41.38446535564657, -72.91712244534328,
  "COLEGIO NUEVA ALERCE", -41.385722308469106, -72.89694554719884,
  "COLEGIO PUMAHUE", -41.449709708640306, -72.92083194905366,
  "COLEGIO SANTO TOMAS", -41.452616474203104, -72.93576212206554,
  "COLEGIO TECNICO PROFESIONAL PIEDRA AZUL", -41.508416350067534, -72.78808586068277,
  "ESCUELA 10 ANGELMO", -41.47331330296234, -72.95437280486928,
  "ESCUELA ALERCE HISTORICO", -41.3989280619128, -72.91791736624471,
  "ESCUELA BASICA GABRIELA MISTRAL", -41.46450966293096, -72.91867472020769,
  "ESCUELA BASICA LAS CAMELIAS", -41.47514300704969, -72.97905449323338,
  "ESCUELA BASICA LICARAYEN", -41.457204422758046, -72.93020252206229,
  "ESCUELA BASICA SANTA INES", -41.46450718528487, -72.96291041651389,
  "ESCUELA CAPITAN ARTURO PRAT CHACON", -41.47439769676615, -72.91258847973745,
  "ESCUELA CAYENEL", -41.450812018773604, -72.96241010671831,
  "ESCUELA CHILOE", -41.4549398979927, -72.94745526254661,
  "ESCUELA DE CULTURA Y DIFUSION ARTISTICA", -41.47674261061956, -72.95050884904097,
  "ESCUELA DIFERENCIAL `LOS EUCALIPTOS`", -41.46471953054713, -72.92539274904247,
  "ESCUELA LIBERTAD", -41.457647546030806, -72.94603423556033,
  "ESCUELA MELIPULLI Y GIMNASIO", -41.46269391037402, -72.92959404755454,
  "ESCUELA MIRASOL", -41.478557252738035, -72.96784036439833,
  "ESCUELA NUMERO 1, ALEMANIA", -41.46032179170911, -72.92606342206179,
  "ESCUELA NUMERO 5, MIRAMAR", -41.47183807116941, -72.92246083020937,
  "ESCUELA PABLO NERUDA", -41.47573319311982, -72.9619319913735,
  "ESCUELA REPUBLICA ARGENTINA", -41.468677896175386, -72.94218317973655,
  "ESCUELA RURAL TEPUAL", -41.423977772222926, -73.10009014905516,
  "ESCUELA RURAL TRAPEN", -41.52875321780894, -73.12242838952369,
  "GIMNASIO UNIVERSIDAD DE LOS LAGOS", -41.49367147416679, -72.98850016439214,
  "INSTITUTO TECNICO FORJADORES DE ALERCE", -41.38927306464779, -72.90553329323266,
  "LICEO COMERCIAL", -41.46743962379661, -72.93062569323432,
  "LICEO COMERCIAL MIRAMAR", -41.4728064855032, -72.9232344778746,
  "LICEO INDUSTRIAL", -41.471126766775846, -72.9285729326517,
  "LICEO POLITECNICO MIRASOL", -41.47769183122277, -72.9833770897289,
  "LICEO TECNICO PROFESIONAL BOSQUE NATIVO", -41.462249369703905, -72.98491814740072,
  "PATAGONIA COLLEGE", -41.45495246426731, -72.90091084555235,
  "THE AMERICAN SCHOOL", -41.45668080411159, -72.91175500751837,
  "UNIVERSIDAD AUSTRAL DE CHILE", -41.48990074596681, -72.89772067853356,
  "COLEGIO DE DIFUSION ARTISTICA LOS ULMOS", -41.39148657849419, -73.45779713558223,
  "COLEGIO INGLES MABEL CONDEMARIN", -41.39690896645798, -73.45926948788401,
  "COLEGIO RAMON ANGEL JARA", -41.39306018445082, -73.46666217439083,
  "ESCUELA RURAL CANITAS", -41.303382873526154, -73.45226911672403,
  "ESCUELA RURAL ESTAQUILLA", -41.40148118786553, -73.81313386520706,
  "LICEO PUNTA DE RIELES", -41.39858291555153, -73.46200935904835
)

ui <- fluidPage(
  theme = shinytheme("flatly"),
  titlePanel("Análisis Electoral Geográfico - Región de Los Lagos", windowTitle = "Análisis Electoral"),
  sidebarLayout(
    sidebarPanel(
      h3("Filtros de Datos", style = "color: #2c3e50;"),
      selectInput(
        inputId = "tipoEleccion",
        label = "Seleccione Tipo de Elección:",
        choices = tipos_eleccion_unicos,
        selected = tipos_eleccion_unicos[1]
      ),
      selectInput(
        inputId = "añoEleccion",
        label = "Seleccione Año de Elección:",
        choices = años_eleccion_unicos,
        selected = años_eleccion_unicos[1]
      ),
      selectInput(
        inputId = "partidoFiltro",
        label = "Seleccione Partido:",
        choices = partidos_unicos,
        selected = "TODOS LOS PARTIDOS"
      ),
      uiOutput("apellidoFilterUI"),
      br(),
      p("Explore la distribución de votos y el detalle por partido al posar el cursor sobre cada comuna en el mapa.", style = "font-size: 0.9em; color: #7f8c8d;")
    ),
    mainPanel(
      tabsetPanel(
        tabPanel("Mapa por Comunas", leafletOutput("mapaComunas", height = 700)),
        tabPanel("Mapa por Locales de Votación", leafletOutput("mapaLocales", height = 700))
      )
    )
  )
)

server <- function(input, output, session) {
  
  output$apellidoFilterUI <- renderUI({
    if (str_detect(input$tipoEleccion, "Presidencial|Alcalde|Concejal|Regional|Parlamentaria|Constitucionales")) {
      selectInput(
        inputId = "apellidoFiltro",
        label = "Seleccione Primer Apellido del Candidato:",
        choices = primer_apellidos_unicos,
        selected = "TODOS LOS CANDIDATOS"
      )
    } else {
      return(NULL)
    }
  })
  
  observeEvent(input$tipoEleccion, {
    if (input$tipoEleccion == "Plebiscito Constitucional") {
      updateSelectInput(session, "partidoFiltro", selected = "TODOS LOS PARTIDOS")
    }
  })
  
  datos_filtrados_base_comunas <- reactive({
    req(input$tipoEleccion, input$añoEleccion)
    data <- datos_elecciones_los_lagos_shiny %>%
      filter(
        tipo_eleccion == input$tipoEleccion,
        año_eleccion == input$añoEleccion,
        !is.na(Comuna)
      )
    if (input$partidoFiltro != "TODOS LOS PARTIDOS") {
      data <- data %>% filter(Partido == input$partidoFiltro)
    }
    if (str_detect(input$tipoEleccion, "Presidencial|Alcalde|Concejal|Regional|Parlamentaria|Constitucionales") &&
        !is.null(input$apellidoFiltro) && input$apellidoFiltro != "TODOS LOS CANDIDATOS") {
      data <- data %>% filter(`Primer apellido` == input$apellidoFiltro)
    }
    return(data)
  })
  
  output$mapaComunas <- renderLeaflet({
    votos_comuna_para_mapa <- datos_filtrados_base_comunas() %>%
      group_by(Comuna_Limpia = limpiar_nombre(Comuna)) %>%
      summarise(Votos_Mapa_Calor = sum(Votos_Totales_Candidato, na.rm = TRUE), .groups = 'drop')
    
    mapa_unido_comunas <- comunas_los_lagos_sf_base %>%
      left_join(votos_comuna_para_mapa, by = "Comuna_Limpia")
    
    mapa_unido_comunas$Votos_Mapa_Calor[is.na(mapa_unido_comunas$Votos_Mapa_Calor)] <- 0
    
    domain_values <- mapa_unido_comunas$Votos_Mapa_Calor
    if (all(is.na(domain_values) | domain_values == 0)) {
      pal_comunas <- colorNumeric(palette = "YlOrRd", domain = c(0, 1))
    } else {
      pal_comunas <- colorNumeric(palette = "YlOrRd", domain = domain_values)
    }
    
    mapa_unido_comunas <- mapa_unido_comunas %>%
      rowwise() %>%
      mutate(
        popup_content = {
          comuna_actual_limpia <- Comuna_Limpia
          detalle_data_comuna <- datos_filtrados_base_comunas() %>%
            filter(Comuna == comuna_actual_limpia)
          
          tipo_actual <- unique(detalle_data_comuna$tipo_eleccion)[1]
          if (tipo_actual == "Plebiscito Constitucional") {
            detalle_sum <- detalle_data_comuna %>%
              group_by(Opciones) %>%
              summarise(Votos_Detalle = sum(Votos_Totales_Candidato, na.rm = TRUE), .groups = 'drop') %>%
              arrange(desc(Votos_Detalle))
            detail_type_label <- "Opción"
            detail_column_name <- "Opciones"
          } else if (tipo_actual %in% c("Municipal (Alcalde)", "Presidencial (1ra vuelta)", "Presidencial (2da vuelta)", "Gobernador Regional (1ra vuelta)", "Gobernador Regional (2da vuelta)")) {
            detalle_sum <- detalle_data_comuna %>%
              mutate(Candidato_Nombre_Completo = paste(Nombres, `Primer apellido`, `Segundo apellido`) %>% str_trim()) %>%
              group_by(Candidato_Nombre_Completo) %>%
              summarise(Votos_Detalle = sum(Votos_Totales_Candidato, na.rm = TRUE), .groups = 'drop') %>%
              arrange(desc(Votos_Detalle))
            detail_type_label <- "Candidato"
            detail_column_name <- "Candidato_Nombre_Completo"
          } else if (tipo_actual %in% c("Concejal", "Constitucionales", "Regional", "Parlamentaria")) {
            detalle_sum <- detalle_data_comuna %>%
              group_by(Partido) %>%
              summarise(Votos_Detalle = sum(Votos_Totales_Candidato, na.rm = TRUE), .groups = 'drop') %>%
              arrange(desc(Votos_Detalle))
            detail_type_label <- "Partido"
            detail_column_name <- "Partido"
          } else {
            detalle_sum <- detalle_data_comuna %>%
              group_by(Partido) %>%
              summarise(Votos_Detalle = sum(Votos_Totales_Candidato, na.rm = TRUE), .groups = 'drop') %>%
              arrange(desc(Votos_Detalle))
            detail_type_label <- "Partido"
            detail_column_name <- "Partido"
          }
          
          html_details <- paste0("<strong>Comuna: ", .data[[nombre_columna_comuna_sf]], "</strong><br/>")
          total_votos_seleccion <- sum(detalle_sum$Votos_Detalle, na.rm = TRUE)
          html_details <- paste0(html_details, "Total Votos (Selección): ", format(total_votos_seleccion, big.mark = ".", decimal.mark = ","), "<br/>")
          
          if (nrow(detalle_sum) > 0 && total_votos_seleccion > 0) {
            html_details <- paste0(html_details, "Detalle por ", detail_type_label, ":<br/>")
            for (i in 1:nrow(detalle_sum)) {
              html_details <- paste0(html_details,
                                     "&nbsp;&nbsp;&nbsp;", detalle_sum[[detail_column_name]][i], ": ",
                                     format(detalle_sum$Votos_Detalle[i], big.mark = ".", decimal.mark = ","), "<br/>")
            }
          } else {
            html_details <- paste0(html_details, "No hay datos detallados para esta selección.")
          }
          html_details
        }
      ) %>%
      ungroup()
    
    leaflet(mapa_unido_comunas) %>%
      addProviderTiles(providers$CartoDB.Positron,
                       options = providerTileOptions(attribution = '&copy; <a href="http://leafletjs.com/copyright">Leaflet</a> &copy; <a href="https://carto.com/attributions">CARTO</a>')
      ) %>%
      addPolygons(
        fillColor = ~pal_comunas(Votos_Mapa_Calor),
        weight = 1, opacity = 1, color = "white", dashArray = "3", fillOpacity = 0.7,
        highlightOptions = highlightOptions(weight = 3, color = "#666", dashArray = "", fillOpacity = 0.7, bringToFront = TRUE),
        label = ~lapply(popup_content, htmltools::HTML),
        labelOptions = labelOptions(
          style = list("font-weight" = "normal", padding = "3px 8px"),
          textsize = "15px",
          direction = "auto"
        )
      ) %>%
      addLegend(
        pal = pal_comunas,
        values = ~Votos_Mapa_Calor,
        opacity = 0.7,
        title = "Votos por Comuna",
        position = "bottomright"
      ) %>%
      addMiniMap(toggleDisplay = TRUE)
  })
  
  # MODIFICACIÓN CLAVE AQUÍ:
  # Ahora, calculamos todo lo necesario para el popup de locales de votación
  # dentro del reactive, para que el renderLeaflet sea mucho más simple.
  datos_para_mapa_locales <- reactive({
    req(input$tipoEleccion, input$añoEleccion)
    
    data <- datos_elecciones_los_lagos_shiny %>%
      filter(
        tipo_eleccion == input$tipoEleccion,
        año_eleccion == input$añoEleccion,
        !is.na(Local)
      )
    
    if (input$partidoFiltro != "TODOS LOS PARTIDOS") {
      data <- data %>% filter(Partido == input$partidoFiltro)
    }
    if (str_detect(input$tipoEleccion, "Presidencial|Alcalde|Concejal|Regional|Parlamentaria|Constitucionales") &&
        !is.null(input$apellidoFiltro) && input$apellidoFiltro != "TODOS LOS CANDIDATOS") {
      data <- data %>% filter(`Primer apellido` == input$apellidoFiltro)
    }
    
    # Agrupamos votos por local, candidato y opciones.
    data_agrupada <- data %>%
      group_by(Local, Comuna, Mesa, Partido, Nombres,
               `Primer apellido`, `Segundo apellido`, Opciones, tipo_eleccion) %>%
      summarise(Votos_Totales = sum(Votos_Totales_Candidato, na.rm = TRUE), .groups = 'drop')
    
    # Unimos con las coordenadas, manejando la relación many-to-many
    data_con_coords <- data_agrupada %>%
      left_join(coordenadas_locales_known, by = "Local", relationship = "many-to-many") %>%
      filter(!is.na(Latitud), !is.na(Longitud))
    
    # Si no hay datos, devolvemos un data frame vacío
    if (nrow(data_con_coords) == 0) {
      return(tibble())
    }
    
    # Calculamos el total de votos por local y el contenido del popup en un solo paso
    data_final_mapa <- data_con_coords %>%
      group_by(Local, Comuna, Latitud, Longitud) %>%
      summarise(
        Total_Local = sum(Votos_Totales, na.rm = TRUE),
        popup_content = {
          # Lógica para construir el HTML del popup para el local actual
          detalle_agregado <- if (unique(tipo_eleccion)[1] == "Plebiscito Constitucional") {
            # Desglose por opciones
            data.frame(
              Key = unique(Opciones),
              Votos = Votos_Totales[match(unique(Opciones), Opciones)]
            )
          } else {
            # Desglose por candidato/partido
            data.frame(
              Key = paste(Nombres, `Primer apellido`, `Segundo apellido`) %>% str_trim(),
              Votos = Votos_Totales,
              Partido = Partido
            ) %>%
              # Asegurarse de que el desglose sea por candidato si el nombre no está vacío
              mutate(Desglose_Key = ifelse(is.na(Key) | Key == "" | is.na(Partido), Partido, Key)) %>%
              group_by(Desglose_Key) %>%
              summarise(Votos = sum(Votos, na.rm = TRUE), .groups = 'drop')
          }
          
          # Construir el detalle HTML del popup
          detalle_html <- paste0(
            "Detalle:<br>",
            paste(
              "&nbsp;&nbsp;&nbsp;",
              detalle_agregado$Desglose_Key, ": ",
              format(detalle_agregado$Votos, big.mark = ".", decimal.mark = ","),
              "<br>"
            ),
            collapse = ""
          )
          
          paste0(
            "<strong>Local: ", unique(Local), "</strong><br>",
            "<strong>Comuna: ", unique(Comuna), "</strong><br>",
            "Total Votos en Local: ", format(Total_Local, big.mark = ".", decimal.mark = ","), "<br>",
            detalle_html
          )
        },
        .groups = 'drop'
      )
    
    # Convertir a un objeto 'sf' al final
    st_as_sf(data_final_mapa, coords = c("Longitud", "Latitud"), crs = 4326)
  })
  
  
  output$mapaLocales <- renderLeaflet({
    map_data_locales <- datos_para_mapa_locales()
    
    if (nrow(map_data_locales) == 0) {
      return(
        leaflet() %>%
          addTiles() %>%
          setView(lng = -72.94, lat = -41.47, zoom = 12) %>%
          addControl(html = "<h4>No hay datos de locales para esta selección o no hay coordenadas.</h4>", position = "topleft")
      )
    }
    
    pal_locales <- colorNumeric(
      palette = "viridis",
      domain = map_data_locales$Total_Local
    )
    
    leaflet(map_data_locales) %>%
      addProviderTiles(providers$CartoDB.Positron) %>%
      addCircleMarkers(
        radius = ~sqrt(Total_Local) / 10 + 2,
        color = ~pal_locales(Total_Local),
        fillOpacity = 0.8,
        stroke = TRUE,
        weight = 1,
        popup = ~lapply(popup_content, htmltools::HTML)
      ) %>%
      addLegend(
        position = "bottomright",
        pal = pal_locales,
        values = ~Total_Local,
        title = "Votos totales<br>por Local",
        opacity = 0.9,
        labFormat = labelFormat(suffix = " votos")
      ) %>%
      setView(lng = -72.94, lat = -41.47, zoom = 12)
  })
}

shinyApp(ui = ui, server = server)
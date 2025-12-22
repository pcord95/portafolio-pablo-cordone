# app.R: Cuestionario de encuesta para la Región de Los Lagos

# 1. Cargar librerías necesarias
# 'shiny' es el framework principal para construir la aplicación.
# 'shinyWidgets' provee controles de entrada más avanzados y estéticos.
# 'shinyjs' es esencial para esconder/mostrar los elementos.
# 'shinythemes' se usa para darle un aspecto moderno a la aplicación.
library(shiny)
library(shinyWidgets)
library(shinyjs) 
library(shinythemes)

# 2. Definir la interfaz de usuario (UI)
# La UI define la apariencia y el diseño de la aplicación web.
ui <- fluidPage(
  useShinyjs(), # Inicializar shinyjs
  theme = shinytheme("cosmo"), # Aplicar un tema moderno
  
  # Estilo CSS personalizado para la matriz de preguntas y secciones
  tags$head(
    tags$style(HTML("
      /* Estilos generales del contenedor de la encuesta */
      #encuesta_container { max-width: 900px; margin: auto; }
      
      /* Estilos para el contenedor de la matriz */
      .matrix-container {
        display: flex;
        flex-direction: column;
        gap: 10px;
        padding: 20px;
        background-color: #f9f9f9;
        border-radius: 8px;
        border: 1px solid #ddd;
      }
      
      /* Estilos para cada fila de la matriz */
      .matrix-row {
        display: flex;
        align-items: center;
        width: 100%;
        margin-top: 10px;
      }

      /* Alineación y estilo del texto de la etiqueta */
      .matrix-row p {
        flex-basis: 35%;
        text-align: left;
        font-weight: bold;
        margin-bottom: 0;
      }
      
      /* Estilos de los botones de matriz tipo slider (termómetro/regla) */
      .matrix-slider-container {
        flex-basis: 60%;
        display: flex;
        align-items: center;
        justify-content: space-between;
        position: relative; /* Para posicionar los números de la escala */
      }
      
      .matrix-slider-container .btn-group {
        width: 100%;
        display: flex;
        position: relative;
        height: 20px; /* Altura de la barra */
        border-radius: 50px; /* Bordes redondeados de la barra */
        overflow: hidden; /* Para que la barra activa no se salga */
        border: 1px solid #ccc;
      }

      .matrix-slider-container .btn-group .btn {
        flex-grow: 1;
        border-radius: 0;
        border: none; /* Eliminar bordes individuales de los segmentos */
        background-color: #e0e0e0; /* Color inactivo */
        color: transparent;
        height: 100%;
        position: relative;
        z-index: 1;
      }
      
      /* Estilo de la barra activa (color de relleno) */
      .matrix-slider-container .btn-group .btn.active {
        background-color: #56A3D4 !important; /* Color azul activo */
        border-color: #56A3D4 !important;
      }

      /* Efecto de 'termómetro' - la barra se llena hasta el punto seleccionado */
      .matrix-slider-container .btn-group .btn.active ~ .btn {
        background-color: #e0e0e0; /* Asegura que los posteriores al activo estén inactivos */
      }
      .matrix-slider-container .btn-group .btn:first-child.active {
          border-top-left-radius: 50px;
          border-bottom-left-radius: 50px;
      }
      .matrix-slider-container .btn-group .btn:last-child.active {
          border-top-right-radius: 50px;
          border-bottom-right-radius: 50px;
      }
      .matrix-slider-container .btn-group .btn.active:not(:last-child) {
          border-top-right-radius: 0;
          border-bottom-right-radius: 0;
      }
      .matrix-slider-container .btn-group .btn:not(:first-child).active {
          border-top-left-radius: 0;
          border-bottom-left-radius: 0;
      }

      /* Estilo de las etiquetas de los números de la escala (1 a 7) */
      .scale-labels {
          position: absolute;
          width: 100%;
          display: flex;
          justify-content: space-between;
          top: -25px; /* Ajustar posición sobre la barra */
          left: 0;
          font-weight: normal;
          color: #555;
      }
      .scale-labels p {
          flex-basis: calc(100% / 6); /* Distribuir uniformemente para 7 puntos */
          text-align: center;
          font-size: 12px;
          margin: 0;
          padding: 0;
          font-weight: bold;
      }
      .scale-labels p:first-child { text-align: left; }
      .scale-labels p:last-child { text-align: right; }
      
      /* Estilos de los radioButtons y checkbox */
      .shiny-input-container:not(.matrix-slider-container) {
          margin-top: 15px;
      }
      .shiny-input-container .radio, .shiny-input-container .checkbox {
          display: block !important;
      }
      .shiny-input-container .radio-inline, .shiny-input-container .checkbox-inline {
          margin-left: 0;
          margin-right: 15px;
      }

      /* Estilos para los títulos de las secciones */
      .section-title {
        color: #004085;
        font-size: 24px;
        margin-bottom: 20px;
        border-bottom: 2px solid #004085;
        padding-bottom: 10px;
      }
      
      /* Estilos para los paneles de las secciones */
      .panel-section {
        padding: 20px;
        border: 1px solid #ccc;
        border-radius: 8px;
        margin-top: 20px;
      }
      
      /* Estilo para los botones de navegación */
      .action-buttons {
        margin-top: 20px;
        display: flex;
        justify-content: space-between;
      }
      .action-buttons .btn-default, .action-buttons .btn-primary, .action-buttons .btn-success {
        border-radius: 5px;
        padding: 10px 20px;
        font-size: 16px;
      }
    "))
  ),
  
  # Contenido principal de la aplicación
  titlePanel(div(h2("Encuesta Elecciones Regionales 2025: Región de Los Lagos"))),
  
  # Contenedor para la encuesta de una sola página
  div(
    id = "encuesta_container",
    
    # 1. Sección de bienvenida
    div(
      id = "seccion_inicio",
      class = "panel-section",
      h4("Bienvenido/a a la encuesta sobre las próximas elecciones en la Región de Los Lagos."),
      p("La información que entregues en este cuestionario es totalmente confidencial y solo serán utilizadas para fines estadísticos y es de carácter voluntaria. Usted puede dejar de responderla en el momento que estime necesario, haciendo click en el botón ABANDONAR en la parte inferior de su pantalla. Si usted responde la encuesta, recibirá el informe de resultados de esta encuesta antes de su publicación."),
      actionButton("next1", "Comenzar Encuesta", class = "btn-primary")
    ),
    
    # 2. Sección de Demografía
    hidden(
      div(
        id = "seccion_demografia",
        class = "panel-section",
        div(class = "section-title", "1. Sección de Demografía y Perfil"),
        
        numericInput("ingresos_hogar", "¿Cuál es el ingreso total aproximado de su hogar (en pesos chilenos)?", value = NULL, min = 0),
        
        selectInput("comuna", "¿En qué comuna de la Región de Los Lagos resides?",
                    choices = c('', 'Ancud' = 'ancud', 'Calbuco' = 'calbuco', 'Castro' = 'castro', 'Chaitén' = 'chaiten', 'Chonchi' = 'chonchi', 'Curaco de Vélez' = 'curaco', 'Dalcahue' = 'dalcahue', 'Futaleufú' = 'futaleufu', 'Hualaihué' = 'hualaihue', 'Maullín' = 'maullin', 'Palena' = 'palena', 'Puerto Montt' = 'ptomontt', 'Puqueldón' = 'puqueldon', 'Queilén' = 'queilen', 'Quellón' = 'quellon', 'Quemchi' = 'quemchi', 'Quinchao' = 'quinchao')),
        radioButtons("sexo", "¿Cuál es tu género?",
                     choices = c("Hombre" = "masculino", "Mujer" = "femenino", "Prefiero no decir" = "no_dice", "Otro" = "otro"), selected = character(0)),
        
        conditionalPanel(
          condition = "input.sexo == 'otro'",
          textInput("sexo_otro", "Por favor, especifique su género:", width = "60%")
        ),
        numericInput("nacimiento", "¿En qué año naciste?", value = NULL, min = 1920, max = 2007),
        selectInput("estudios", "¿Cuál es tu nivel de estudios más alto alcanzado?",
                    choices = c('', 'Básica o menos' = 'basica', 'Media/Técnica' = 'media', 'Técnica Superior' = 'tecnica_superior', 'Universitaria completa' = 'universitaria', 'Postgrado' = 'postgrado')),
        radioButtons("situacion_laboral", "¿Cuál es su situación laboral principal?",
                     choices = c('Empleado/a asalariado/a' = 'asalariado', 'Trabajador/a por cuenta propia' = 'cuenta_propia', 'Desempleado/a' = 'desempleado', 'Estudiante' = 'estudiante', 'Jubilado/a o Pensionado/a' = 'jubilado', 'Trabajo de hogar' = 'hogar', 'Otro' = 'otro'), selected = character(0)),
        div(class = "action-buttons",
            actionButton("back1", "Anterior", class = "btn-default"),
            actionButton("next2", "Siguiente", class = "btn-primary")
        )
      )
    ),
    
    # 3. Sección de Participación Cívica
    hidden(
      div(
        id = "seccion_participacion",
        class = "panel-section",
        div(class = "section-title", "2. Sección de Participación Cívica y Política"),
        radioButtons("interes_politica", "¿Qué tanto te gusta la política?",
                     choices = c("Me encanta", "Me gusta", "Me interesa", "No me gusta", "Me disgusta mucho"), selected = character(0)),
        radioButtons("voto_obligatorio", "¿Qué tan de acuerdo o en desacuerdo estás con la restauración del voto obligatorio?",
                     choices = c("Totalmente de acuerdo", "De acuerdo", "Neutral", "En desacuerdo", "Totalmente en desacuerdo"), selected = character(0)),
        
        # Nueva pregunta: Entusiasmo en elecciones presidenciales y parlamentarias
        radioButtons("entusiasmo_elecciones", "¿Qué tan entusiasmado/a está en participar de las próximas Elecciones Presidenciales y Parlamentarias?",
                     choices = c("Totalmente entusiasmado", "Entusiasmado", "Poco entusiasmado", "Nada entusiasmado", "No me interesa"), selected = character(0)),
        
        # Nueva pregunta: Nivel de confianza en los partidos políticos
        radioButtons("confianza_partidos", "En una escala de 1 a 5, donde 1 es 'Ninguna confianza' y 5 es 'Mucha confianza', ¿cuánta confianza le inspiran los partidos políticos?",
                     choices = 1:5, selected = character(0)),
        
        radioButtons("voto_elecciones_pasadas", "¿Votaste en la última elección de Alcaldes y Gobernadores?",
                     choices = c("Sí", "No", "No recuerdo", "Otro" = "otro_voto_pasado"), selected = character(0)),
        
        conditionalPanel(
          condition = "input.voto_elecciones_pasadas == 'otro_voto_pasado'",
          textInput("voto_elecciones_pasadas_otro", "Por favor, especifique:", width = "60%")
        ),
        
        checkboxGroupInput("valoracion_politicas", "Cuál es la política pública que más valora de los últimos 4 años? (Marque un máximo de 3 opciones)",
                           choices = c('Programa de vivienda' = 'vivienda', 'Mejoras en salud regional' = 'salud', 'Subsidios al transporte público' = 'transporte', 'Apoyo a la pequeña agricultura' = 'agricultura', 'Incentivos al turismo' = 'turismo', 'Protección del medio ambiente' = 'medio_ambiente', 'Otro' = 'otro_politica', 'No sabe/No responde' = 'no_sabe_politica')),
        conditionalPanel(
          condition = "input.valoracion_politicas.includes('otro_politica')",
          textInput("valoracion_politicas_otro", "Por favor, especifique otra política pública:", width = "60%")
        ),
        
        # Nueva pregunta de conocimiento
        radioButtons("conocimiento_politico", "¿Cuál de los siguientes organismos es responsable de la política monetaria en Chile?",
                     choices = c("Banco Central de Chile", "Ministerio de Hacienda", "Servicio de Impuestos Internos", "Comisión para el Mercado Financiero", "No sabe/No responde"), selected = character(0)),
        
        div(class = "action-buttons",
            actionButton("back2", "Anterior", class = "btn-default"),
            actionButton("next3", "Siguiente", class = "btn-primary")
        )
      )
    ),
    
    # 4. Sección de Opinión y Matriz
    hidden(
      div(
        id = "seccion_opinion",
        class = "panel-section",
        div(class = "section-title", "3. Sección de Percepción y Opinión"),
        
        radioButtons("valor_mas_relevante", "¿Cuál de estos valores cree usted que es el más relevante para una sociedad?",
                     choices = c("Orden", "Justicia", "Libertad", "Solidaridad", "Mérito", "Otros"), selected = character(0)),
        conditionalPanel(
          condition = "input.valor_mas_relevante == 'Otros'",
          textInput("valor_mas_relevante_otro", "¿Cuál?:", width = "60%")
        ),
        radioButtons("valor_menos_relevante", "¿Cuál de estos valores cree usted que es el menos relevante para una sociedad?",
                     choices = c("Orden", "Justicia", "Libertad", "Solidaridad", "Mérito", "Otros"), selected = character(0)),
        conditionalPanel(
          condition = "input.valor_menos_relevante == 'Otros'",
          textInput("valor_menos_relevante_otro", "¿Cuál?:", width = "60%")
        ),
        
        # Pregunta de matriz tipo Likert con barras (escala 1 a 7)
        div(
          class = "matrix-container",
          div(class = "matrix-title", "En una escala de 1 a 7, ¿cómo evalúa la situación de los siguientes aspectos en su vida diaria en los últimos 4 años?"),
          div(class = "matrix-row",
              p("Vivienda"),
              div(class = "matrix-slider-container",
                  div(class = "scale-labels", lapply(1:7, function(x) p(x))),
                  radioGroupButtons("mejora_vida_vivienda", label = NULL, choices = 1:7, justified = TRUE, size = "sm", selected = character(0))
              )
          ),
          div(class = "matrix-row",
              p("Salud"),
              div(class = "matrix-slider-container",
                  div(class = "scale-labels", lapply(1:7, function(x) p(x))),
                  radioGroupButtons("mejora_vida_salud", label = NULL, choices = 1:7, justified = TRUE, size = "sm", selected = character(0))
              )
          ),
          div(class = "matrix-row",
              p("Trabajo"),
              div(class = "matrix-slider-container",
                  div(class = "scale-labels", lapply(1:7, function(x) p(x))),
                  radioGroupButtons("mejora_vida_trabajo", label = NULL, choices = 1:7, justified = TRUE, size = "sm", selected = character(0))
              )
          ),
          div(class = "matrix-row",
              p("Familia"),
              div(class = "matrix-slider-container",
                  div(class = "scale-labels", lapply(1:7, function(x) p(x))),
                  radioGroupButtons("mejora_vida_familia", label = NULL, choices = 1:7, justified = TRUE, size = "sm", selected = character(0))
              )
          ),
          div(class = "matrix-row",
              p("Educación"),
              div(class = "matrix-slider-container",
                  div(class = "scale-labels", lapply(1:7, function(x) p(x))),
                  radioGroupButtons("mejora_vida_educacion", label = NULL, choices = 1:7, justified = TRUE, size = "sm", selected = character(0))
              )
          ),
          div(class = "matrix-row",
              p("Transporte"),
              div(class = "matrix-slider-container",
                  div(class = "scale-labels", lapply(1:7, function(x) p(x))),
                  radioGroupButtons("mejora_vida_transporte", label = NULL, choices = 1:7, justified = TRUE, size = "sm", selected = character(0))
              )
          )
        ),
        
        # Nueva pregunta de matriz sobre instituciones (escala 1 a 7)
        div(
          class = "matrix-container",
          div(class = "matrix-title", "En una escala de 1 a 7, ¿cómo evalúa el trabajo de las siguientes instituciones locales?"),
          div(class = "matrix-row",
              p("Gobierno Regional"),
              div(class = "matrix-slider-container",
                  div(class = "scale-labels", lapply(1:7, function(x) p(x))),
                  radioGroupButtons("mejora_institucion_gobierno_regional", label = NULL, choices = 1:7, justified = TRUE, size = "sm", selected = character(0))
              )
          ),
          div(class = "matrix-row",
              p("Municipio"),
              div(class = "matrix-slider-container",
                  div(class = "scale-labels", lapply(1:7, function(x) p(x))),
                  radioGroupButtons("mejora_institucion_municipio", label = NULL, choices = 1:7, justified = TRUE, size = "sm", selected = character(0))
              )
          ),
          div(class = "matrix-row",
              p("Delegación Presidencial"),
              div(class = "matrix-slider-container",
                  div(class = "scale-labels", lapply(1:7, function(x) p(x))),
                  radioGroupButtons("mejora_institucion_delegacion", label = NULL, choices = 1:7, justified = TRUE, size = "sm", selected = character(0))
              )
          ),
          div(class = "matrix-row",
              p("SEREMIS"),
              div(class = "matrix-slider-container",
                  div(class = "scale-labels", lapply(1:7, function(x) p(x))),
                  radioGroupButtons("mejora_institucion_seremis", label = NULL, choices = 1:7, justified = TRUE, size = "sm", selected = character(0))
              )
          ),
          div(class = "matrix-row",
              p("Diputados/as"),
              div(class = "matrix-slider-container",
                  div(class = "scale-labels", lapply(1:7, function(x) p(x))),
                  radioGroupButtons("mejora_institucion_diputados", label = NULL, choices = 1:7, justified = TRUE, size = "sm", selected = character(0))
              )
          ),
          div(class = "matrix-row",
              p("Senadores"),
              div(class = "matrix-slider-container",
                  div(class = "scale-labels", lapply(1:7, function(x) p(x))),
                  radioGroupButtons("mejora_institucion_senadores", label = NULL, choices = 1:7, justified = TRUE, size = "sm", selected = character(0))
              )
          ),
          div(class = "matrix-row",
              p("Concejales"),
              div(class = "matrix-slider-container",
                  div(class = "scale-labels", lapply(1:7, function(x) p(x))),
                  radioGroupButtons("mejora_institucion_concejales", label = NULL, choices = 1:7, justified = TRUE, size = "sm", selected = character(0))
              )
          ),
          div(class = "matrix-row",
              p("Consejeros Regionales"),
              div(class = "matrix-slider-container",
                  div(class = "scale-labels", lapply(1:7, function(x) p(x))),
                  radioGroupButtons("mejora_institucion_cores", label = NULL, choices = 1:7, justified = TRUE, size = "sm", selected = character(0))
              )
          )
        ),
        
        textInput("problema_comuna", "Escriba aquí, en una o dos frases, el principal problema o desafío de su comuna."),
        div(class = "action-buttons",
            actionButton("back3", "Anterior", class = "btn-default"),
            actionButton("next4", "Siguiente", class = "btn-primary")
        )
      )
    ),
    
    # 5. Sección de Voto y Candidatos
    hidden(
      div(
        id = "seccion_voto",
        class = "panel-section",
        div(class = "section-title", "4. Sección de Voto y Candidatos"),
        
        # Nueva pregunta: Características valoradas en un candidato
        checkboxGroupInput("caracteristicas_candidato", "¿Qué características valora más en un candidato/a (marque un máximo de 3)?",
                           choices = c("Honestidad" = "honestidad", "Experiencia política" = "experiencia", "Cercanía con la gente" = "cercania", "Capacidad de gestión" = "gestion", "Ideología" = "ideologia", "Liderazgo" = "liderazgo", "Propuestas claras" = "propuestas", "Otro" = "otro_caracteristica"),
                           selected = character(0)),
        conditionalPanel(
          condition = "input.caracteristicas_candidato.includes('otro_caracteristica')",
          textInput("caracteristicas_candidato_otro", "Por favor, especifique otra característica:", width = "60%")
        ),
        
        radioButtons("voto_presidencial", "Si las elecciones presidenciales fueran este fin de semana, ¿por quién votaría?", 
                     choices = c('Jeannette Jara' = 'jara', 'José Antonio Kast' = 'kast', 'Evelyn Matthei' = 'matthei', 'Franco Parisi' = 'parisi', 'Johannes Kaiser' = 'kaiser', 'Marco Enriquez-Ominami' = 'meo', 'Eduardo Artés' = 'artes', 'Harold Mayne-Nicholls' = 'harold', 'No sabe/No responde' = 'no_sabe_presidencial'), selected = character(0)),
        
        # Escenarios de segunda vuelta generados dinámicamente
        uiOutput("segunda_vuelta_scenarios"),
        
        # Nueva pregunta: Voto por coalición parlamentaria
        radioButtons("voto_coalicion_parlamentaria", "¿A cuál de este conjunto de partidos es probable que usted le dé el voto?",
                     choices = c("Pacto por la Dignidad" = "pacto_dignidad", "Chile Vamos" = "chile_vamos", "Republicanos" = "republicanos", "Socialismo Democrático" = "socialismo_democratico", "Otro" = "otro_coalicion"), selected = character(0)),
        
        conditionalPanel(
          condition = "input.voto_coalicion_parlamentaria == 'otro_coalicion'",
          textInput("voto_coalicion_parlamentaria_otro", "Por favor, especifique otra coalición:", width = "60%")
        ),
        
        # Candidatos a diputado generados dinámicamente según la coalición
        uiOutput("candidatos_diputados_dinamicos"),
        
        textInput("razones_voto", "Razón más importante para su decisión de voto."),
        div(class = "action-buttons",
            actionButton("back4", "Anterior", class = "btn-default"),
            actionButton("submit", "Finalizar Encuesta", class = "btn-success")
        )
      )
    ),
    
    # 6. Sección de Finalización
    hidden(
      div(
        id = "seccion_fin",
        class = "panel-section",
        h3("¡Encuesta finalizada!"),
        p("Gracias por participar en esta importante encuesta. Tu opinión es fundamental para este estudio."),
        downloadButton("downloadData", "Descargar mis respuestas")
      )
    )
  )
)

# 3. Definir la lógica del servidor (Server)
# El servidor maneja la reactividad y las interacciones de la aplicación.
server <- function(input, output, session) {
  
  # Lógica para avanzar y retroceder entre las secciones
  observeEvent(input$next1, {
    hide("seccion_inicio")
    show("seccion_demografia")
  })
  
  # Validación de Demografía y avance
  observeEvent(input$next2, {
    # Validar que input$ingresos_hogar no sea NULL y no sea NA
    ingresos_validos <- !is.null(input$ingresos_hogar) && !is.na(input$ingresos_hogar)
    
    demografia_completa <- ingresos_validos &&
      !is.null(input$comuna) && input$comuna != "" &&
      !is.null(input$sexo) &&
      !is.null(input$nacimiento) && !is.na(input$nacimiento) &&
      !is.null(input$estudios) && input$estudios != "" &&
      !is.null(input$situacion_laboral)
    
    if (demografia_completa) {
      # Aquí se guardan los datos de la sección de Demografía
      data_demografia <- reactive({
        data.frame(
          ingresos_hogar = input$ingresos_hogar,
          comuna = input$comuna,
          sexo = input$sexo,
          nacimiento = input$nacimiento,
          estudios = input$estudios,
          situacion_laboral = input$situacion_laboral,
          sexo_otro = if (input$sexo == 'otro') input$sexo_otro else NA,
          timestamp = Sys.time()
        )
      })
      # firebase::set_doc(
      #   db,
      #   collection = "encuestas",
      #   doc = paste0("encuesta_user_", app_id, "_", auth$get_user()$uid),
      #   data = list(demografia = data_demografia())
      # )
      
      hide("seccion_demografia")
      show("seccion_participacion")
    } else {
      showModal(modalDialog(
        title = "Atención",
        "Por favor, complete todas las preguntas de esta sección antes de continuar.",
        easyClose = TRUE
      ))
    }
  })
  
  # Botón de retroceso de Demografía
  observeEvent(input$back1, {
    hide("seccion_demografia")
    show("seccion_inicio")
  })
  
  # Validación de Participación y avance
  observeEvent(input$next3, {
    # Validación para la política pública (máximo 3 opciones)
    valoracion_politicas_validas <- length(input$valoracion_politicas) <= 3 && length(input$valoracion_politicas) > 0
    
    participacion_completa <- !is.null(input$interes_politica) &&
      !is.null(input$voto_obligatorio) &&
      !is.null(input$entusiasmo_elecciones) && # Nueva pregunta
      !is.null(input$confianza_partidos) &&
      !is.null(input$voto_elecciones_pasadas) &&
      valoracion_politicas_validas &&
      !is.null(input$conocimiento_politico) # Nueva pregunta
    
    if (participacion_completa) {
      # Aquí se guardan los datos de la sección de Participación
      data_participacion <- reactive({
        data.frame(
          interes_politica = input$interes_politica,
          voto_obligatorio = input$voto_obligatorio,
          entusiasmo_elecciones = input$entusiasmo_elecciones, # Nueva pregunta
          confianza_partidos = input$confianza_partidos,
          voto_elecciones_pasadas = input$voto_elecciones_pasadas,
          voto_elecciones_pasadas_otro = if (input$voto_elecciones_pasadas == 'otro_voto_pasado') input$voto_elecciones_pasadas_otro else NA,
          valoracion_politicas = paste(input$valoracion_politicas, collapse=";"),
          valoracion_politicas_otro = if ('otro_politica' %in% input$valoracion_politicas) input$valoracion_politicas_otro else NA,
          conocimiento_politico = input$conocimiento_politico, # Nueva pregunta
          timestamp = Sys.time()
        )
      })
      # firebase::update_doc(
      #   db,
      #   collection = "encuestas",
      #   doc = paste0("encuesta_user_", app_id, "_", auth$get_user()$uid),
      #   data = list(participacion = data_participacion())
      # )
      
      hide("seccion_participacion")
      show("seccion_opinion")
    } else {
      showModal(modalDialog(
        title = "Atención",
        "Por favor, complete todas las preguntas de esta sección antes de continuar. Asegúrese de marcar un máximo de 3 políticas públicas.",
        easyClose = TRUE
      ))
    }
  })
  
  # Botón de retroceso de Participación
  observeEvent(input$back2, {
    hide("seccion_participacion")
    show("seccion_demografia")
  })
  
  # Lógica para generar escenarios de segunda vuelta
  output$segunda_vuelta_scenarios <- renderUI({
    req(input$voto_presidencial) # Asegurarse de que ya se haya votado en primera vuelta
    
    candidatos_principales_ids <- c('jara', 'kast', 'matthei', 'parisi')
    nombres_candidatos_map <- c(
      'jara' = 'Jeannette Jara',
      'kast' = 'José Antonio Kast',
      'matthei' = 'Evelyn Matthei',
      'parisi' = 'Franco Parisi'
    )
    
    voto_primera_vuelta_id <- input$voto_presidencial
    
    # Excluir el candidato votado y "No sabe/No responde" de los escenarios
    candidatos_para_escenarios_ids <- setdiff(candidatos_principales_ids, voto_primera_vuelta_id)
    
    # Si el candidato votado es uno de los principales, incluirlo en los escenarios
    if (voto_primera_vuelta_id %in% candidatos_principales_ids) {
      candidatos_para_escenarios_ids <- unique(c(voto_primera_vuelta_id, candidatos_para_escenarios_ids))
    }
    
    lista_preguntas <- tagList()
    
    if (length(candidatos_para_escenarios_ids) >= 2) {
      combinaciones <- combn(candidatos_para_escenarios_ids, 2, simplify = FALSE)
      
      # Filtrar combinaciones para asegurar que el candidato de primera vuelta esté en al menos un escenario
      if (voto_primera_vuelta_id %in% candidatos_principales_ids) {
        combinaciones_con_primera <- Filter(function(x) voto_primera_vuelta_id %in% x, combinaciones)
        combinaciones_sin_primera <- setdiff(combinaciones, combinaciones_con_primera)
        
        if (length(combinaciones_con_primera) > 0) {
          escenario1 <- sample(combinaciones_con_primera, 1)[[1]]
          combinaciones_restantes <- setdiff(combinaciones, list(escenario1))
          
          if (length(combinaciones_restantes) >= 2) {
            escenarios_restantes <- sample(combinaciones_restantes, 2)
            escenarios_elegidos <- c(list(escenario1), escenarios_restantes)
          } else if (length(combinaciones_restantes) == 1) {
            escenarios_elegidos <- c(list(escenario1), combinaciones_restantes)
          } else {
            escenarios_elegidos <- list(escenario1)
          }
        } else {
          escenarios_elegidos <- sample(combinaciones, min(3, length(combinaciones)))
        }
      } else { # Si el voto de primera vuelta no es un candidato principal, solo generar 3 escenarios aleatorios
        escenarios_elegidos <- sample(combinaciones, min(3, length(combinaciones)))
      }
      
      # Asegurar que no haya duplicados en los escenarios elegidos
      escenarios_elegidos <- unique(escenarios_elegidos)
      
      for (i in 1:min(3, length(escenarios_elegidos))) {
        escenario <- escenarios_elegidos[[i]]
        candidato1_id <- escenario[1]
        candidato2_id <- escenario[2]
        
        nombre1 <- nombres_candidatos_map[candidato1_id]
        nombre2 <- nombres_candidatos_map[candidato2_id]
        
        # Usar nombres completos como choices y values
        lista_preguntas <- tagAppendChild(lista_preguntas, radioButtons(
          inputId = paste0("voto_segunda_vuelta_escenario_", i),
          label = paste0("Escenario ", i, ": Si en segunda vuelta llegan ", nombre1, " y ", nombre2, ", ¿por cuál votaría usted?"),
          choices = c(nombre1 = nombre1, nombre2 = nombre2, 'Nulo/a' = 'nulo', 'No votaría' = 'no_votaria'),
          selected = character(0)
        ))
      }
    } else {
      lista_preguntas <- p("No hay suficientes candidatos principales para generar escenarios de segunda vuelta.")
    }
    
    lista_preguntas
  })
  
  # Validación de Opinión y avance
  observeEvent(input$next4, {
    # Validar los escenarios de segunda vuelta generados dinámicamente
    # Se asume que se generan 3 escenarios, ajustar si cambia la lógica de generación
    # Se utiliza is.null(input$id) || input$id == "" para manejar inputs no generados o vacíos
    escenario1_completo <- is.null(input$voto_segunda_vuelta_escenario_1) || input$voto_segunda_vuelta_escenario_1 != ""
    escenario2_completo <- is.null(input$voto_segunda_vuelta_escenario_2) || input$voto_segunda_vuelta_escenario_2 != ""
    escenario3_completo <- is.null(input$voto_segunda_vuelta_escenario_3) || input$voto_segunda_vuelta_escenario_3 != ""
    
    opinion_completa <- !is.null(input$valor_mas_relevante) &&
      !is.null(input$valor_menos_relevante) &&
      !is.null(input$mejora_vida_vivienda) &&
      !is.null(input$mejora_vida_salud) &&
      !is.null(input$mejora_vida_trabajo) &&
      !is.null(input$mejora_vida_familia) &&
      !is.null(input$mejora_vida_educacion) &&
      !is.null(input$mejora_vida_transporte) &&
      !is.null(input$mejora_institucion_gobierno_regional) &&
      !is.null(input$mejora_institucion_municipio) &&
      !is.null(input$mejora_institucion_delegacion) &&
      !is.null(input$mejora_institucion_seremis) &&
      !is.null(input$mejora_institucion_diputados) &&
      !is.null(input$mejora_institucion_senadores) &&
      !is.null(input$mejora_institucion_concejales) &&
      !is.null(input$mejora_institucion_cores) &&
      input$problema_comuna != "" &&
      escenario1_completo && escenario2_completo && escenario3_completo
    
    if (opinion_completa) {
      # Aquí se guardan los datos de la sección de Opinión
      data_opinion <- reactive({
        data.frame(
          voto_segunda_vuelta_escenario_1 = input$voto_segunda_vuelta_escenario_1,
          voto_segunda_vuelta_escenario_2 = input$voto_segunda_vuelta_escenario_2,
          voto_segunda_vuelta_escenario_3 = input$voto_segunda_vuelta_escenario_3,
          valor_mas_relevante = input$valor_mas_relevante,
          valor_mas_relevante_otro = if (input$valor_mas_relevante == 'Otros') input$valor_mas_relevante_otro else NA,
          valor_menos_relevante = input$valor_menos_relevante,
          valor_menos_relevante_otro = if (input$valor_menos_relevante == 'Otros') input$valor_menos_relevante_otro else NA,
          mejora_vida_vivienda = input$mejora_vida_vivienda,
          mejora_vida_salud = input$mejora_vida_salud,
          mejora_vida_trabajo = input$mejora_vida_trabajo,
          mejora_vida_familia = input$mejora_vida_familia,
          mejora_vida_educacion = input$mejora_vida_educacion,
          mejora_vida_transporte = input$mejora_vida_transporte,
          mejora_institucion_gobierno_regional = input$mejora_institucion_gobierno_regional,
          mejora_institucion_municipio = input$mejora_institucion_municipio,
          mejora_institucion_delegacion = input$mejora_institucion_delegacion,
          mejora_institucion_seremis = input$mejora_institucion_seremis,
          mejora_institucion_diputados = input$mejora_institucion_diputados,
          mejora_institucion_senadores = input$mejora_institucion_senadores,
          mejora_institucion_concejales = input$mejora_institucion_concejales,
          mejora_institucion_cores = input$mejora_institucion_cores,
          problema_comuna = input$problema_comuna,
          timestamp = Sys.time()
        )
      })
      # firebase::update_doc(
      #   db,
      #   collection = "encuestas",
      #   doc = paste0("encuesta_user_", app_id, "_", auth$get_user()$uid),
      #   data = list(opinion = data_opinion())
      # )
      
      hide("seccion_opinion")
      show("seccion_voto")
    } else {
      showModal(modalDialog(
        title = "Atención",
        "Por favor, complete todas las preguntas de esta sección antes de continuar.",
        easyClose = TRUE
      ))
    }
  })
  
  # Botón de retroceso de Opinión
  observeEvent(input$back3, {
    hide("seccion_opinion")
    show("seccion_participacion")
  })
  
  # Lógica para generar candidatos a diputados dinámicamente
  output$candidatos_diputados_dinamicos <- renderUI({
    req(input$voto_coalicion_parlamentaria)
    
    coalicion_elegida <- input$voto_coalicion_parlamentaria
    
    # Definir candidatos por coalición (ejemplo)
    candidatos_por_coalicion <- list(
      "pacto_dignidad" = c("Candidato 1A", "Candidato 1B", "Candidato 1C", "Candidato 1D", "Candidato 1E", "Candidato 1F"),
      "chile_vamos" = c("Candidato 2A", "Candidato 2B", "Candidato 2C", "Candidato 2D", "Candidato 2E", "Candidato 2F"),
      "republicanos" = c("Candidato 3A", "Candidato 3B", "Candidato 3C", "Candidato 3D", "Candidato 3E", "Candidato 3F"),
      "socialismo_democratico" = c("Candidato 4A", "Candidato 4B", "Candidato 4C", "Candidato 4D", "Candidato 4E", "Candidato 4F")
    )
    
    if (coalicion_elegida %in% names(candidatos_por_coalicion)) {
      choices_candidatos <- setNames(candidatos_por_coalicion[[coalicion_elegida]], candidatos_por_coalicion[[coalicion_elegida]])
      choices_candidatos <- c(choices_candidatos, 'Otro/a' = 'otro_diputado', 'No sabe/No responde' = 'no_sabe_diputado', 'No votaría' = 'no_vota_diputado')
      
      radioButtons(
        inputId = "voto_diputado",
        label = paste0("¿Por cuál de estos candidatos de la coalición ", input$voto_coalicion_parlamentaria, " votaría?"),
        choices = choices_candidatos,
        selected = character(0)
      )
    } else {
      # Si la opción es "Otro" en coalición, o no se ha seleccionado, mostrar la pregunta original de diputados
      radioButtons(
        inputId = "voto_diputado",
        label = "Si las elecciones fueran este fin de semana, ¿por cuál de estos candidatos a diputado votaría?",
        choices = c('Alexis Osses' = 'osses', 'Hector Ulloa' = 'ulloa', 'Alejandro Bernales' = 'bernales', 'Jaime Saez' = 'saez', 'Feve Hugo' = 'hugo', 'Otro/a' = 'otro_diputado', 'No sabe/No responde' = 'no_sabe_diputado', 'No votaría' = 'no_vota_diputado'), 
        selected = character(0)
      )
    }
  })
  
  # Validación de Voto y finalización
  observeEvent(input$submit, {
    # Validar que al menos una característica de candidato esté seleccionada
    caracteristicas_validas <- length(input$caracteristicas_candidato) > 0 && length(input$caracteristicas_candidato) <= 3
    
    # Validar que los escenarios de segunda vuelta estén completos si se generaron
    escenario1_completo <- is.null(input$voto_segunda_vuelta_escenario_1) || input$voto_segunda_vuelta_escenario_1 != ""
    escenario2_completo <- is.null(input$voto_segunda_vuelta_escenario_2) || input$voto_segunda_vuelta_escenario_2 != ""
    escenario3_completo <- is.null(input$voto_segunda_vuelta_escenario_3) || input$voto_segunda_vuelta_escenario_3 != ""
    
    voto_completo <- caracteristicas_validas &&
      !is.null(input$voto_presidencial) &&
      escenario1_completo && escenario2_completo && escenario3_completo && # Validar escenarios
      !is.null(input$voto_coalicion_parlamentaria) &&
      !is.null(input$voto_diputado) && # Validar el candidato a diputado dinámico
      input$razones_voto != ""
    
    if (voto_completo) {
      # Aquí se guardan los datos de la sección de Voto
      data_voto <- reactive({
        data.frame(
          caracteristicas_candidato = paste(input$caracteristicas_candidato, collapse=";"),
          caracteristicas_candidato_otro = if ('otro_caracteristica' %in% input$caracteristicas_candidato) input$caracteristicas_candidato_otro else NA,
          voto_presidencial = input$voto_presidencial,
          voto_presidencial_otro = if (input$voto_presidencial == 'otros_presidencial') input$voto_presidencial_otro else NA,
          voto_segunda_vuelta_escenario_1 = input$voto_segunda_vuelta_escenario_1,
          voto_segunda_vuelta_escenario_2 = input$voto_segunda_vuelta_escenario_2,
          voto_segunda_vuelta_escenario_3 = input$voto_segunda_vuelta_escenario_3,
          voto_coalicion_parlamentaria = input$voto_coalicion_parlamentaria,
          voto_coalicion_parlamentaria_otro = if (input$voto_coalicion_parlamentaria == 'otro_coalicion') input$voto_coalicion_parlamentaria_otro else NA,
          voto_diputado = input$voto_diputado,
          voto_diputado_otro = if (input$voto_diputado == 'otro_diputado') input$voto_diputado_otro else NA,
          razones_voto = input$razones_voto,
          timestamp = Sys.time()
        )
      })
      # firebase::update_doc(
      #   db,
      #   collection = "encuestas",
      #   doc = paste0("encuesta_user_", app_id, "_", auth$get_user()$uid),
      #   data = list(voto = data_voto(), estado_encuesta = "finalizada")
      # )
      
      hide("seccion_voto")
      show("seccion_fin")
    } else {
      showModal(modalDialog(
        title = "Atención",
        "Por favor, complete todas las preguntas de esta sección para finalizar. Asegúrese de marcar un máximo de 3 características de candidato.",
        easyClose = TRUE
      ))
    }
  })
  
  # Botón de retroceso de Voto
  observeEvent(input$back4, {
    hide("seccion_voto")
    show("seccion_opinion")
  })
  
  # Guardado de respuestas (solo para usuario actual)
  respuestas <- reactive({
    data.frame(
      comuna = input$comuna, sexo = input$sexo, nacimiento = input$nacimiento, estudios = input$estudios,
      situacion_laboral = input$situacion_laboral, ingresos_hogar = input$ingresos_hogar,
      interes_politica = input$interes_politica, voto_obligatorio = input$voto_obligatorio,
      entusiasmo_elecciones = input$entusiasmo_elecciones,
      confianza_partidos = input$confianza_partidos,
      voto_elecciones_pasadas = input$voto_elecciones_pasadas,
      valoracion_politicas = paste(input$valoracion_politicas, collapse=";"),
      conocimiento_politico = input$conocimiento_politico,
      caracteristicas_candidato = paste(input$caracteristicas_candidato, collapse=";"),
      voto_presidencial = input$voto_presidencial,
      voto_segunda_vuelta_escenario_1 = input$voto_segunda_vuelta_escenario_1,
      voto_segunda_vuelta_escenario_2 = input$voto_segunda_vuelta_escenario_2,
      voto_segunda_vuelta_escenario_3 = input$voto_segunda_vuelta_escenario_3,
      conoce_lista_parlamentaria = input$conoce_lista_parlamentaria,
      nombre_lista_parlamentaria = input$nombre_lista_parlamentaria,
      lista_parlamentaria_opciones = input$lista_parlamentaria_opciones,
      voto_diputado = input$voto_diputado,
      razones_voto = input$razones_voto,
      fecha = Sys.time()
    )
  })
  output$downloadData <- downloadHandler(
    filename = function() { paste("respuestas_encuesta.csv") },
    content = function(file) {
      write.csv(respuestas(), file, row.names=FALSE, fileEncoding="UTF-8")
    }
  )
}

# 4. Crear la aplicación Shiny
shinyApp(ui, server)

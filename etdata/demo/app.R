# ETData · demo público (portafolio de Pablo Cordone Sánchez)
# Versión de muestra con funciones limitadas. Trabaja sobre índices ya calculados
# (percentiles por posición, estilo de equipos y similitud "juega parecido"); no incluye
# el motor de cálculo ni estadísticas crudas. El archivo de datos no se publica en el repositorio.
library(shiny)
library(bslib)
library(DT)
library(ggplot2)

datos <- readRDS("datos_demo.rds")
J <- datos$jugadores; M <- datos$metricas; E <- datos$equipos; P <- datos$parecidos; Z <- datos$zonas; I <- datos$info
ACENTO <- "#8a3b1f"; TINTA <- "#161616"; PAPEL <- "#f3efe6"; GRIS2 <- "#5d6b7a"
fecha <- function(d) format(as.Date(d), "%d-%m-%Y")
aviso <- sprintf("Muestra: Primera División y Primera B de Chile, del %s al %s · %d jugadores de campo con edad registrada y 450' o más · %d partidos. Se muestran solo índices derivados (percentiles y similitud), no estadísticas crudas.",
                 fecha(I$desde), fecha(I$hasta), I$n_jugadores, I$partidos)

tema <- bs_theme(version = 5, bg = PAPEL, fg = TINTA, primary = ACENTO, secondary = GRIS2,
                 base_font = font_google("IBM Plex Sans"), heading_font = font_google("Fraunces"),
                 code_font = font_google("IBM Plex Mono"), "border-radius" = "0", "font-size-base" = "0.95rem")

# ---------- gráficos ----------
barras_percentil <- function(eje, p, titulo = NULL, col = ACENTO) {
  d <- data.frame(eje = factor(eje, levels = rev(eje)), p = p)
  ggplot(d, aes(p, eje)) + geom_col(fill = col, width = 0.55) +
    geom_vline(xintercept = 50, linetype = "dashed", colour = "#9b9282", linewidth = 0.4) +
    geom_text(aes(label = p), hjust = -0.3, size = 3.4, colour = TINTA) +
    scale_x_continuous(limits = c(0, 108), breaks = c(0, 25, 50, 75, 100)) +
    labs(x = "Percentil (50 = mediana)", y = NULL, title = titulo) +
    theme_minimal(base_size = 12) +
    theme(panel.grid.minor = element_blank(), panel.grid.major.y = element_blank(),
          plot.background = element_rect(fill = PAPEL, colour = NA), plot.title = element_text(face = "bold"))
}

cancha_zonas <- function(pid, titulo) {
  z <- Z[Z$player_id == pid, , drop = FALSE]; if (!nrow(z)) return(NULL)
  zn <- grep("^z[0-9]_", names(z), value = TRUE)
  carril <- c(D = 0, dD = 1, C = 2, dI = 3, I = 4); y0 <- c(0, 20, 37, 63, 80); y1 <- c(20, 37, 63, 80, 100)
  d <- data.frame(fx = as.integer(substr(zn, 2, 2)), fy = carril[sub("^z[0-9]_", "", zn)], v = as.numeric(z[1, zn]))
  d$v <- 100 * d$v / sum(d$v)
  d$x0 <- d$fx * 105 / 6; d$x1 <- (d$fx + 1) * 105 / 6; d$ya <- y0[d$fy + 1] * 0.68; d$yb <- y1[d$fy + 1] * 0.68
  lin <- "#3a3631"
  ggplot(d) +
    geom_rect(aes(xmin = x0, xmax = x1, ymin = ya, ymax = yb, alpha = v), fill = ACENTO, colour = NA) +
    geom_text(aes((x0 + x1) / 2, (ya + yb) / 2, label = ifelse(v >= 3, paste0(round(v), "%"), "")), size = 3.2,
              colour = ifelse(d$v > max(d$v) * 0.55, PAPEL, TINTA)) +
    annotate("rect", xmin = 0, xmax = 105, ymin = 0, ymax = 68, fill = NA, colour = lin, linewidth = 0.4) +
    annotate("segment", x = 52.5, xend = 52.5, y = 0, yend = 68, colour = lin, linewidth = 0.4) +
    annotate("path", x = 52.5 + 9.15 * cos(seq(0, 2 * pi, length.out = 80)), y = 34 + 9.15 * sin(seq(0, 2 * pi, length.out = 80)), colour = lin, linewidth = 0.4) +
    annotate("rect", xmin = 0, xmax = 16.5, ymin = 13.84, ymax = 54.16, fill = NA, colour = lin, linewidth = 0.4) +
    annotate("rect", xmin = 88.5, xmax = 105, ymin = 13.84, ymax = 54.16, fill = NA, colour = lin, linewidth = 0.4) +
    annotate("text", x = 104, y = -3, label = "ataca →", hjust = 1, size = 3, colour = "#6b655a") +
    scale_alpha(range = c(0.06, 0.95), guide = "none") + coord_fixed(xlim = c(0, 105), ylim = c(-4, 68), expand = FALSE) +
    labs(title = titulo) + theme_void(base_size = 12) +
    theme(plot.background = element_rect(fill = PAPEL, colour = NA), plot.title = element_text(face = "bold", hjust = 0))
}

# ---------- interfaz ----------
ui <- page_navbar(
  id = "nav",
  title = tags$span("ETData", tags$small(" · demo", style = "color:#8a3b1f;font-family:'IBM Plex Mono';font-size:.75em")),
  theme = tema, fillable = FALSE,
  header = tags$div(class = "container-fluid", style = "max-width:1200px",
    tags$p(aviso, style = "font-size:.82rem;color:#5a5348;border-left:3px solid #8a3b1f;padding:.4rem .8rem;margin:1rem 0 .2rem;background:#ebe5d8")),
  nav_panel("Buscador",
    layout_sidebar(
      sidebar = sidebar(width = 280,
        checkboxGroupInput("liga", "Liga", choices = c("Primera División", "Primera B"), selected = c("Primera División", "Primera B")),
        selectInput("linea", "Línea", choices = c("Todas", "Defensa", "Mediocampo", "Ataque")),
        sliderInput("edad", "Edad", min = min(J$edad), max = max(J$edad), value = c(min(J$edad), max(J$edad)), step = 1),
        sliderInput("minmin", "Minutos mínimos", min = 450, max = max(J$minutos), value = 450, step = 90),
        selectInput("orden", "Ordenar por percentil en", choices = setNames(M$var, M$etiqueta), selected = "key_passes"),
        tags$small("Percentil frente a los jugadores de la misma línea dentro de la muestra.", style = "color:#6b655a")),
      card(card_header("Jugadores"), DTOutput("tabla")),
      card(card_header(textOutput("titulo_perfil", inline = TRUE)), plotOutput("perfil", height = "420px"))
    )),
  nav_panel("Estilo de equipos",
    layout_columns(col_widths = c(3, 9),
      card(selectInput("eq1", "Equipo", choices = sort(unique(E$equipo)), selected = "O'Higgins"),
           selectInput("eq2", "Comparar con (opcional)", choices = c("—", sort(unique(E$equipo)))),
           tags$p("Cada eje se mide frente a los equipos de su propia liga: 50 es la mediana. El estilo explica por qué los números de un jugador son los que son.",
                  style = "font-size:.88rem;color:#5a5348")),
      card(plotOutput("estilo", height = "460px")))),
  nav_panel("Juega parecido",
    layout_columns(col_widths = c(4, 8),
      card(selectizeInput("jp", "Jugador", choices = NULL),
           tags$p("La similitud combina dónde interviene el jugador (30 zonas de la cancha) y qué rol cumple en su equipo. Es un punto de partida para ver vídeo, no una recomendación.",
                  style = "font-size:.88rem;color:#5a5348"),
           DTOutput("similares")),
      card(layout_columns(col_widths = c(6, 6), plotOutput("zonas_a", height = "300px"), plotOutput("zonas_b", height = "300px")),
           tags$small("Pulsa un jugador de la lista para comparar su huella.", style = "color:#6b655a")))),
  nav_spacer(),
  nav_item(tags$a("Pablo Cordone Sánchez", href = "https://github.com/pcord95/portafolio-pablo-cordone", target = "_blank"))
)

# ---------- servidor ----------
server <- function(input, output, session) {
  # ?tab=buscador | estilo | parecido abre directamente esa pestaña (para enlazar cada análisis)
  observe({ q <- parseQueryString(session$clientData$url_search)$tab
    tabs <- c(buscador = "Buscador", estilo = "Estilo de equipos", parecido = "Juega parecido")
    if (!is.null(q) && q %in% names(tabs)) nav_select("nav", tabs[[q]]) })
  etq <- setNames(M$etiqueta, M$var)
  filtrados <- reactive({
    d <- J[J$liga %in% input$liga & J$edad >= input$edad[1] & J$edad <= input$edad[2] & J$minutos >= input$minmin, ]
    if (input$linea != "Todas") d <- d[d$linea == input$linea, ]
    d[order(-d[[input$orden]]), ]
  })
  output$tabla <- renderDT({
    d <- filtrados()
    top2 <- apply(d[, M$var], 1, function(r) { o <- order(-r)[1:2]; paste0(etq[M$var[o]], " p", r[o], collapse = " · ") })
    t <- data.frame(Jugador = d$nombre, Edad = d$edad, Club = d$club, Liga = d$liga, Posición = d$posicion,
                    Minutos = d$minutos, Percentil = d[[input$orden]], `Lo que lo distingue` = top2, check.names = FALSE)
    names(t)[7] <- paste("Percentil ·", etq[[input$orden]])
    datatable(t, rownames = FALSE, selection = list(mode = "single", selected = 1),
              options = list(pageLength = 10, dom = "tip", language = list(info = "_TOTAL_ jugadores", paginate = list(previous = "Anterior", `next` = "Siguiente"))))
  })
  sel <- reactive({ i <- input$tabla_rows_selected; d <- filtrados(); if (!length(i) || i > nrow(d)) d[1, ] else d[i, ] })
  output$titulo_perfil <- renderText({ s <- sel(); if (!nrow(s)) "" else paste0(s$nombre, " · ", s$posicion, " · ", s$club) })
  output$perfil <- renderPlot({ s <- sel(); req(nrow(s)); barras_percentil(M$etiqueta, as.integer(s[1, M$var])) }, bg = PAPEL)

  output$estilo <- renderPlot({
    a <- E[E$equipo == input$eq1, ]; req(nrow(a))
    if (input$eq2 == "—" || input$eq2 == input$eq1) return(barras_percentil(a$eje, a$percentil, paste(input$eq1, "·", a$liga[1])))
    b <- E[E$equipo == input$eq2, ]
    d <- rbind(data.frame(equipo = input$eq1, eje = a$eje, p = a$percentil), data.frame(equipo = input$eq2, eje = b$eje, p = b$percentil))
    d$eje <- factor(d$eje, levels = rev(a$eje)); d$equipo <- factor(d$equipo, levels = c(input$eq1, input$eq2))
    ggplot(d, aes(p, eje, fill = equipo)) + geom_col(position = position_dodge(0.7), width = 0.65) +
      geom_vline(xintercept = 50, linetype = "dashed", colour = "#9b9282") + scale_fill_manual(values = c(ACENTO, GRIS2), name = NULL) +
      scale_x_continuous(limits = c(0, 100)) + labs(x = "Percentil frente a su liga (50 = mediana)", y = NULL) +
      theme_minimal(base_size = 12) + theme(legend.position = "top", panel.grid.minor = element_blank(), panel.grid.major.y = element_blank())
  }, bg = PAPEL)

  con_sim <- J[J$player_id %in% P$player_id, ]
  updateSelectizeInput(session, "jp", choices = setNames(con_sim$player_id, paste0(con_sim$nombre, " · ", con_sim$club)),
                       selected = if ("849177" %in% con_sim$player_id) "849177" else con_sim$player_id[which.max(con_sim$minutos)], server = TRUE)   # Arnaldo Castillo (O'Higgins), el ejemplo de la metodología
  sim <- reactive({ req(input$jp); s <- P[P$player_id == input$jp, ]; s <- merge(s, J, by.x = "similar_id", by.y = "player_id"); s[order(-s$similitud), ] })
  output$similares <- renderDT({
    s <- sim()
    datatable(data.frame(Jugador = s$nombre, Edad = s$edad, Club = s$club, Posición = s$posicion, Similitud = s$similitud),
              rownames = FALSE, selection = list(mode = "single", selected = 1), options = list(dom = "t", pageLength = 10, ordering = FALSE))
  })
  output$zonas_a <- renderPlot({ req(input$jp); cancha_zonas(input$jp, J$nombre[J$player_id == input$jp]) }, bg = PAPEL)
  output$zonas_b <- renderPlot({
    s <- sim(); i <- input$similares_rows_selected; if (!length(i)) i <- 1; req(nrow(s) >= i)
    cancha_zonas(s$similar_id[i], paste0(s$nombre[i], " · similitud ", s$similitud[i]))
  }, bg = PAPEL)
}

shinyApp(ui, server)

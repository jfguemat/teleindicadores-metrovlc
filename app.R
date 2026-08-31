library(shiny)
library(bslib)
library(dplyr)
library(httr2)
library(jsonlite)
library(rvest)
library(stringr)
library(purrr)
library(DT)

# ==============================================================================
# 1. DESCARREGA DINÀMICA DEL CATÀLEG OFICIAL D'ESTACIONS
# ==============================================================================
obtener_catalogo_estaciones <- function() {
  tryCatch({
    url <- "https://www.metrovalencia.es/ca/consulta-estaciones/"
    doc <- read_html(url)
    opciones <- doc %>% html_elements("select option")
    
    df <- tibble(
      id = opciones %>% html_attr("value"),
      nombre = opciones %>% html_text(trim = TRUE)
    ) %>%
      filter(!is.na(id), id != "", id != "0", !str_detect(nombre, "^Selecciona")) %>%
      distinct(id, .keep_all = TRUE) %>%
      arrange(nombre)
    
    return(setNames(df$id, df$nombre))
  }, error = function(e) {
    c("Ayora" = "122", "Jesús" = "23", "Àngel Guimerà" = "25", "Empalme" = "29")
  })
}

LISTA_ESTACIONES <- obtener_catalogo_estaciones()

# ==============================================================================
# 2. CLIENT HTTP I PARSER DEL TELEINDICADOR
# ==============================================================================
fetch_teleindicador_oficial <- function(id_estacion) {
  tryCatch({
    cuerpo <- paste0("action=formularios_ajax&data=action%3Dinfo-estacion%26id%3D", id_estacion)
    
    resp <- request("https://www.metrovalencia.es/wp-admin/admin-ajax.php") %>%
      req_method("POST") %>%
      req_body_raw(cuerpo, type = "application/x-www-form-urlencoded; charset=UTF-8") %>%
      req_headers(
        "User-Agent" = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:154.0) Firefox/154.0",
        "Accept" = "*/*",
        "X-Requested-With" = "XMLHttpRequest",
        "Referer" = "https://www.metrovalencia.es/ca/consulta-estaciones/"
      ) %>%
      req_timeout(5) %>%
      req_perform()
    # --- AQUÍ el diagnóstico ---
message("STATUS TELEINDICADOR: ", resp_status(resp))
message("HEADERS: ", paste(names(resp_headers(resp)), resp_headers(resp), sep="=", collapse=" | "))

raw_text <- resp_body_string(resp)
message("RAW (primeros 200 chars): ", substr(raw_text, 1, 200))
    #-----------------------------
    raw_text <- resp_body_string(resp)
    json_data <- jsonlite::fromJSON(raw_text)
    
    if (is.null(json_data$html) || json_data$html == "") {
      return(tibble(Línia = character(), Destinació = character(), `Minuts rest.` = numeric(), `Hora estimada` = character()))
    }
    
    doc <- read_html(json_data$html)
    items_teleindicador <- doc %>% 
      html_elements("[class*='arribada'], [class*='proxim'], .horarios li, .proximos-trenes-item, .df-sb") %>% 
      html_text2()
    
    items_validos <- items_teleindicador[str_detect(items_teleindicador, "[0-9]+\\s*min")]
    if (length(items_validos) == 0) {
      return(tibble(Línia = character(), Destinació = character(), `Minuts rest.` = numeric(), `Hora estimada` = character()))
    }
    
    map_df(items_validos, function(txt) {
      partes <- unlist(str_split(txt, "\n")) %>% str_trim()
      partes <- partes[partes != ""]
      
      idx_min <- grep("^[0-9]+\\s*min$", partes)
      if (length(idx_min) == 0) return(NULL)
      
      min_val <- as.numeric(str_extract(partes[idx_min[1]], "[0-9]+"))
      destino_candidato <- if (idx_min[1] > 1) partes[idx_min[1] - 1] else partes[1]
      
      if (str_detect(destino_candidato, regex("Temps|arribada|pròxim|próxim|Direcció|Línea|Línia", ignore_case = TRUE))) {
        return(NULL)
      }
      
      linea_num <- case_when(
        str_detect(destino_candidato, "Bétera|Seminari|Picassent|Villanueva|Castelló|L'Alcúdia|València Sud") ~ "L1",
        str_detect(destino_candidato, "Llíria|Paterna") ~ "L2",
        str_detect(destino_candidato, "Rafelbunyol|Alboraia") ~ "L3",
        str_detect(destino_candidato, "Mas del Rosari|Estellés|Lloma|Parc|Fira|Ll. Llarga|Dr. Lluch") ~ "L4",
        str_detect(destino_candidato, "Aeroport|Riba-roja|Av. del Cid") ~ "L5",
        str_detect(destino_candidato, "Tossal del Rei") ~ "L6",
        str_detect(destino_candidato, "Torrent|Marítim") ~ "L7",
        str_detect(destino_candidato, "Neptú") ~ "L8",
        str_detect(destino_candidato, "Riba-roja de Túria") ~ "L9",
        str_detect(destino_candidato, "Alacant|Natzaret") ~ "L10",
        TRUE ~ "Metro"
      )
      
      tibble(
        Línia = linea_num,
        Destinació = destino_candidato,
        `Minuts rest.` = min_val,
        `Hora estimada` = format(Sys.time() + min_val * 60, "%H:%M")
      )
    }) %>%
      distinct(Destinació, `Minuts rest.`, .keep_all = TRUE) %>%
      arrange(`Minuts rest.`)
    
  }, error = function(e) {
    tibble(Línia = character(), Destinació = character(), `Minuts rest.` = numeric(), `Hora estimada` = character())
  })
}

# ==============================================================================
# 3. INTERFÍCIE D'USUARI ADAPTABLE (UI)
# ==============================================================================
ui <- page_fluid(
  theme = bs_theme(bootswatch = "zephyr", primary = "#d9230f"),
  title = "Teleindicadors Metrovalencia",
  
  # Contenidor fluid amb amplada adaptable (fins al 95% de la pantalla)
  div(class = "container-fluid py-3 px-md-4", style = "max-width: 1200px;",
      card(
        full_screen = TRUE, # Permet botó de pantalla completa natiu
        card_header(
          div(class = "d-flex justify-content-between align-items-center",
              span(icon("train"), " Teleindicador Oficial en Directe"),
              span(class = "badge bg-danger", "En Directe")
          )
        ),
        card_body(
          div(class = "row g-2 align-items-end mb-3",
              div(class = "col-12 col-md-8",
                  selectInput(
                    "estacion_sel", 
                    "Selecciona una estació:", 
                    choices = LISTA_ESTACIONES, 
                    selected = if ("122" %in% LISTA_ESTACIONES) "122" else LISTA_ESTACIONES[1],
                    selectize = TRUE,
                    width = "100%"
                  )
              ),
              div(class = "col-12 col-md-4 d-flex justify-content-between justify-content-md-end align-items-center gap-2",
                  actionButton("btn_refresh", "Actualitza", icon = icon("rotate"), class = "btn-outline-danger btn-sm"),
                  span(class = "text-muted", style = "font-size: 0.85rem;", textOutput("lbl_sync", inline = TRUE))
              )
          ),
          # Taula amb amplada del 100%
          div(style = "width: 100%;",
              DTOutput("tabla_trenes", width = "100%")
          )
        )
      )
  )
)

# ==============================================================================
# 4. SERVIDOR (SERVER)
# ==============================================================================
server <- function(input, output, session) {
  
  auto_poll <- reactiveTimer(20000)
  
  trenes_data <- reactive({
    auto_poll()
    input$btn_refresh
    req(input$estacion_sel)
    fetch_teleindicador_oficial(input$estacion_sel)
  })
  
  output$lbl_sync <- renderText({
    trenes_data()
    paste("Sincronitzat:", format(Sys.time(), "%H:%M:%S"))
  })
  
  output$tabla_trenes <- renderDT({
    df <- trenes_data()
    
    if (nrow(df) == 0) {
      return(datatable(
        tibble(Estat = "No hi ha trens programats al teleindicador en aquest moment."),
        options = list(dom = 't'), 
        rownames = FALSE
      ))
    }
    
    datatable(
      df,
      fillContainer = FALSE,
      options = list(
        dom = 't',
        paging = FALSE,              # Mostra tots els trens sense tallar-los
        scrollY = "calc(55vh)",       # Alçada dinàmica: ocupa el 55% de la teua finestra
        scrollCollapse = TRUE,
        autoWidth = TRUE,             # Ajusta les columnes a l'amplada de pantalla
        columnDefs = list(
          list(className = 'dt-center', targets = c(0, 2, 3)), # Centra línia, minuts i hora
          list(width = '15%', targets = 0),
          list(width = '45%', targets = 1),
          list(width = '20%', targets = 2),
          list(width = '20%', targets = 3)
        )
      ),
      rownames = FALSE
    )
  })
}

shinyApp(ui, server)

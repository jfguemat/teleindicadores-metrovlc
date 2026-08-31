FROM rocker/shiny:latest

RUN apt-get update && apt-get install -y \
    libxml2-dev \
    libcurl4-openssl-dev \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

RUN install2.r --error \
    shiny \
    bslib \
    dplyr \
    httr2 \
    jsonlite \
    rvest \
    stringr \
    purrr \
    DT

# Esborrem els fitxers de mostra de Shiny Server
RUN rm -rf /srv/shiny-server/*

# Copiem la teua app com a aplicació principal
COPY teleinc_metroVLC.R /srv/shiny-server/

EXPOSE 3838

CMD ["/usr/bin/shiny-server"]

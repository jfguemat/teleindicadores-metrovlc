FROM rocker/shiny:latest

RUN apt-get update && apt-get install -y \
    libxml2-dev \
    libcurl4-openssl-dev \
    libssl-dev \
    libuv1-dev \
    libpng-dev \
    zlib1g-dev \
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

RUN rm -rf /srv/shiny-server/*
COPY app.R /srv/shiny-server/
RUN chown -R shiny:shiny /srv/shiny-server

EXPOSE 3838

# Lanza la app directamente con R, sin shiny-server,
# para que message()/print() salgan por stdout y Render los capture
CMD ["R", "-e", "shiny::runApp('/srv/shiny-server', host='0.0.0.0', port=3838)"]

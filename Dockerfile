FROM rocker/shiny:latest

# 1. Dependències del sistema necessàries per a fs, sass, bslib i httr2
RUN apt-get update && apt-get install -y \
    libxml2-dev \
    libcurl4-openssl-dev \
    libssl-dev \
    libuv1-dev \
    libpng-dev \
    zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

# 2. Instal·lació de llibreries de R
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

# 3. Neteja de la carpeta per defecte i còpia de la teua app
RUN rm -rf /srv/shiny-server/*
COPY app.R /srv/shiny-server/

# 4. Permisos per a l'usuari shiny
RUN chown -R shiny:shiny /srv/shiny-server

EXPOSE 3838

CMD ["/usr/bin/shiny-server"]

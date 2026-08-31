FROM rocker/shiny:latest

# 1. Dependències del sistema per als paquets de R
RUN apt-get update && apt-get install -y \
    libxml2-dev \
    libcurl4-openssl-dev \
    libssl-dev \
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

# 3. Neteja de carpetes i còpia de l'aplicació
RUN rm -rf /srv/shiny-server/*
COPY app.R /srv/shiny-server/

# 4. Ajust de permisos per a l'usuari shiny
RUN chown -R shiny:shiny /srv/shiny-server

# 5. Activar logs detallats a la consola (Render)
ENV SHINY_LOG_STDERR=1
ENV SHINY_GA_ID=""

EXPOSE 3838

CMD ["/usr/bin/shiny-server"]

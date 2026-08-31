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
COPY shiny-server.conf /etc/shiny-server/shiny-server.conf

RUN chown -R shiny:shiny /srv/shiny-server

EXPOSE 3838
CMD ["/usr/bin/shiny-server"]

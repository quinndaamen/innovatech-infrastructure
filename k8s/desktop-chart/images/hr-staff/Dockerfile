FROM lscr.io/linuxserver/webtop:ubuntu-xfce

ARG DEBIAN_FRONTEND=noninteractive

LABEL org.opencontainers.image.title="innovatech-hr-staff" \
      innovatech.role="hr-staff"

RUN rm -f /etc/apt/sources.list.d/*xtradeb*

# HR applications
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        libreoffice \
        libreoffice-writer \
        libreoffice-calc \
        libreoffice-impress \
        thunderbird \
        keepassxc \
        pdfarranger \
        evince \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

ENV DISABLE_SUDO=true
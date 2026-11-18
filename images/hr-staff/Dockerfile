# Pin by digest from: docker inspect --format='{{index .RepoDigests 0}}' lscr.io/linuxserver/webtop:ubuntu-xfce
FROM lscr.io/linuxserver/webtop:ubuntu-xfce

ARG DEBIAN_FRONTEND=noninteractive

LABEL org.opencontainers.image.title="innovatech-hr-staff" \
      innovatech.role="hr-staff"

# The base image ships a third-party repository that breaks apt-get update
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

# Role policy: users cannot use sudo, so they cannot install other applications
ENV DISABLE_SUDO=true
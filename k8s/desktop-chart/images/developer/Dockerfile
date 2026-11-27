FROM lscr.io/linuxserver/webtop:ubuntu-xfce

ARG DEBIAN_FRONTEND=noninteractive

LABEL org.opencontainers.image.title="innovatech-developer" \
      innovatech.role="developer"

RUN rm -f /etc/apt/sources.list.d/*xtradeb*

# Development tools
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        git \
        git-lfs \
        python3 \
        python3-pip \
        python3-venv \
        python3-dev \
        nodejs \
        build-essential \
        make \
        cmake \
        curl \
        wget \
        jq \
        unzip \
        zip \
        openssh-client \
        sqlite3 \
        net-tools \
        iputils-ping \
        dnsutils \
        traceroute \
        nano \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

ENV DISABLE_SUDO=true
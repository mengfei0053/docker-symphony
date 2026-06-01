# syntax=docker/dockerfile:1

FROM docker.1ms.run/ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive
ARG SYMPHONY_REPO=https://github.com/openai/symphony.git
ARG SYMPHONY_REF=main
ARG CODEX_PACKAGE=@openai/codex
ARG FIGMA_MCP_PACKAGE=figma-developer-mcp

ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    MIX_ENV=prod \
    MISE_YES=1 \
    MISE_DATA_DIR=/opt/mise \
    MISE_CONFIG_DIR=/opt/mise \
    MISE_CACHE_DIR=/opt/mise/cache \
    PATH=/opt/mise/shims:/usr/local/bin:/usr/local/sbin:/usr/sbin:/usr/bin:/sbin:/bin \
    SYMPHONY_HOME=/opt/symphony/elixir \
    SYMPHONY_WORKFLOW=/config/WORKFLOW.md \
    SYMPHONY_LOGS_ROOT=/data/logs \
    SYMPHONY_PORT=4000 \
    SYMPHONY_WORKSPACE_ROOT=/data/workspaces

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bash \
        build-essential \
        ca-certificates \
        curl \
        git \
        gnupg \
        libncurses5-dev \
        libncursesw5-dev \
        libssl-dev \
        locales \
        openssh-client \
        pkg-config \
        unzip \
        xz-utils \
        zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js for the Codex CLI used by Symphony's default `codex app-server` command.
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get update \
    && apt-get install -y --no-install-recommends nodejs \
    && npm install -g "${CODEX_PACKAGE}" "${FIGMA_MCP_PACKAGE}" \
    && npm cache clean --force \
    && rm -rf /var/lib/apt/lists/*

# Install mise, then use Symphony's checked-in mise.toml for Erlang/Elixir versions.
RUN curl -fsSL https://mise.run | sh \
    && install -m 0755 /root/.local/bin/mise /usr/local/bin/mise \
    && mkdir -p /opt/mise /opt/symphony /data/logs /data/workspaces /config /usr/local/share/symphony /root/.codex

RUN git clone --depth 1 --branch "${SYMPHONY_REF}" "${SYMPHONY_REPO}" /opt/symphony \
    && cd /opt/symphony/elixir \
    && mise trust \
    && mise install \
    && mise exec -- mix local.hex --force \
    && mise exec -- mix local.rebar --force \
    && mise exec -- mix setup \
    && mise exec -- mix build

COPY docker/entrypoint.sh /usr/local/bin/symphony-entrypoint
COPY docker/codex-config.toml /root/.codex/config.toml
COPY WORKFLOW.example.md /usr/local/share/symphony/WORKFLOW.example.md

RUN chmod +x /usr/local/bin/symphony-entrypoint \
    && cp /usr/local/share/symphony/WORKFLOW.example.md /config/WORKFLOW.md

WORKDIR /opt/symphony/elixir

EXPOSE 4000

ENTRYPOINT ["/usr/local/bin/symphony-entrypoint"]
CMD []

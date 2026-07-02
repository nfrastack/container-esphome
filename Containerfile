# SPDX-FileCopyrightText: © 2026 Nfrastack <code@nfrastack.com>
#
# SPDX-License-Identifier: MIT

ARG \
    BASE_IMAGE

FROM ${BASE_IMAGE}

LABEL \
        org.opencontainers.image.title="ESPHome" \
        org.opencontainers.image.description="ESPHome Dashboard" \
        org.opencontainers.image.url="https://hub.docker.com/r/nfrastack/esphome" \
        org.opencontainers.image.documentation="https://github.com/nfrastack/container-esphome/blob/main/README.md" \
        org.opencontainers.image.source="https://github.com/nfrastack/container-esphome.git" \
        org.opencontainers.image.authors="Nfrastack <code@nfrastack.com>" \
        org.opencontainers.image.vendor="Nfrastack <https://www.nfrastack.com>" \
        org.opencontainers.image.licenses="MIT"

ARG \
    ESPHOME_VERSION="2026.6.4" \
    ESPHOME_REPO_URL="https://github.com/esphome/esphome" \
    PYTHON_VERSION="3.14"

COPY CHANGELOG.md /usr/src/container/CHANGELOG.md
COPY LICENSE /usr/src/container/LICENSE
COPY README.md /usr/src/container/README.md

ENV \
    CONTAINER_ENABLE_MESSAGING=FALSE \
    CONTAINER_ENABLE_SCHEDULING=FALSE \
    ESPHOME_USER=esphome \
    ESPHOME_GROUP=esphome \
    PATH="/opt/esphome/bin:$PATH" \
    IMAGE_NAME="nfrastack/esphome" \
    IMAGE_REPO_URL="https://github.com/nfrastack/container-esphome/"
    #NGINX_ENABLE_CREATE_SAMPLE_HTML=FALSE \
    #NGINX_LOG_ACCESS_LOCATION=/logs/nginx \
    #NGINX_LOG_ERROR_LOCATION=/logs/nginx \
    #NGINX_PROXY_BUFFERS="12 256k" \
    #NGINX_WEBROOT=/var/lib/nginx/wwwroot \
    #NGINX_WORKER_PROCESSES=1 \

EXPOSE 6052

RUN echo "" && \
    BUILD_ENV=" \
                10-nginx/ENABLE_NGINX=TRUE \
                10-nginx/NGINX_PROXY_URL='http://localhost:[env:LISTEN_PORT]' \
                10-nginx/NGINX_SITE_ENABLED=esphome \
                10-nginx/NGINX_SITE_ESPHOME_MODE=proxy \
              " \
              && \
    ESPHOME_BUILD_DEPS_ALPINE=" \
                                jpeg-dev \
                                freetype-dev \
                                rust \
                                cargo \
                            " \
                        && \
    ESPHOME_RUN_DEPS_ALPINE=" \
                                clang-extra-tools \
                                git \
                                libjpeg \
                                patch \
                            " \
                        && \
    ESPHOME_BUILD_DEPS_DEBIAN=" \
                                libjpeg-dev \
                                libfreetype-dev \
                                rustc \
                                cargo \
                            " \
                        && \
    ESPHOME_RUN_DEPS_DEBIAN=" \
                                clang-format \
                                clang-tidy \
                                git \
                                libjpeg62-turbo \
                                patch \
                            " \
                        && \
    source /container/base/functions/container/build && \
    container_build_log image && \
    create_user "${ESPHOME_USER}" 6052 "${ESPHOME_GROUP}" 6052 /var/lib/esphome && \
    package update && \
    package upgrade && \
    package install \
                    ESPHOME_BUILD_DEPS \
                    ESPHOME_RUN_DEPS \
                    && \
    \
    package build python "${PYTHON_VERSION}" && \
    pip install --break-system-packages uv && \
    UV_PYTHON_DOWNLOADS=never uv venv /opt/esphome --python /usr/local/bin/python$(echo ${PYTHON_VERSION} | cut -d. -f1-2) && \
    chown -R "${ESPHOME_USER}":"${ESPHOME_GROUP}" /opt/esphome && \
    source /opt/esphome/bin/activate && \
    \
    clone_git_repo "${ESPHOME_REPO_URL}" "${ESPHOME_VERSION}" /opt/esphome/app && \
    chown -R "${ESPHOME_USER}":"${ESPHOME_GROUP}" /opt/esphome/app && \
    cd /opt/esphome/app && \
    uv pip install --no-cache-dir \
                -r requirements.txt \
                -e /opt/esphome/app \
                && \
    uv pip install --no-cache-dir esphome-device-builder && \
    \
    platformio settings set enable_telemetry No && \
    platformio settings set check_platformio_interval 1000000 && \
    mkdir -p /piolibs && \
    /opt/esphome/bin/python3 script/platformio_install_deps.py platformio.ini --libraries && \
    \
    container_build_log add "ESPHome" "${ESPHOME_VERSION}" "${ESPHOME_REPO_URL}" && \
    \
    package remove \
                    ESPHOME_BUILD_DEPS \
                    && \
    package cleanup && \
    rm -rf \
            /root/.cache \
            /usr/src/* \
            /var/lib/esphome

COPY rootfs /

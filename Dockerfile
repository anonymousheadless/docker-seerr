# syntax=docker/dockerfile:1

FROM ghcr.io/linuxserver/baseimage-alpine:3.22

# set version label
ARG BUILD_DATE
ARG VERSION
ARG SEERR_VERSION
LABEL build_version="Linuxserver.io version:- ${VERSION} Build-date:- ${BUILD_DATE}"
LABEL maintainer="nemchik"

# set environment variables
ENV HOME="/config" \
  TMPDIR=/run/seerr-temp

RUN \
  echo "**** install build packages ****" && \
  apk add --no-cache --virtual=build-dependencies \
    build-base \
    python3 && \
  echo "**** install runtime packages ****" && \
  apk add --no-cache \
    nodejs \
    npm && \
  npm install -g pnpm@10.24.0 && \
  if [ -z ${SEERR_VERSION+x} ]; then \
    SEERR_VERSION=$(curl -sX GET "https://api.github.com/repos/seerr-team/seerr/releases/latest" \
    | awk '/tag_name/{print $4;exit}' FS='[""]'); \
  fi && \
  export COMMIT_TAG="${SEERR_VERSION}" && \
  curl -o \
    /tmp/seerr.tar.gz -L \
    "https://github.com/seerr-team/seerr/archive/${SEERR_VERSION}.tar.gz" && \
  mkdir -p /app/seerr && \
  tar xzf \
    /tmp/seerr.tar.gz -C \
    /app/seerr/ --strip-components=1 && \
  cd /app/seerr && \
  export NODE_OPTIONS=--max_old_space_size=2048 && \
  CYPRESS_INSTALL_BINARY=0 pnpm install --frozen-lockfile && \
  pnpm build && \
  pnpm install --production --ignore-scripts && \
  pnpm store prune && \
  rm -rf \
    /app/seerr/src \
    /app/seerr/server && \
  echo "{\"commitTag\": \"${COMMIT_TAG}\"}" > committag.json && \
  rm -rf /app/seerr/config && \
  ln -s /config /app/seerr/config && \
  touch /config/DOCKER && \
  printf "Linuxserver.io version: ${VERSION}\nBuild-date: ${BUILD_DATE}" > /build_version && \
  echo "**** cleanup ****" && \
  apk del --purge \
    build-dependencies && \
  rm -rf \
    /tmp/* \
    $HOME/.cache \
    /app/seerr/.next/cache/* \
    /run/seerr-temp

# copy local files
COPY root/ /

# ports and volumes
EXPOSE 5055

VOLUME /config

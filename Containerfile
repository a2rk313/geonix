ARG BASE_IMAGE=ghcr.io/ublue-os/bluefin:latest
ARG BASE_VARIANT=bluefin
ARG IMAGE_NAME=geonix-gnome
ARG IMAGE_REGISTRY=ghcr.io/a2rk313
ARG DEFAULT_TAG=latest

FROM scratch AS ctx
COPY build_files /

FROM ${BASE_IMAGE}

LABEL org.opencontainers.image.title="Geonix"
LABEL org.opencontainers.image.description="A Universal Blue based distro made for the cool folks that use GIS and Remote Sensing knowledge to make the world a better place."
LABEL org.opencontainers.image.source="https://github.com/a2rk313/geonix"

ENV BASE_VARIANT=${BASE_VARIANT}
ENV IMAGE_NAME=${IMAGE_NAME}
ENV IMAGE_REGISTRY=${IMAGE_REGISTRY}
ENV DEFAULT_TAG=${DEFAULT_TAG}

RUN rm /opt && mkdir /opt

# GIS stack + kernel optimizations + just recipes
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build.sh

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    /ctx/set-components.sh

# Strip redundant packages from base image
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    /ctx/remove-packages.sh

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=bind,source=logo,target=/ctx/logo \
    /ctx/image-info.sh && \
    /ctx/branding.sh
    KERNEL_VERSION=$(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n' kernel-core) && \
    DRACUT_NO_XATTR=1 dracut \
      --no-hostonly \
      --reproducible \
      --zstd \
      -f "/usr/lib/modules/${KERNEL_VERSION}/initramfs.img" \
      "${KERNEL_VERSION}"

RUN bootc container lint

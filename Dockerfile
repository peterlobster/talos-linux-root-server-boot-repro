FROM alpine:3.20

# Versions can be overridden at build time:
#   docker build --build-arg TALOSCTL_VERSION=v1.12.0 --build-arg HELM_VERSION=v4.0.0 --build-arg KUBECTL_VERSION=v1.35.0 ...
ARG TALOSCTL_VERSION=v1.12.0
ARG HELM_VERSION=v4.0.0
ARG KUBECTL_VERSION=v1.35.0
ARG TARGETARCH

RUN apk add --no-cache \
    bash \
    ca-certificates \
    curl \
    jq \
    openssh-client \
    docker-cli \
    tar \
    gzip \
    && update-ca-certificates

# Install kubectl (official upstream binary)
RUN set -eux; \
    arch="${TARGETARCH:-$(apk --print-arch)}"; \
    case "$arch" in \
    x86_64|amd64) arch="amd64" ;; \
    aarch64|arm64) arch="arm64" ;; \
    armv7|armhf) arch="arm" ;; \
    *) echo "Unsupported arch: $arch"; exit 1 ;; \
    esac; \
    curl -fsSL -o /usr/local/bin/kubectl \
    "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${arch}/kubectl"; \
    chmod +x /usr/local/bin/kubectl; \
    kubectl version --client

# Install talosctl (downloads the official release binary)
RUN set -eux; \
    arch="${TARGETARCH:-$(apk --print-arch)}"; \
    case "$arch" in \
    x86_64|amd64) arch="amd64" ;; \
    aarch64|arm64) arch="arm64" ;; \
    armv7|armhf) arch="armv7" ;; \
    *) echo "Unsupported arch: $arch"; exit 1 ;; \
    esac; \
    curl -fsSL -o /usr/local/bin/talosctl \
    "https://github.com/siderolabs/talos/releases/download/${TALOSCTL_VERSION}/talosctl-linux-${arch}"; \
    chmod +x /usr/local/bin/talosctl; \
    talosctl version --client

# Install Helm (official tarball)
RUN set -eux; \
    arch="${TARGETARCH:-$(apk --print-arch)}"; \
    case "$arch" in \
    x86_64|amd64) arch="amd64" ;; \
    aarch64|arm64) arch="arm64" ;; \
    *) echo "Unsupported arch: $arch"; exit 1 ;; \
    esac; \
    tmpdir="$(mktemp -d)"; \
    curl -fsSL -o "$tmpdir/helm.tgz" \
    "https://get.helm.sh/helm-${HELM_VERSION}-linux-${arch}.tar.gz"; \
    tar -xzf "$tmpdir/helm.tgz" -C "$tmpdir"; \
    mv "$tmpdir/linux-${arch}/helm" /usr/local/bin/helm; \
    chmod +x /usr/local/bin/helm; \
    rm -rf "$tmpdir"; \
    helm version

WORKDIR /workdir

ENTRYPOINT ["/bin/bash"]

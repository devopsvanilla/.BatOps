# syntax=docker/dockerfile:1.6
FROM sqlpad/sqlpad:latest

ARG APT_NAMESERVERS="8.8.8.8,8.8.4.4"

USER root
RUN set -eux; \
    if [ -n "$APT_NAMESERVERS" ]; then \
        if [ -w /etc/resolv.conf ]; then \
            : > /etc/resolv.conf; \
            for ns in $(echo "$APT_NAMESERVERS" | tr ',' ' '); do \
                ns=$(echo "$ns" | xargs); \
                if [ -n "$ns" ]; then \
                    echo "nameserver $ns" >> /etc/resolv.conf; \
                fi; \
            done; \
        else \
            echo "[sqlpad build] /etc/resolv.conf é somente leitura; ignorando override de DNS" >&2; \
        fi; \
    fi; \
    install_optional=true; \
    if ! apt-get update; then \
        install_optional=false; \
        echo "[sqlpad build] aviso: 'apt-get update' falhou (provavelmente DNS). Pacotes opcionais serão ignorados." >&2; \
    fi; \
    if [ "$install_optional" = true ]; then \
        if ! apt-get install -y --no-install-recommends xsel; then \
            install_optional=false; \
            echo "[sqlpad build] aviso: falha ao instalar 'xsel'. Prosseguindo sem o pacote opcional." >&2; \
        fi; \
    fi; \
    rm -rf /var/lib/apt/lists/* || true

RUN set -eux; \
    if ! id -u sqlpad >/dev/null 2>&1; then \
        useradd --create-home --shell /bin/bash sqlpad; \
    fi; \
    mkdir -p /var/lib/sqlpad /etc/sqlpad; \
    chown -R sqlpad:sqlpad /var/lib/sqlpad /etc/sqlpad || true; \
    chown -R sqlpad:sqlpad /usr/app/public || true

USER sqlpad

#!/bin/sh
set -eu

SSL_DIR=/etc/nginx/ssl
CERT_PATH="$SSL_DIR/docutranslate.crt"
KEY_PATH="$SSL_DIR/docutranslate.key"
CONF_PATH=/etc/nginx/conf.d/docutranslate.conf
HTTPS_PORT="${DOCUTRANSLATE_HTTPS_PORT:-443}"

mkdir -p "$SSL_DIR" /var/www/certbot

if [ ! -s "$CERT_PATH" ] || [ ! -s "$KEY_PATH" ]; then
    openssl req -x509 -nodes -newkey rsa:2048 -days 365 \
        -keyout "$KEY_PATH" \
        -out "$CERT_PATH" \
        -subj "/CN=${DOCUTRANSLATE_SSL_CN:-localhost}" \
        >/dev/null 2>&1
fi

chmod 644 "$CERT_PATH"
chmod 600 "$KEY_PATH"

if [ "$HTTPS_PORT" = "443" ] || [ -z "$HTTPS_PORT" ]; then
    HTTPS_PORT_SUFFIX=""
else
    HTTPS_PORT_SUFFIX=":$HTTPS_PORT"
fi

if [ -f "$CONF_PATH" ]; then
    sed -i "s|__DOCUTRANSLATE_HTTPS_PORT_SUFFIX__|$HTTPS_PORT_SUFFIX|g" "$CONF_PATH"
fi

exec "$@"

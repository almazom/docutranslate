#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SSL_DIR="$ROOT_DIR/nginx/ssl"
LETSENCRYPT_DIR="$ROOT_DIR/nginx/letsencrypt"
WEBROOT_DIR="$ROOT_DIR/nginx/www/certbot"

DOMAIN=""
EMAIL=""
SELF_SIGNED=false
NO_RELOAD=false

usage() {
    cat <<'EOF'
Usage:
  scripts/setup_ssl.sh --self-signed [--domain localhost]
  scripts/setup_ssl.sh --domain example.com --email admin@example.com

Options:
  --domain <domain>     Public domain for Let's Encrypt or the CN for a self-signed cert
  --email <email>       Email required for Let's Encrypt issuance
  --self-signed         Generate a local self-signed certificate instead of using Let's Encrypt
  --no-reload           Do not reload the running nginx container after writing certs
EOF
}

reload_nginx() {
    if [[ "$NO_RELOAD" == true ]]; then
        return
    fi
    if docker compose ps --status running --services nginx 2>/dev/null | grep -qx "nginx"; then
        docker compose exec nginx nginx -s reload >/dev/null 2>&1 || true
    fi
}

run_nginx_tool() {
    docker compose run --rm --no-deps "$@"
}

copy_letsencrypt_cert() {
    run_nginx_tool \
        -e DOCUTRANSLATE_CERT_DOMAIN="$DOMAIN" \
        --entrypoint sh \
        nginx \
        -lc '
            live_dir="/etc/letsencrypt/live/$DOCUTRANSLATE_CERT_DOMAIN"
            if [ ! -f "$live_dir/fullchain.pem" ] || [ ! -f "$live_dir/privkey.pem" ]; then
                echo "Let'\''s Encrypt files not found in $live_dir" >&2
                exit 1
            fi

            cp "$live_dir/fullchain.pem" /etc/nginx/ssl/docutranslate.crt
            cp "$live_dir/privkey.pem" /etc/nginx/ssl/docutranslate.key
            chmod 644 /etc/nginx/ssl/docutranslate.crt
            chmod 600 /etc/nginx/ssl/docutranslate.key
        '
}

mkdir -p "$SSL_DIR" "$LETSENCRYPT_DIR" "$WEBROOT_DIR"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --domain)
            DOMAIN="${2:-}"
            shift 2
            ;;
        --email)
            EMAIL="${2:-}"
            shift 2
            ;;
        --self-signed)
            SELF_SIGNED=true
            shift
            ;;
        --no-reload)
            NO_RELOAD=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage
            exit 1
            ;;
    esac
done

if [[ "$SELF_SIGNED" == true || -z "$DOMAIN" ]]; then
    DOMAIN="${DOMAIN:-localhost}"
    run_nginx_tool \
        -e DOCUTRANSLATE_SSL_CN="$DOMAIN" \
        --entrypoint sh \
        nginx \
        -lc '
            openssl req -x509 -nodes -newkey rsa:2048 -days 365 \
                -keyout /etc/nginx/ssl/docutranslate.key \
                -out /etc/nginx/ssl/docutranslate.crt \
                -subj "/CN=${DOCUTRANSLATE_SSL_CN:-localhost}"
            chmod 644 /etc/nginx/ssl/docutranslate.crt
            chmod 600 /etc/nginx/ssl/docutranslate.key
        '
    reload_nginx
    echo "Self-signed certificate created for $DOMAIN"
    exit 0
fi

if [[ -z "$EMAIL" ]]; then
    echo "--email is required when requesting a Let's Encrypt certificate." >&2
    usage
    exit 1
fi

docker compose --profile tools run --rm certbot certonly \
    --webroot \
    --webroot-path /var/www/certbot \
    --non-interactive \
    --agree-tos \
    --email "$EMAIL" \
    -d "$DOMAIN"

copy_letsencrypt_cert
reload_nginx
echo "Let's Encrypt certificate installed for $DOMAIN"

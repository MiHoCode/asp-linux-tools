
#!/bin/sh
set -eu

# Usage:
# sudo ./asp_create_lan_webserver.sh \
#   <apache2|nginx> <server-ip> [app-port] [lan-subnet]
#
# Example:
# sudo ./asp_create_lan_webserver.sh \
#   nginx 192.168.1.100 5000 192.168.1.0/24

if [ "$(id -u)" -ne 0 ]; then
  echo "please execute as root (sudo)."
  exit 1
fi

WEBSERVER="${1:-}"
SERVER_IP="${2:-}"
PORT="${3:-5000}"
LAN_SUBNET="${4:-}"

usage() {
  echo "usage: $0 <apache2|nginx> <server-ip> [app-port] [lan-subnet]"
  exit 1
}

[ -n "$WEBSERVER" ] || usage
[ -n "$SERVER_IP" ] || usage

case "$WEBSERVER" in
  apache2|nginx) ;;
  *) echo "error: invalid web server"; usage ;;
esac

# IPv4-Adresse prüfen
if ! printf '%s\n' "$SERVER_IP" | awk -F. '
  NF != 4 { exit 1 }
  {
    for (i = 1; i <= 4; i++) {
      if ($i !~ /^[0-9]+$/ || length($i) > 3 ||
          $i + 0 > 255) exit 1
    }
  }
'; then
  echo "error: invalid IPv4 address"
  exit 1
fi

case "$PORT" in
  *[!0-9]*|'')
    echo "error: invalid port"; exit 1 ;;
esac

if [ "$PORT" -lt 1 ] || [ "$PORT" -gt 65535 ]; then
  echo "error: port must be between 1 and 65535"
  exit 1
fi

# CIDR-Subnetz prüfen, falls angegeben
if [ -n "$LAN_SUBNET" ]; then
  if ! printf '%s\n' "$LAN_SUBNET" | awk -F/ '
    NF != 2 { exit 1 }
    $2 !~ /^[0-9]+$/ { exit 1 }
    $2 < 0 || $2 > 32 { exit 1 }
    {
      n = split($1, a, ".")
      if (n != 4) exit 1
      for (i = 1; i <= 4; i++) {
        if (a[i] !~ /^[0-9]+$/ ||
            length(a[i]) > 3 ||
            a[i] + 0 > 255) exit 1
      }
    }
  '; then
    echo "error: invalid LAN subnet"
    exit 1
  fi
fi

backup_if_exists() {
  if [ -f "$1" ]; then
    cp -a "$1" "$1.bak.$(date +%s)"
  fi
}

echo "Webserver: $WEBSERVER"
echo "Server IP: $SERVER_IP"
echo "Kestrel port: $PORT"
echo "LAN subnet: ${LAN_SUBNET:-not restricted by UFW}"

if [ "$WEBSERVER" = "apache2" ]; then

  echo "checking/installing apache2..."
  apt-get update
  DEBIAN_FRONTEND=noninteractive \
    apt-get install -y apache2

  a2enmod proxy proxy_http headers rewrite \
           reqtimeout

  SITE_CONF="/etc/apache2/sites-available/asp-lan.conf"
  backup_if_exists "$SITE_CONF"

  cat > "$SITE_CONF" <<EOF
# ASP.NET Core LAN Reverse Proxy
# Server: ${SERVER_IP}
# Backend: 127.0.0.1:${PORT}

<VirtualHost *:80>
    ServerName ${SERVER_IP}

    ProxyPreserveHost On
    ProxyRequests Off

    LimitRequestBody 0
    ProxyTimeout 3600
    Timeout 3600

    RequestReadTimeout header=3600,MinRate=1 body=3600,MinRate=1

    ProxyPass / http://127.0.0.1:${PORT}/ retry=0 timeout=3600 connectiontimeout=3600 upgrade=websocket
    ProxyPassReverse / http://127.0.0.1:${PORT}/

    RequestHeader set X-Forwarded-Proto "http"
    RequestHeader set X-Forwarded-Host "%{Host}i"

    Header always set X-Content-Type-Options "nosniff"
    Header always set X-Frame-Options "SAMEORIGIN"

    ErrorLog \${APACHE_LOG_DIR}/asp-lan_error.log
    CustomLog \${APACHE_LOG_DIR}/asp-lan_access.log combined
</VirtualHost>
EOF

  a2ensite asp-lan.conf
  a2dissite 000-default.conf || true

  apache2ctl configtest
  systemctl enable --now apache2
  systemctl reload apache2

elif [ "$WEBSERVER" = "nginx" ]; then

  echo "checking/installing nginx..."
  apt-get update
  DEBIAN_FRONTEND=noninteractive \
    apt-get install -y nginx

  SITE_AVAIL="/etc/nginx/sites-available/asp-lan"
  SITE_ENABLED="/etc/nginx/sites-enabled/asp-lan"

  backup_if_exists "$SITE_AVAIL"

  cat > "$SITE_AVAIL" <<EOF
# ASP.NET Core LAN Reverse Proxy
# Server: ${SERVER_IP}
# Backend: 127.0.0.1:${PORT}

server {
    listen 80 default_server;
    listen [::]:80 default_server;

    server_name ${SERVER_IP} _;

    client_max_body_size 2g;

    location / {
        proxy_pass http://127.0.0.1:${PORT};

        proxy_http_version 1.1;

        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";

        proxy_request_buffering off;
        proxy_buffering off;

        proxy_connect_timeout 3600s;
        proxy_send_timeout 3600s;
        proxy_read_timeout 3600s;
        send_timeout 3600s;
    }

    access_log /var/log/nginx/asp-lan_access.log;
    error_log /var/log/nginx/asp-lan_error.log;
}
EOF

  ln -sf "$SITE_AVAIL" "$SITE_ENABLED"

  if [ -e /etc/nginx/sites-enabled/default ]; then
    rm -f /etc/nginx/sites-enabled/default
  fi

  nginx -t
  systemctl enable --now nginx
  systemctl reload nginx
fi

# UFW: Optional nur LAN-Subnetz freigeben
if command -v ufw >/dev/null 2>&1 &&
   ufw status | grep -q "Status: active"; then

  if [ -n "$LAN_SUBNET" ]; then
    echo "allowing HTTP from $LAN_SUBNET..."
    ufw allow from "$LAN_SUBNET" to any port 80 proto tcp
  else
    echo "WARNING: UFW active, but no LAN subnet provided."
    echo "Port 80 was not opened automatically."
  fi
fi

echo ""
echo "======================================="
echo " ASP.NET Core LAN setup completed"
echo "======================================="
echo "Webserver: $WEBSERVER"
echo "URL: http://${SERVER_IP}"
echo "Backend: http://127.0.0.1:${PORT}"
echo "HTTPS: disabled"
echo "======================================="

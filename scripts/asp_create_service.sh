#!/bin/sh
set -eu

# Usage: ./asp_create_service.sh <service_name> <service_executable> [<port>]

# root-check (ohne EUID: bashism)
if [ "$(id -u)" -ne 0 ]; then
  echo "please execute as root (sudo)."
  exit 1
fi

SERVICENAME="${1:-}"
SERVICEBIN="${2:-}"
PORT="${3:-}"

if [ -z "$SERVICENAME" ] || [ -z "$SERVICEBIN" ]; then
  echo "error: missing parameters."
  echo "usage: $0 <service_name> <service_executable> [<port>]"
  exit 1
fi

if [ -z "$PORT" ]; then
    PORT="5000"
fi

if [ ! -f "$SERVICEBIN" ]; then
  echo "error: service executable '$SERVICEBIN' not found."
  exit 1
fi

WORKDIR=$(dirname "$SERVICEBIN")
if [ ! -d "$WORKDIR" ] || [ "$WORKDIR" = "/" ]; then
  echo "error: invalid or dangerous working directory '$WORKDIR'."
  exit 1
fi

echo "$SERVICENAME installation started..."

echo "configuring user and rights..."
# idempotent user creation (system user, no login)
if id -u "${SERVICENAME}user" >/dev/null 2>&1; then
  echo "user '${SERVICENAME}user' already exists."
else
  if command -v useradd >/dev/null 2>&1; then
    useradd --system --create-home --home-dir "$WORKDIR" --shell /usr/sbin/nologin "${SERVICENAME}user"
  else
    adduser --disabled-login --gecos "" "${SERVICENAME}user" || true
  fi
fi
chown -R "${SERVICENAME}user:${SERVICENAME}user" "$WORKDIR"
chmod -R 700 "$WORKDIR"

# make app executable if present
if [ -f "$SERVICEBIN" ]; then
  chmod +x "$SERVICEBIN"
fi

echo "configuring service..."
cat <<EOF | sudo tee /etc/systemd/system/${SERVICENAME}.service > /dev/null
[Unit]
Description=${SERVICENAME}
After=network.target

[Service]
Type=simple
User=${SERVICENAME}user
WorkingDirectory=${WORKDIR}
Environment=ASPNETCORE_URLS=http://127.0.0.1:${PORT}
ExecStart=${SERVICEBIN}
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
if ! systemctl enable --now "${SERVICENAME}"; then
  echo "error: failed to enable and start service '${SERVICENAME}'."
  exit 1
fi

echo "Service '${SERVICENAME}' has been set up."

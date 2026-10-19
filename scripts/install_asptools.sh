#!/bin/sh
set -eu

if [ "$(id -u)" -ne 0 ]; then
  echo "please run as root (sudo)"
  exit 1
fi

SRC="https://raw.githubusercontent.com/MiHoCode/asp-linux-tools/main/scripts/"

# Hier einfach neue Skripte ergänzen:
SCRIPTS="asp_create_service.sh asp_create_webserver.sh asp_create_webserver_local.sh"

for SCRIPT in $SCRIPTS; do
  echo "Installing $SCRIPT ..."
  wget -O "/usr/local/bin/$SCRIPT" "${SRC}${SCRIPT}"
  chmod +x "/usr/local/bin/$SCRIPT"
done

echo "Installed all tool scripts"

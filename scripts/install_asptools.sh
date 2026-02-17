#!/bin/sh
set -eu

if [ "$(id -u)" -ne 0 ]; then
  echo "please execute as root (sudo)."
  exit 1
fi

SRC="https://raw.githubusercontent.com/MiHoCode/asp-linux-tools/main/scripts/"

SCRIPT1="asp_create_service.sh"
SCRIPT2="asp_create_webserver.sh"

SRC1="${SRC}${SCRIPT1}"
SRC2="${SRC}${SCRIPT2}"

wget -O /usr/local/bin/${SCRIPT1} $SRC1
chmod +x /usr/local/bin/${SCRIPT1}
wget -O /usr/local/bin/${SCRIPT2} $SRC2
chmod +x /usr/local/bin/${SCRIPT2}

echo "Installed all tool scripts"

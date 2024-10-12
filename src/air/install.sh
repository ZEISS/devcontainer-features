#!/bin/sh
set -e

echo "Activating feature 'air'"

# Default version
VERSION=${VERSION:-"latest"}

# Defailt install path
BIN=${BIN:-/usr/local/bin}

echo "Installing air version $VERSION"

# Clean up
rm -rf /var/lib/apt/lists/*

echo "Step 1, check if user is root"
if [ "$(id -u)" -ne 0 ]; then
    echo -e 'Script must be run as root. Use sudo, su, or add "USER root" to your Dockerfile before running this script.'
    exit 1
fi

echo "Step 2, check if architecture is supported"
ARCHITECTURE="$(uname -m | sed s/aarch64/arm64/ | sed s/x86_64/amd64/)"
if [ "${ARCHITECTURE}" != "amd64" ] && [ "${ARCHITECTURE}" != "x86_64" ] && [ "${ARCHITECTURE}" != "arm64" ] && [ "${ARCHITECTURE}" != "aarch64" ]; then
    echo "(!) Architecture $ARCHITECTURE unsupported"
    exit 1
fi

echo "Step 3, check the os in small case"
OS="$(uname -s | tr '[:upper:]' '[:lower:]')"

apt_get_update()
{
    if [ "$(find /var/lib/apt/lists/* | wc -l)" = "0" ]; then
        echo "Running apt-get update..."
        apt-get update -y
    fi
}

# Checks if packages are installed and installs them if not
check_packages() {
    if ! dpkg -s "$@" > /dev/null 2>&1; then
        apt_get_update
        apt-get -y install --no-install-recommends "$@"
    fi
}

export DEBIAN_FRONTEND=noninteractive

# Install dependencies
check_packages ca-certificates curl unzip

# Install air

curl -sSL "https://github.com/air-verse/air/releases/download/v${VERSION}/air_${VERSION}_${OS}_${ARCHITECTURE}" -o "${BIN}/air"
chmod +x "${BIN}/air"

# Clean up
rm -rf /var/lib/apt/lists/*

echo "Done!"
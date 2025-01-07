#!/bin/sh
set -e

echo "Activating feature 'ghc'"

# Default version
VERSION=${VERSION:-"latest"}

# Defailt install path
BIN=${BIN:-/usr/local/bin}

echo "Installing ghc version $VERSION"

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

# Install ghc

ghc_filename="ghc_${VERSION}_${OS}_${ARCHITECTURE}.tar.gz"

curl -fsSLO --compressed "https://github.com/zeiss/ghc/releases/download/v${VERSION}/${ghc_filename}"
tar -xzf "$ghc_filename" -C "${BIN}" ghc

# Clean up
rm -rf /var/lib/apt/lists/*

echo "Done!"
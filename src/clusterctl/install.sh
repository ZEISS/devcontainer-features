#!/bin/sh
set -e

echo "Activating feature 'clusterctl'"

# Default version
VERSION=${VERSION:-"latest"}

# Defailt install path
BIN=${BIN:-/usr/local/bin}

echo "Installing clusterctl version $VERSION"

# Clean up
rm -rf /var/lib/apt/lists/*

echo "Step 1, check if user is root"
if [ "$(id -u)" -ne 0 ]; then
    echo -e 'Script must be run as root. Use sudo, su, or add "USER root" to your Dockerfile before running this script.'
    exit 1
fi

echo "Step 2, check if architecture is supported"
architecture="$(uname -m | sed s/aarch64/arm64/ | sed s/x86_64/amd64/)"
if [ "${architecture}" != "amd64" ] && [ "${architecture}" != "x86_64" ] && [ "${architecture}" != "arm64" ] && [ "${architecture}" != "aarch64" ]; then
    echo "(!) Architecture $architecture unsupported"
    exit 1
fi

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

# Install clusterctl

curl -sSL "https://github.com/kubernetes-sigs/cluster-api/releases/download/${VERSION}/clusterctl-linux-${architecture}" -o "${BIN}/clusterctl"
chmod +x "${BIN}/clusterctl"

# Clean up
rm -rf /var/lib/apt/lists/*

echo "Done!"
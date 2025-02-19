#!/usr/bin/env bash

set -e

echo "Activating feature 'ghc'"

# Clean up
rm -rf /var/lib/apt/lists/*

VERSION=${VERSION:-"latest"}

if [ "$(id -u)" -ne 0 ]; then
    echo -e 'Script must be run as root. Use sudo, su, or add "USER root" to your Dockerfile before running this script.'
    exit 1
fi

apt_get_update()
{
    echo "Running apt-get update..."
    apt-get update -y
}

# Checks if packages are installed and installs them if not
check_packages() {
    if ! dpkg -s "$@" > /dev/null 2>&1; then
        if [ "$(find /var/lib/apt/lists/* | wc -l)" = "0" ]; then
            apt_get_update
        fi
        apt-get -y install --no-install-recommends "$@"
    fi
}

# from https://stackoverflow.com/questions/4023830/how-to-compare-two-strings-in-dot-separated-version-format-in-bash
function vercomp() {
  if [[ "$1" == "$2" ]]; then
    return 0
  fi
  local IFS=.
  # shellcheck disable=SC2206
  local i ver1=($1) ver2=($2)
  # fill empty fields in ver1 with zeros
  for ((i = ${#ver1[@]}; i < ${#ver2[@]}; i++)); do
    ver1[i]=0
  done
  for ((i = 0; i < ${#ver1[@]}; i++)); do
    if [[ -z ${ver2[i]} ]]; then
      # fill empty fields in ver2 with zeros
      ver2[i]=0
    fi
    if ((10#${ver1[i]} > 10#${ver2[i]})); then
      return 1
    fi
    if ((10#${ver1[i]} < 10#${ver2[i]})); then
      return 2
    fi
  done
  return 0
}

get_architecture() {
    local version="$1"
    local architecture_
    architecture="$(uname -m)"
    case $architecture in
        x86_64) architecture_="amd64";;
        aarch64 | armv8* | arm64) architecture_="arm64";;
        *) echo "(!) Architecture $architecture unsupported"; exit 1 ;;
    esac

    # x86_64 before 0.27.0
    vercomp "$version" "0.27.0"
    case $? in
    0) op='=' ;;
    1) op='>' ;;
    2) op='<' ;;
    esac
    if [[ "$op" == '<' && "$architecture" == 'x86_64' ]]; then
        architecture_="x86_64"
    fi

    echo "${architecture_}"
}

export DEBIAN_FRONTEND=noninteractive

# Figure out correct version of a three part version number is not passed
find_version_from_git_tags() {
    local variable_name=$1
    local requested_version=${!variable_name}
    if [ "${requested_version}" = "none" ]; then return; fi
    local repository=$2
    local prefix=${3:-"tags/v"}
    local separator=${4:-"."}
    local last_part_optional=${5:-"false"}
    if [ "$(echo "${requested_version}" | grep -o "." | wc -l)" != "2" ]; then
        local escaped_separator=${separator//./\\.}
        local last_part
        if [ "${last_part_optional}" = "true" ]; then
            last_part="(${escaped_separator}[0-9]+)?"
        else
            last_part="${escaped_separator}[0-9]+"
        fi
        local regex="${prefix}\\K[0-9]+${escaped_separator}[0-9]+${last_part}$"
        local version_list="$(git ls-remote --tags ${repository} | grep -oP "${regex}" | tr -d ' ' | tr "${separator}" "." | sort -rV)"
        if [ "${requested_version}" = "latest" ] || [ "${requested_version}" = "current" ] || [ "${requested_version}" = "lts" ]; then
            declare -g ${variable_name}="$(echo "${version_list}" | head -n 1)"
        else
            set +e
            declare -g ${variable_name}="$(echo "${version_list}" | grep -E -m 1 "^${requested_version//./\\.}([\\.\\s]|$)")"
            set -e
        fi
    fi
    if [ -z "${!variable_name}" ] || ! echo "${version_list}" | grep "^${!variable_name//./\\.}$" > /dev/null 2>&1; then
        echo -e "Invalid ${variable_name} value: ${requested_version}\nValid values:\n${version_list}" >&2
        exit 1
    fi
    echo "${variable_name}=${!variable_name}"
}

# Install dependencies
check_packages curl git tar

# Use a temporary locaiton for ghc archive
export TMP_DIR="/tmp/tmp-ghc"
mkdir -p ${TMP_DIR}
chmod 700 ${TMP_DIR}

# Install ghc
echo "(*) Installing ghc..."
find_version_from_git_tags VERSION https://github.com/zeiss/ghc
VERSION="${VERSION#"v"}"

architecture=$(get_architecture "$VERSION")
os="$(uname -s | tr '[:upper:]' '[:lower:]')"

curl -sSL -o ${TMP_DIR}/ghc.tar.gz "https://github.com/zeiss/ghc/releases/download/v${VERSION}/ghc_${VERSION}_${os}_${architecture}.tar.gz"
tar -xzf "${TMP_DIR}/ghc.tar.gz" -C "${TMP_DIR}" ghc
mv ${TMP_DIR}/ghc /usr/local/bin/ghc
chmod 0755 /usr/local/bin/ghc

# Clean up
rm -rf /var/lib/apt/lists/*

echo "Done!"
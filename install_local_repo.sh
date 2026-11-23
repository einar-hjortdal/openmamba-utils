#!/bin/bash
set -euo pipefail

sudo -v

REPO_PATH="${HOME}/.local/share/rpmrepo"
REPO_FILE="/etc/yum.repos.d/local.repo"

if ! command -v createrepo &>/dev/null; then
	sudo dnf install -y createrepo
fi

mkdir -p "${REPO_PATH}"
createrepo "${REPO_PATH}"

sudo tee "${REPO_FILE}" >/dev/null <<EOF
[local]
name=local
baseurl=file://${REPO_PATH}
enabled=1
gpgcheck=0
EOF

echo "done"

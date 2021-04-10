#!/bin/bash
set -euo pipefail
# rewrite the trace output to stdout
exec 3>&1
export BASH_XTRACEFD=3
set -x

[ "${GLIBC:-}" ] || exit 0
ARCH="$(uname -m)"

curl -fsSo glibc-linux4.pkg.tar.zst \
    "https://repo.archlinuxcn.org/$ARCH/glibc-linux4-$GLIBC-$ARCH.pkg.tar.zst"
tar -C / -xf glibc-linux4.pkg.tar.zst
yes | pacman -Udd --noprogressbar glibc-linux4.pkg.tar.zst && \
rm -f glibc-linux4.pkg.tar.zst

sed -i '/^IgnorePkg/ s/$/ glibc/' /etc/pacman.conf

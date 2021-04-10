#!/bin/bash
set -euo pipefail
# rewrite the trace output to stdout
exec 3>&1
export BASH_XTRACEFD=3
set -x

: "${BRANCH:=stable}"
ARCH="$(uname -m)"
[ -f "/build/workspace/PKGBUILD" ]

pkg_root="/build/packages/$BRANCH/$ARCH"
pkg_db="$pkg_root/manjarocn.db.tar.xz"
pkg_cache_root=/pkgcache/$BRANCH/$ARCH
mkdir -p "$pkg_root" /build/sources /build/srcpackages

cp -R /gpg /home/builder/.gnupg
chown -R builder:builder /build /home/builder

[ "${PACKAGER:-}" ] && sudo -u builder gpg --list-secret-keys "$PACKAGER"
[ "${GPGKEY:-}" ] && sudo -u builder gpg --list-secret-keys "$GPGKEY"
sed -Ei "/^#PACKAGER/ { s/^#//; s/=.*/='$PACKAGER'/ }; /^#GPGKEY/ { s/^#//; s/=.*/='$GPGKEY'/ }" /etc/makepkg.conf

sudo -u builder gpg --armor --export "$GPGKEY" | pacman-key --add /dev/stdin
pacman-key --lsign-key "$GPGKEY"

for package in "$pkg_root/"*.pkg.tar.zst; do
    rm -f "$pkg_cache_root/${package##*/}"
done

[ -f "$pkg_db" ] || sudo -u builder repo-add --sign --key "$GPGKEY" "$pkg_db"
[ "${UPDATEMIRRORS:-0}" -gt 0 ] && pacman-mirrors --geoip
pacman -Syyuu --noconfirm --noprogressbar

cd /build/workspace

if [ "$(source PKGBUILD && type -t pkgver)" == 'function' ]; then
    $(source PKGBUILD && echo "${makedepends[@]}" | xargs | grep -Eiq '(^|\s)git(\s|$)') && pacman -S --noconfirm --noprogressbar git
    sudo -u builder makepkg -do
fi

# `pacman -Si` returns 1 if package not in sync database
repo_ver=$(pacman -Si "$(source PKGBUILD && echo "$pkgname" | xargs)" | grep -Ei '^version' | awk -F':' '{ print $2 }' | xargs) && \
    pkg_ver="$(source PKGBUILD && echo "$pkgver" | xargs)-$(source PKGBUILD && echo "$pkgrel" | xargs)" && \
    [ "$repo_ver" ] && [ "$pkg_ver" != '-' ] && [ "$(vercmp "$repo_ver" "$pkg_ver")" -ge 0 ] && \
    exit 0

[ "${UPDATESUMS:-0}" -gt 0 ] && sudo -u builder updpkgsums
gpg_keys=$(source PKGBUILD && echo "${validpgpkeys[@]}" | xargs)
[ "$gpg_keys" ] && sudo -u builder gpg --recv-keys $gpg_keys

sudo -u builder makepkg -Ccfs --noconfirm --noprogressbar
sudo -u builder repo-add --new --remove --sign --key "$GPGKEY" "$pkg_db" "$pkg_root/"*.pkg.tar.zst
rm -f "$pkg_root/"*.old "$pkg_root/"*.old.sig

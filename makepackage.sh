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

find "$pkg_root" -name '*.pkg.tar.zst' -printf "$pkg_cache_root/%f\n" | xargs rm -f

[ -f "$pkg_db" ] || sudo -u builder repo-add --sign --key "$GPGKEY" "$pkg_db"
[ "${UPDATEMIRRORS:-0}" -gt 0 ] && pacman-mirrors --geoip
pacman -Syyuu --noconfirm --noprogressbar

cd /build/workspace
pkgname=$(source PKGBUILD && echo "$pkgname" | xargs)

# update $pkgver
[ "$(source PKGBUILD && type -t pkgver)" == 'function' ] && sudo -u builder makepkg --cleanbuild --nodeps --nobuild --noprepare
# `pacman -Si` returns 1 if package not in sync database
if repover=$(pacman -Si "$pkgname" | grep -Ei '^version' | cut -d':' -f'2-' | xargs); then
    pkgver="$(source PKGBUILD && echo "$pkgver" | xargs)"
    if [ "$pkgver" ]; then
        pkgrel=$(set +u; source PKGBUILD && echo "$pkgrel" | xargs)
        epoch=$(set +u; source PKGBUILD && echo "$epoch" | xargs)
        [ "$pkgrel" ] && pkgver="$pkgver-$pkgrel"
        [ "$epoch" ] && pkgver="$epoch:$pkgver"
    fi
    [ "$repover" ] && [ "$pkgver" ] && [ "$(vercmp "$repover" "$pkgver")" -ge 0 ] && exit 0
fi

[ "${UPDATESUMS:-0}" -gt 0 ] && sudo -u builder updpkgsums
gpg_keys=$(source PKGBUILD && echo "${validpgpkeys[@]}" | xargs)
[ "$gpg_keys" ] && sudo -u builder gpg --recv-keys $gpg_keys

sudo -u builder makepkg --cleanbuild --clean --force --syncdeps --noconfirm --noprogressbar --needed
sudo -u builder repo-add --new --remove --sign --key "$GPGKEY" "$pkg_db" "$pkg_root/$pkgname-$pkgver.pkg.tar.zst"
rm -f "$pkg_root/"*.old "$pkg_root/"*.old.sig

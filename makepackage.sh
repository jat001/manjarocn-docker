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

sudo -u builder gpg --list-secret-keys "$PACKAGER" >/dev/null
sudo -u builder gpg --list-secret-keys "$GPGKEY" >/dev/null
sed -Ei "/^#PACKAGER/ { s/^#//; s/=.*/='$PACKAGER'/ };
/^#GPGKEY/ { s/^#//; s/=.*/='$GPGKEY'/ };
" /etc/makepkg.conf

sudo -u builder gpg --armor --export "$GPGKEY" | pacman-key --add /dev/stdin
pacman-key --lsign-key "$GPGKEY" &>/dev/null

find "$pkg_root" -name '*.pkg.tar.zst' -printf "$pkg_cache_root/%f\n" | xargs rm -f

[ -f "$pkg_db" ] || sudo -u builder repo-add --sign --key "$GPGKEY" "$pkg_db"
[ "${UPDATEMIRRORS:-0}" -gt 0 ] && pacman-mirrors --geoip
pacman -Syyuu --noconfirm --noprogressbar

function getvar () {
    varname="$1"
    required=${2:-0}

    varval=$(set +x; source PKGBUILD >/dev/null; set +u; echo ${!varname} | xargs)
    [ $required -ne 0 ] && [ -z "$varval" ] && return 1
    echo "$varval"
}

cd /build/workspace

pkgname="$(getvar 'pkgname' 1)"
pkgver="$(getvar 'pkgver' 1)"
pkgrel="$(getvar 'pkgrel' 1)"

pkgver="$pkgver-$pkgrel"
epoch=$(getvar 'epoch')
[ -n "$epoch" ] && pkgver="$epoch:$pkgver"

# `pacman -Si` returns 1 if package not in sync database
repover=$(pacman -Si "$pkgname" | grep -Ei '^version' | cut -d':' -f'2-' | xargs) \
    && [ "$(vercmp "$repover" "$pkgver")" -ge 0 ] && exit 0

[ "${UPDATESUMS:-0}" -gt 0 ] && sudo -u builder updpkgsums
gpg_keys=$(getvar 'validpgpkeys[@]')
[ -n "$gpg_keys" ] && sudo -u builder gpg --recv-keys $gpg_keys

sudo -u builder "SRCDEST=/build/sources/$pkgname" makepkg --cleanbuild --clean --force --syncdeps --noconfirm --noprogressbar --needed
sudo -u builder repo-add --new --remove --sign --key "$GPGKEY" "$pkg_db" "$pkg_root/$pkgname-$pkgver-$ARCH.pkg.tar.zst"
rm -f "$pkg_root/"*.old "$pkg_root/"*.old.sig

#!/bin/bash
set -euo pipefail
set -x

: "${BRANCH:='stable'}"
ARCH="$(uname -m)"

[ -f "/build/PKGBUILD" ] || exit 1
cd /build
mkdir -p "packages/$BRANCH/$ARCH" sources srcpackages

cp -R /gpg /home/builder/.gnupg
chown -R builder:builder /build /home/builder

[ "${PACKAGER:-}" ] && sudo -u builder gpg -K "$PACKAGER"
[ "${GPGKEY:-}" ] && sudo -u builder gpg -K "$GPGKEY"
sed -Ei "/^#PACKAGER/ { s/^#//; s/=.*/='$PACKAGER'/ }; /^#GPGKEY/ { s/^#//; s/=.*/='$GPGKEY'/ }" /etc/makepkg.conf

for package in '/build/packages/*.pkg.tar.*'; do
    rm -f "/pkgcache/$BRANCH/$ARCH/$package"
done
[ -f "/build/packages/$BRANCH/$ARCH/packages.db.tar.xz" ] || \
    sudo -u builder repo-add "/build/packages/$BRANCH/$ARCH/packages.db.tar.xz"

[ "${UPDATEMIRRORS:0}" -gt 0 ] && pacman-mirrors --geoip
pacman --noconfirm --noprogressbar -Syyuu

if [ "$(source PKGBUILD; type -t pkgver)" == 'function' ]; then
    [[ "$(source PKGBUILD; echo \"\${makedepends[*]})\")" =~ 'git' ]] && pacman --noconfirm --noprogressbar -S git
    sudo -u builder makepkg -do
fi

repo_ver=$(pacman -Si "$(source PKGBUILD; echo \$pkgname)" | grep -Ei '^version' | awk -F':' '{ print $2 }' | xargs)
if [ "$repo_ver" ]; then
    pkg_ver="$(source PKGBUILD; echo \$pkgver)-$(source PKGBUILD; echo \$pkgrel)"
    [ "$(vercmp $repo_ver $pkg_ver)" -ge 0 ] && exit 0
fi

[ "${IMTOOLAZYTOCHECKSUMS:0}" -gt 0 ] && sudo -u builder updpkgsums
sudo -u builder makepkg --noconfirm --noprogressbar -Ccfs

sudo -u builder repo-add -Rnsv /build/packages/packages.db.tar.xz /build/packages/*.pkg.tar.zst

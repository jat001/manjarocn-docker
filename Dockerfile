FROM manjarolinux/build-stable:latest

RUN sed -i '/#set bell-style none/ s/^#//' /etc/inputrc
RUN sed -Ei '/#CacheDir/ { s/^#//; s~=.*~= /pkgcache~ }' /etc/pacman.conf
RUN sed -i '/#IgnorePkg/ { s/^#//; s/$/ filesystem glibc/ }' /etc/pacman.conf
RUN sed -i 's/-c"$countries"/--geoip/g' /makepackage.sh

RUN rm -fr /etc/pacman.d/gnupg
RUN pacman-key --init
RUN pacman-key --populate archlinux
RUN pacman-key --populate manjaro

RUN mkdir -p /build/packages
RUN repo-add /build/packages/packages.db.tar.xz
RUN mkdir -p /pkgcache

ARG glibc=https://repo.archlinuxcn.org/x86_64/glibc-linux4-2.33-5-x86_64.pkg.tar.zst
RUN curl -fsSo glibc-linux4-x86_64.pkg.tar.zst $glibc
RUN yes | pacman -U glibc-linux4-x86_64.pkg.tar.zst
RUN rm -f glibc-linux4-x86_64.pkg.tar.zst

RUN pacman-mirrors --geoip
RUN pacman --noconfirm --noprogressbar -Syyu

RUN rm -fr /build/packages
RUN rm -f /var/lib/pacman/sync/*
RUN rm -fr /pkgcache/*
RUN rm -fr /var/cache/pacman/pkg
RUN ln -s /pkgcache /var/cache/pacman/pkg

ENV PACKAGER="Manjaro CN Build Server <build@manjarocn.org>"
ENV GPGKEY="974B3711CFB9BF2D"

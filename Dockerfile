FROM manjarolinux/base:latest

ARG BRANCH=stable

RUN mkdir -p /gpg "/pkgcache/$BRANCH/$(uname -m)" /build
VOLUME [ "/gpg" "/pkgcache" "/build" ]

RUN sed -i '/#set bell-style none/ s/^#//' /etc/inputrc

RUN useradd -m builder
RUN mkdir -p /etc/sudoers.d
RUN echo 'builder ALL=(root) NOPASSWD:/usr/bin/pacman' > /etc/sudoers.d/makepkg

RUN sed -Ei $'/^#CacheDir/ { s/^#//; s#=.*#= '"/pkgcache/$BRANCH/$(uname -m)"'# }; \
/^#IgnorePkg/ { s/^#//; s/=.*/= filesystem/ } \
' /etc/pacman.conf

ARG GLIBC
ADD --chmod=755 patch_glibc.sh /
RUN /patch_glibc.sh
RUN rm -f /patch_glibc.sh

RUN rm -fr /etc/pacman.d/gnupg
RUN pacman-key --init
RUN pacman-key --populate

RUN pacman-mirrors --geoip -a -B "$BRANCH"
RUN pacman -Syyuu --noconfirm --noprogressbar --needed base-devel
RUN rm -f /var/lib/pacman/sync/* "/pkgcache/$BRANCH/$(uname -m)/*"

RUN echo $'\n\
[manjarocn]\n\
SigLevel = Required TrustedOnly\n\
Server = '"file:///build/packages/$BRANCH/$(uname -m)"$'\n\
' >> /etc/pacman.conf

RUN sed -Ei '/^#PKGDEST/ { s/^#//; s#=.*#='"'/build/packages/$BRANCH/$(uname -m)'"'# }; \
/^#SRCDEST/ { s/^#//; s#=.*#='"'/build/sources'"'# }; \
/^#SRCPKGDEST/ { s/^#//; s#=.*#='"'/build/srcpackages'"'# }; \
/^BUILDENV/ s/=.*/=(!distcc color !ccache !check sign)/; \
' /etc/makepkg.conf

ENV PACKAGER="Manjaro CN Build Server <build@manjarocn.org>"
ENV GPGKEY="974B3711CFB9BF2D"

ADD --chmod=755 makepackage.sh /
CMD [ "/makepackage.sh" ]

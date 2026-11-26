# Wine for old Windows games (CD images, GOG installers).
#   docker-images-update wine
# Used through `wine-game` (linux/scripts): every game gets its own Wine prefix on
# the host in ~/Games/NAME, so the image itself stays clean and can be rebuilt.

FROM my/base

# en_US and ru_RU: games without Unicode use the codepage of LANG (cp1251 for Russian)
RUN sed -i -e 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' \
		-e 's/^#ru_RU.UTF-8 UTF-8/ru_RU.UTF-8 UTF-8/' /etc/locale.gen && \
	locale-gen

# wine: 32-bit games run through WoW64; multilib only in case a package still wants it.
# bsdtar (libarchive, already in the base) unpacks the .iso files.
RUN printf '\n[multilib]\nInclude = /etc/pacman.d/mirrorlist\n' >> /etc/pacman.conf && \
	pacman --cachedir /tmp -Sy --noconfirm --needed \
		wine wine-mono wine-gecko winetricks cabextract unzip icoutils \
		libpulse alsa-plugins gnutls \
		mesa vulkan-icd-loader vulkan-intel vulkan-radeon \
		xorg-xrandr ttf-liberation && \
	pacman --cachedir /tmp -Scc --noconfirm && \
	rm -rf /tmp/*

COPY wine-run /usr/local/bin/wine-run

ENV WINEDEBUG=-all
WORKDIR /home/user
USER user
CMD [ "winecfg" ]

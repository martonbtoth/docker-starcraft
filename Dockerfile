FROM ubuntu:22.04
MAINTAINER Alexander Wellbrock <a.wellbrock@mailbox.org>

### X11 server: inspired by suchja/x11server and suchja/wine ###

# first create user and group for all the X Window stuff
# required to do this first so we have consistent uid/gid between server and client container
RUN addgroup --system starcraft \
  && adduser \
    --home /home/starcraft \
    --disabled-password \
    --shell /bin/bash \
    --gecos "user for running starcraft brood war" \
    --ingroup starcraft \
    --quiet \
    starcraft \
  && adduser starcraft sudo

RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections

# Install packages for building the image
RUN apt-get update -y \
  && apt-get install -y \
    curl \
    unzip \
    p7zip \
    software-properties-common \
    vim \
    sudo \
    apt-transport-https \
    winbind \
    gpg-agent \
    wget \
    tigervnc-standalone-server \
    tigervnc-xorg-extension


# Install packages required for connecting against X Server
RUN apt-get update && apt-get install -y --no-install-recommends \
  xvfb \
  xauth \
  x11vnc \
  x11-utils \
  x11-xserver-utils

ENV DISPLAY :0.0

# Define which versions we need
ENV WINE_MONO_VERSION 4.6.4
ENV WINE_GECKO_VERSION 2.47

RUN mkdir -pm755 /etc/apt/keyrings \
  && wget -O /etc/apt/keyrings/winehq-archive.key https://dl.winehq.org/wine-builds/winehq.key \
  && wget -NP /etc/apt/sources.list.d/ https://dl.winehq.org/wine-builds/ubuntu/dists/jammy/winehq-jammy.sources

# Install wine and related packages
RUN dpkg --add-architecture i386 \
  && apt-get update -y \
  && apt-get install -y --install-recommends \
    winehq-stable \
  && rm -rf /var/lib/apt/lists/*

# Use the latest version of winetricks
RUN curl -SL 'https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks' -o /usr/local/bin/winetricks \
  && chmod +x /usr/local/bin/winetricks

ENV WINEPREFIX=/home/starcraft/.wine 
ENV WINEARCH=win32

# These package are necessery for the init of wine
# However they should not be removed because wine will then complain
# that they are gone, blocking all other gui applications.
RUN mkdir /opt/wine-stable/share/wine/mono \
    && curl -L https://dl.winehq.org/wine/wine-mono/7.4.0/wine-mono-7.4.0-x86.msi -o /opt/wine-stable/share/wine/mono/wine-mono-7.4.0-x86.msi
RUN mkdir /opt/wine-stable/share/wine/gecko \
    && curl -L https://dl.winehq.org/wine/wine-gecko/2.47.3/wine-gecko-2.47.3-x86.msi -o /opt/wine-stable/share/wine/gecko/wine-gecko-2.47.3-x86.msi

RUN mkdir ~/.Xauthority && mkdir ~/.vnc

# Starting an x server before running wine init prevents some errors
RUN Xvfb :0 -auth ~/.Xauthority -screen 0 1024x768x24 >> /var/log/xvfb.log 2>&1 & \
    su -c "wine wineboot --init" starcraft \
    && su -c "winetricks -q vcrun2013" starcraft

RUN rm /tmp/.X0-lock

ENV BOT_DIR /home/starcraft/.wine/drive_c/bot
ENV BOT_PATH=$BOT_DIR/bot.dll BOT_DEBUG_PATH=$BOT_DIR/bot_d.dll

# Volume to place your bot inside
VOLUME $BOT_DIR
WORKDIR $BOT_DIR

# Supply your copy of StarCraft within data/StarCraft
# At least the directory should be there...
ENV STARCRAFT /home/starcraft/.wine/drive_c/StarCraft
ADD data/StarCraft/ $STARCRAFT

# Get BWAPI version 412
ENV BWAPI_DIR /home/starcraft/.wine/drive_c/bwapi/
RUN curl -L https://github.com/lionax/bwapi/releases/download/v4.1.2/BWAPI-4.1.2.zip -o /tmp/bwapi.zip \
   && unzip /tmp/bwapi.zip -d $BWAPI_DIR \
      && mv $BWAPI_DIR/BWAPI/* $BWAPI_DIR \
      && rm -R $BWAPI_DIR/BWAPI \
      && rm /tmp/bwapi.zip \
      && chmod 755 -R $BWAPI_DIR

# Get bwapi-data as of version 412
RUN curl -L https://github.com/lionax/bwapi/releases/download/v4.1.2/bwapi-data-4.1.2.zip -o /tmp/bwapi-data.zip \
   && unzip /tmp/bwapi-data.zip -d $STARCRAFT \
      && rm /tmp/bwapi-data.zip \
      && chmod 755 -R $STARCRAFT/bwapi-data

RUN chown -R starcraft:starcraft /home/starcraft/

ADD entrypoint.sh /bin/entrypoint
RUN chmod +x /bin/entrypoint

WORKDIR $STARCRAFT

RUN wget -q http://files.theabyss.ru/sc/starcraft.zip
RUN unzip starcraft.zip

WORKDIR $BOT_DIR

ENTRYPOINT ["entrypoint"]
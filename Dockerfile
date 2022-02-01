# vim:set ft=dockerfile:
FROM debian:bullseye AS base

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y libssl1.1 zlib1g libmariadb3 libuuid1 libtiff5 libtiffxx5 libjpeg62-turbo libxml2 libsqlite3-0 \
    libcurl4 libpcre16-3 libpcre3-dev libpcre32-3 libpcrecpp0v5 libspeex1 libspeexdsp1 libldns3 libedit2 libavformat58 libswscale5 \
    liblua5.2-0 libopus0 libpq5 libasound2 libflac8 libogg0 libvorbis0a libvorbisenc2 libvorbisfile3 python-all

FROM base AS build

RUN apt-get install -y git build-essential automake cmake libssl-dev shtool pkg-config zlib1g-dev libtool libtool-bin libmariadb-dev uuid-dev \
    debhelper libtiff-dev libjpeg-dev dpatch doxygen autotools-dev xsltproc \
    libsqlite3-dev libcurl4-openssl-dev libpcre3-dev libspeex-dev libspeexdsp-dev libldns-dev libedit-dev yasm \
    libavformat-dev libswscale-dev liblua5.2-dev libopus-dev libpq-dev libasound2-dev \
    libflac-dev libogg-dev libtool libvorbis-dev libopus-dev python-all-dev

COPY . /usr/src/freeswitch/

WORKDIR /usr/src/freeswitch/libs
RUN git clone -b v1.13.7 https://github.com/freeswitch/sofia-sip.git
WORKDIR /usr/src/freeswitch/libs/sofia-sip
RUN ./autogen.sh && ./configure && make && make install

WORKDIR /usr/src/freeswitch/libs
RUN git clone https://github.com/freeswitch/spandsp.git
WORKDIR /usr/src/freeswitch/libs/spandsp
RUN ./bootstrap.sh && ./configure && make && make install

WORKDIR /usr/src/freeswitch/libs
RUN git clone -b v1.7.0 https://github.com/signalwire/libks.git
WORKDIR /usr/src/freeswitch/libs/libks
RUN cmake . -DCMAKE_BUILD_TYPE=Release && make && make install

WORKDIR /usr/src/freeswitch/libs
RUN git clone -b 1.3.0 https://github.com/signalwire/signalwire-c.git
WORKDIR /usr/src/freeswitch/libs/signalwire-c
RUN cmake . -DCMAKE_BUILD_TYPE=Release && make && make install

WORKDIR /usr/src/freeswitch/libs
RUN rm -rf libsndfile && git clone -b v1.0.30 https://github.com/libsndfile/libsndfile.git
WORKDIR /usr/src/freeswitch/libs/libsndfile
RUN cmake . -DBUILD_SHARED_LIBS=ON && make && make install

WORKDIR /usr/src/freeswitch
RUN ./bootstrap.sh && ./configure && make && make install

FROM base AS final

ENV LD_LIBRARY_PATH=/usr/local/lib
#ENV PATH=/usr/local/freeswitch/bin

COPY --from=build /usr/local/ /usr/local/

WORKDIR /usr/local/freeswitch

## Ports
# Open the container up to the world.
### 8021 fs_cli, 5060 5061 5080 5081 sip and sips, 64535-65535 rtp
EXPOSE 8021/tcp
EXPOSE 5060/tcp 5060/udp 5080/tcp 5080/udp
EXPOSE 5061/tcp 5061/udp 5081/tcp 5081/udp
EXPOSE 7443/tcp
EXPOSE 5070/udp 5070/tcp
EXPOSE 64535-65535/udp
EXPOSE 16384-32768/udp

# Volumes
## Freeswitch Configuration
VOLUME ["/etc/freeswitch"]
## Tmp so we can get core dumps out
VOLUME ["/tmp"]

# Healthcheck to make sure the service is running
SHELL       ["/bin/bash"]
HEALTHCHECK --interval=15s --timeout=5s \
    CMD  fs_cli -x status | grep -q ^UP || exit 

CMD freeswitch -c

FROM varnish:7.6.1 AS varnish
FROM varnish AS build_vmod
ENV VMOD_BUILD_DEPS="libcurl4-openssl-dev libpcre3-dev libarchive-dev git cmake build-essential"
USER root
RUN set -e; \
    export DEBIAN_FRONTEND=noninteractive; \
    apt-get update; \
    apt-get -y install /pkgs/*.deb $VMOD_DEPS $VMOD_BUILD_DEPS; \
    rm -rf /var/lib/apt/lists/*;
RUN set -e; \
    cd /; \
    git clone https://github.com/varnish/libvmod-tinykvm.git; \
    cd libvmod-tinykvm \
    git checkout 2442bdd9d1ac88e700eba8231bac6980be888f35; \
    git submodule init; \
    git submodule update;
RUN set -e; \
    cd /libvmod-tinykvm; \
    mkdir -p .build; \
    cd .build; \
    cmake .. -DCMAKE_BUILD_TYPE=Release -DVARNISH_PLUS=OFF; \
    cmake --build . -j6;

FROM rust:1.85-slim-bookworm AS build_rust
RUN DEBIAN_FRONTEND=noninteractive apt-get update && apt-get -y install curl libclang-dev build-essential && rm -rf /var/lib/apt/lists/*
COPY  --exclude=*.vcl --exclude=*.md --exclude=*.js --exclude=Dockerfile . /build/
WORKDIR /build
# Do not put rustflags in .cargo/config.toml as that causes build error:
# error: cannot produce proc-macro for `asn1-rs-derive v0.4.0` as the target `x86_64-unknown-linux-gnu` does not support these crate types
RUN RUSTFLAGS="-C target-feature=+crt-static" cargo build --release --target x86_64-unknown-linux-gnu

FROM varnish
ENV VMOD_RUN_DEPS="libcurl4 libpcre3 libarchive13"
USER root
RUN set -e; \
    export DEBIAN_FRONTEND=noninteractive; \
    apt-get update; \
    apt-get -y install $VMOD_RUN_DEPS; \
    rm -rf /var/lib/apt/lists/*;
COPY --from=build_vmod /libvmod-tinykvm/.build/libvmod_*.so /usr/lib/varnish/vmods/
COPY --from=build_rust /build/target/x86_64-unknown-linux-gnu/release/deno-varnish /deno-varnish
COPY main.js /main.js
COPY default.vcl /etc/varnish/default.vcl
USER varnish

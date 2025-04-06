FROM varnish:7.7.0 AS varnish

FROM varnish AS build_vmod
ENV VMOD_BUILD_DEPS="libcurl4-openssl-dev libpcre3-dev libarchive-dev libjemalloc-dev git cmake build-essential"
USER root
WORKDIR /libvmod-tinykvm
RUN set -e; \
    export DEBIAN_FRONTEND=noninteractive; \
    apt-get update; \
    apt-get -y install /pkgs/*.deb $VMOD_DEPS $VMOD_BUILD_DEPS; \
    rm -rf /var/lib/apt/lists/*;
RUN set -e; \
    git init; \
    git remote add origin https://github.com/varnish/libvmod-tinykvm.git; \
    git fetch --depth 1 origin 23f88dca9327ea778d9b572b674da22bc9e9da0e; \
    git checkout FETCH_HEAD; \
    git submodule update --init --recursive;
RUN set -e; \
    mkdir -p .build; \
    cd .build; \
    cmake .. -DCMAKE_BUILD_TYPE=Release -DVARNISH_PLUS=OFF; \
    cmake --build . -j6;

FROM rust:1.85-slim-bookworm AS build_rust
RUN DEBIAN_FRONTEND=noninteractive apt-get update && apt-get -y install curl libclang-dev build-essential && rm -rf /var/lib/apt/lists/*
WORKDIR /build
# Do not put rustflags in .cargo/config.toml as that causes build error:
# error: cannot produce proc-macro for `asn1-rs-derive v0.4.0` as the target `x86_64-unknown-linux-gnu` does not support these crate types
ENV RUSTFLAGS="-C target-feature=+crt-static"
# Build and cache the dependencies
COPY Cargo.toml Cargo.lock ./
RUN mkdir src benches \
    && echo "fn main() {}" > src/main.rs \
    && echo "" > benches/invoke_op.rs \
    && cargo fetch \
    && cargo build --release --target x86_64-unknown-linux-gnu \
    && rm -rf src benches
# Build
COPY --exclude=*.vcl --exclude=*.md --exclude=*.js --exclude=Dockerfile . ./
RUN  cargo build --release --target x86_64-unknown-linux-gnu

FROM varnish
ENV VMOD_RUN_DEPS="libcurl4 libpcre3 libarchive13 libjemalloc2"
USER root
RUN set -e; \
    export DEBIAN_FRONTEND=noninteractive; \
    apt-get update; \
    apt-get -y install $VMOD_RUN_DEPS; \
    rm -rf /var/lib/apt/lists/*;
COPY --from=build_vmod /libvmod-tinykvm/.build/libvmod_*.so /usr/lib/varnish/vmods/
COPY --from=build_rust /build/target/x86_64-unknown-linux-gnu/release/deno-varnish /
COPY --from=build_rust /build/target/x86_64-unknown-linux-gnu/release/blockon /
COPY --from=build_rust /build/target/x86_64-unknown-linux-gnu/release/onget /
COPY --from=build_rust /build/target/x86_64-unknown-linux-gnu/release/output /
COPY default.vcl /etc/varnish/default.vcl
COPY main.js /
COPY output.js /
COPY output.html /
COPY renderer.js /
USER varnish

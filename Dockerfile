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
    git fetch --depth 1 origin b32e4900c22c263794eae699f0bb05ef157ea9a0; \
    git checkout FETCH_HEAD; \
    git submodule update --init --recursive;
RUN set -e; \
    mkdir -p .build; \
    cd .build; \
    cmake .. -DCMAKE_BUILD_TYPE=Release -DVARNISH_PLUS=OFF; \
    cmake --build . -j6;
RUN set -e; \
    cd .build; \
    cp ../src/kvm/tests/kvm_api.h .; \
    echo '#include "kvm_api.h"' > kvm_api.c; \
    gcc -shared -o libkvm_api.so -fPIC kvm_api.c;

FROM rust:1.86-slim-bookworm AS build_rust
RUN DEBIAN_FRONTEND=noninteractive apt-get update && apt-get -y install git curl libclang-dev build-essential cmake clang && rm -rf /var/lib/apt/lists/*
WORKDIR /build

FROM build_rust AS build_deno
RUN set -e; \
    git init; \
    git remote add origin https://github.com/lrowe/deno.git; \
    git fetch --depth 1 origin b2191cc032b70a97d64dff5878ddb2db2faf2f5e; \
    git checkout FETCH_HEAD; \
    git submodule update --init --recursive;
RUN cargo build

FROM build_rust AS build_deno_varnish
# Do not put rustflags in .cargo/config.toml as that causes build error:
# error: cannot produce proc-macro for `asn1-rs-derive v0.4.0` as the target `x86_64-unknown-linux-gnu` does not support these crate types
ARG RUSTFLAGS="-C target-feature=+crt-static"
ENV RUSTFLAGS="${RUSTFLAGS}"
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
RUN cargo build --release --target x86_64-unknown-linux-gnu

FROM varnish
ENV VMOD_RUN_DEPS="libcurl4 libpcre3 libarchive13 libjemalloc2"
USER root
RUN set -e; \
    export DEBIAN_FRONTEND=noninteractive; \
    apt-get update; \
    apt-get -y install $VMOD_RUN_DEPS; \
    rm -rf /var/lib/apt/lists/*;
COPY --from=denoland/deno:bin-2.3.1 /deno /usr/local/bin/deno
COPY --from=build_vmod /libvmod-tinykvm/.build/libvmod_*.so /usr/lib/varnish/vmods/
COPY --from=build_deno_varnish /build/target/x86_64-unknown-linux-gnu/release/deno-varnish /
COPY --from=build_deno_varnish /build/target/x86_64-unknown-linux-gnu/release/blockon /
COPY --from=build_deno_varnish /build/target/x86_64-unknown-linux-gnu/release/onget /
COPY --from=build_deno_varnish /build/target/x86_64-unknown-linux-gnu/release/output /
WORKDIR /mnt
COPY default.vcl .
COPY *.compute.json .
COPY *.ext.js .
COPY output.html .
COPY --from=build_vmod /libvmod-tinykvm/.build/libkvm_api.so .
COPY varnish.ts .
COPY *.ffi.ts .
RUN set -e; \
    export V8_FLAGS="--single-threaded,--max-old-space-size=64,--max-semi-space-size=64"; \
    deno compile --allow-all "--v8-flags=$V8_FLAGS" -o hello.ffi.exe hello.ffi.ts; \
    deno compile --allow-all "--v8-flags=$V8_FLAGS" -o output.ffi.exe output.ffi.ts; \
    # https://github.com/denoland/deno/issues/29129
    deno compile --no-check --allow-all "--v8-flags=$V8_FLAGS" -o renderer.ffi.exe renderer.ffi.ts;
USER varnish
ENV VARNISH_HTTP_PORT=8080
ENV VARNISH_VCL_FILE=/mnt/default.vcl

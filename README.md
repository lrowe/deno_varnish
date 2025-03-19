# Experiment embedding deno_runtime in Varnish TinyKVM.

This is very early in development and doesn't work yet.

## Build static binary and validate that it runs on Linux

> [!NOTE]  
> Do not put rustflags in .cargo/config.toml as that causes build error:
> error: cannot produce proc-macro for `asn1-rs-derive v0.4.0` as the target `x86_64-unknown-linux-gnu` does not support these crate types

Uses the static glibc approach from [Building static Rust binaries for Linux](https://msfjarvis.dev/posts/building-static-rust-binaries-for-linux/).
By not using musl we avoid a lengthy v8 build and reuse the published glibc build artifacts from https://github.com/denoland/rusty_v8/releases/.

```
RUSTFLAGS="-C target-feature=+crt-static" cargo build --release --target x86_64-unknown-linux-gn
ldd ./target/x86_64-unknown-linux-gnu/release/deno-varnish # statically linked
DENO_V8_FLAGS="--jitless,--single-threaded,--single-threaded-gc" SCRIPT="$PWD/main.js" ./target/x86_64-unknown-linux-gnu/release/deno-varnish
lease/deno-varnish
```

This produces the following output with the expected segmentation fault.
```
Running file:///[...]/deno_varnish/main.js...
Hello from deno_varnish
Segmentation fault (core dumped)
```

Inspecting the coredump with gdb shows that the segfault happens when the kvm asm api is called.
```
# Enable core dumps on Ubuntu 24.04
sudo sysctl -w kernel.core_pattern=core.%u.%p.%t # to enable core generation
ulimit -c unlimited
gdb ./target/x86_64-unknown-linux-gnu/release/deno-varnish core[...]
[...]
Program terminated with signal SIGSEGV, Segmentation fault.
#0  0x[...] in deno_varnish::varnish::set_backend_get ()
```

## Running inside Varnish TinyKVM

I've been using podman but this should also work under docker.
I installed the static version of podman from https://github.com/mgoltzsche/podman-static on Ubuntu 24.04 and followed the apparmor profile instructions.
And replaced `docker.io` with `mirror.gcr.io` in /etc/containers/registries.conf.

Build 

    podman build -t deno-varnish .

Then run concurrently:

    podman run --rm -p 127.0.0.1:8080:8080 -e VARNISH_HTTP_PORT=8080 --device /dev/kvm --group-add keep-groups --name deno-varnish deno-varnish
    podman exec -it deno-varnish varnishlog
    curl http://localhost:8080/hello


## Issues

### Unhandled system calls

Does not prevent it from working. https://filippo.io/linux-syscall-table/

```
Info: Child (15) said deno-varnish: Unhandled system call 230  # clock_nanosleep
Info: Child (15) said deno-varnish: Unhandled system call 332  # statx
```

## (Resolved) failed to create UnixStream

Avoid calling .enable_all() when building the tokio runtime as that includes .enable_io() which triggers this error.

```
*   << BeReq    >> 3
...
-   VCL_Log        deno-varnish says: Running
-   VCL_Log        deno-varnish says: file:///main.js
-   VCL_Log        deno-varnish says: ...

-   VCL_Log        deno-varnish says:
thread 'main' panicked at /usr/local/cargo/registry/src/index.crates.io-1949cf8c6b5b557f/tokio-1.44.1/src/signal/unix.rs:60:53:
failed to create UnixStream: Os { code: 38, kind: Unsupported, message: "Function not implemented" }

-   VCL_Log        deno-varnish says: note: run with `RUST_BACKTRACE=1` environment variable to display a backtrace
```

### (Resolved) VM 'deno-varnish' exception: Too many relocations

Fixed in varnish/tinykvm#21.

```
*   << BeReq    >> 3
...
-   Error          VM 'deno-varnish' exception: Too many relocations
-   Error          KVM: Unable to reserve VM for index 0, program deno-varnish
...
```

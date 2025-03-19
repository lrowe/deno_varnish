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

## VM 'deno-varnish' exception: Too many relocations

I've been using podman but this should also work under docker.
I installed the static version of podman from https://github.com/mgoltzsche/podman-static on Ubuntu 24.04 and followed the apparmor profile instructions.
And replaced `docker.io` with `mirror.gcr.io` in /etc/containers/registries.conf.

Build 

    podman build -t deno-varnish .

Then run concurrently:

    podman run --rm -p 127.0.0.1:8080:8080 -e VARNISH_HTTP_PORT=8080 --device /dev/kvm --group-add keep-groups --name deno-varnish deno-varnish
    podman exec -it deno-varnish varnishlog
    curl http://localhost:8080/hello

## Error from varnishlog

Failed request:

```
*   << BeReq    >> 3         
-   Begin          bereq 2 pass
-   VCL_use        boot
-   Timestamp      Start: 1742371185.343647 0.000000 0.000000
-   BereqMethod    GET
-   BereqURL       /foo
-   BereqProtocol  HTTP/1.1
-   BereqHeader    Host: localhost:8080
-   BereqHeader    User-Agent: curl/8.5.0
-   BereqHeader    Accept: */*
-   BereqHeader    X-Forwarded-For: 192.168.50.20
-   BereqHeader    Via: 1.1 3ac4cb34604a (Varnish/7.6)
-   BereqHeader    X-Varnish: 3
-   VCL_call       BACKEND_FETCH
-   VCL_return     fetch
-   Timestamp      Fetch: 1742371185.343837 0.000190 0.000190
-   Error          VM 'deno-varnish' exception: Too many relocations
-   Error          KVM: Unable to reserve VM for index 0, program deno-varnish
-   Timestamp      Beresp: 1742371185.593593 0.249946 0.249756
-   Timestamp      Error: 1742371185.593596 0.249949 0.000003
-   BerespProtocol HTTP/1.1
-   BerespStatus   503
-   BerespReason   Backend fetch failed
-   BerespHeader   Date: Wed, 19 Mar 2025 07:59:45 GMT
-   BerespHeader   Server: Varnish
-   VCL_call       BACKEND_ERROR
-   BerespHeader   Content-Type: text/html; charset=utf-8
-   BerespHeader   Retry-After: 5
-   VCL_return     deliver
-   Storage        malloc Transient
-   Length         278
-   BereqAcct      0 0 0 0 0 0
-   End            
```

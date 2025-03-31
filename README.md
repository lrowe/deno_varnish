# Experiment embedding deno_runtime in Varnish TinyKVM.

This is very early in development, it only kinda works and is quite slow (more than likely my fault!)

## Build static binary and validate that it runs on Linux

> [!NOTE]  
> Do not put rustflags in .cargo/config.toml as that causes build error:
> error: cannot produce proc-macro for `asn1-rs-derive v0.4.0` as the target `x86_64-unknown-linux-gnu` does not support these crate types

Uses the static glibc approach from [Building static Rust binaries for Linux](https://msfjarvis.dev/posts/building-static-rust-binaries-for-linux/).
By not using musl we avoid a lengthy v8 build and reuse the published glibc build artifacts from https://github.com/denoland/rusty_v8/releases/.

```
RUSTFLAGS="-C target-feature=+crt-static" cargo build --release --target x86_64-unknown-linux-gnu
ldd ./target/x86_64-unknown-linux-gnu/release/deno-varnish # statically linked
./target/x86_64-unknown-linux-gnu/release/deno-varnish state request ./main.js
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

### Running under gdb

* Use `rust-gdb` wrapper.

* Unsure how to load libc debug symbols when debugging crt-static build.

    - Not sufficent to just install `libc6-dbg`.

## Running inside Varnish TinyKVM

I've been using podman but this should also work under docker.
I installed the static version of podman from https://github.com/mgoltzsche/podman-static on Ubuntu 24.04 and followed the apparmor profile instructions.
And replaced `docker.io` with `mirror.gcr.io` in /etc/containers/registries.conf.

Enable huge pages on host

    echo 2048 | sudo tee /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages

Build 

    podman build -t deno-varnish .

Then run concurrently:

    podman run --rm -p 127.0.0.1:8080:8080 -e VARNISH_HTTP_PORT=8080 --device /dev/kvm --group-add keep-groups --name deno-varnish deno-varnish
    podman exec -it deno-varnish varnishlog
    curl http://localhost:8080/hello

### Connecting with gdb

* Use `rust-gdb` wrapper.

* Configure  with `"allow_debug": true`. Watch the connection timeout along with timeouts from `"max_boot_time"` and `"max_request_time"`.

    > Allow remotely debugging requests with GDB. The request to be debugged has to cause a breakpoint. In the C API this is done with `sys_breakpoint()`. The GDB instance must load the program using `file myprogram` before it can remotely connect using target `remote :2159`.

    [JSON Glossary](https://github.com/varnish/libvmod-tinykvm/blob/main/docs/glossary.md)

    - Does not work in combination with `tinykvm.start` in `vcl_init`.

#### Debugging through JS stackframes

Add `--gdbjit_full` to v8 flags. ``--gdbjit` doesn't really do anything. No need to rebuild.

Slows things down. Can take a minute or so to hit a breakpoint that would otherwise be instantaneous.

## Issues and open questions

### (Resolved) Understand why we are running out of memory in non-ephemeral mode

This is fixed by specifying memory limits for v8 in the environment:
```
"DENO_V8_FLAGS=--max-heap-size=64,--max-old-space-size=64"
```

Even after ensuring the RcHttpRecord is dropped we still run out of memory.

Run with `"ephemeral": false` and repro with:

```
wrk -t 1 -c 1 http://127.0.0.1:8080/deno
```

### Investigate glibc tunables

If we do want hugepages we can configure malloc to use them.

    "GLIBC_TUNABLES=glibc.malloc.hugetlb=2:glibc.malloc.mmap_threshold=2097152"

### Why does updating rust dependencies break things

Causes a check to fail in mutex.cc:75.

Presumably down to v8 update from 134.5.0 to 135.1.0.

### Do we want any of these proc / sys mounts?

Should check where each of these are used. Easiest way seem to be running under gdb with `catch syscall openat`.

None of these seem to be absolutely necessary.

Everything under `/proc` is misleading as it reflects the host process not the current process running within the VM.

```
    "/proc/self/mountinfo",
    "/proc/self/maps",  # Used by rust panic handler setup and v8 setup
    "/proc/self/cgroup",
    "/proc/stat",
```

Most of these under `/sys` seem to be used by a transitive dependency of swc for the ts transform.

```
    "/sys/devices/system/cpu/online",
    "/sys/devices/system/cpu/cpu0/tsc_freq_khz", # probably safe
    "/sys/fs/cgroup/cgroup.controllers",
    "/sys/fs/cgroup/cpu.max",
```

### (Resolved) Debugging rusty_v8 with full debug symbols for v8

See: https://github.com/denoland/rusty_v8/issues/1750

Delete target directory and cargo build with env:

```
V8_FROM_SOURCE=1 PRINT_GN_ARGS=1 GN_ARGS="line_tables_only=false no_inline_line_tables=false symbol_level=2"
```

### (Resolved) Backend VM memory exception: page_at: page directory not present

TinyKVM now lets us specify address_space separately from max_memory.

Seems ok to allocate 70GB of address space to avoid this for now.

Tracked down why here and follow ups: https://github.com/varnish/tinykvm/issues/23#issuecomment-2748807778

* Would gdb `maintenance info sections` let us know what is causing memory to be paged in?

    - Cannot use /proc/self/maps as that reflects the varnish process on the host.

Only triggered after switching to `wait_for_requests_paused` which works in the rust demo.

```
*   << BeReq    >> 3
-   Begin          bereq 2 pass
-   VCL_use        boot
-   Timestamp      Start: 1742507690.861852 0.000000 0.000000
-   BereqMethod    GET
-   BereqURL       /foo
-   BereqProtocol  HTTP/1.1
-   BereqHeader    Host: localhost:8080
-   BereqHeader    User-Agent: curl/8.5.0
-   BereqHeader    Accept: */*
-   BereqHeader    X-Forwarded-For: 192.168.50.20
-   BereqHeader    Via: 1.1 61ebf08ab1c1 (Varnish/7.6)
-   BereqHeader    X-Varnish: 3
-   VCL_call       BACKEND_FETCH
-   VCL_return     fetch
-   Timestamp      Fetch: 1742507690.862047 0.000194 0.000194
-   VCL_Log        deno-varnish says: Running
-   VCL_Log        deno-varnish says: file:///main.js
-   VCL_Log        deno-varnish says: ...

-   VCL_Log        deno-varnish says: Hello from deno_varnish

-   VCL_Log        deno-varnish says: before wait_for_requests_paused

-   Error          Backend VM memory exception: page_at: page directory not present (addr: 0x1000003000, size: 0x40000000)
-   VCL_Log        deno-varnish says: CR0: 0x80040033  CR3: 0x7000000000

-   VCL_Log        deno-varnish says: CR2: 0x0  CR4: 0x350620

-   VCL_Log        deno-varnish says: RAX: 0x0  RBX: 0x0  RCX: 0x0

-   VCL_Log        deno-varnish says: RDX: 0x0  RSI: 0x0  RDI: 0x0

-   VCL_Log        deno-varnish says: RIP: 0x0  RBP: 0x0  RSP: 0x0

-   VCL_Log        deno-varnish says: SS: 0x23  CS: 0x2B  DS: 0x23  FS: 0x0  GS: 0x0

-   VCL_Log        deno-varnish says: FS BASE: 0x65E1040  GS BASE: 0x5030

-   VCL_Log        deno-varnish says: [0] 0x       0

-   VCL_Log        deno-varnish says: CR0: 0x80040033  CR3: 0x7000000000

-   VCL_Log        deno-varnish says: CR2: 0x0  CR4: 0x350620

-   VCL_Log        deno-varnish says: RAX: 0x0  RBX: 0x0  RCX: 0x0

-   VCL_Log        deno-varnish says: RDX: 0x0  RSI: 0x0  RDI: 0x0

-   VCL_Log        deno-varnish says: RIP: 0x0  RBP: 0x0  RSP: 0x0

-   VCL_Log        deno-varnish says: SS: 0x23  CS: 0x2B  DS: 0x23  FS: 0x0  GS: 0x0

-   VCL_Log        deno-varnish says: FS BASE: 0x65E1040  GS BASE: 0x5030

-   VCL_Log        deno-varnish says: [0] 0x       0

-   BerespProtocol HTTP/1.1
-   BerespStatus   500
-   BerespReason   Internal Server Error
-   BerespHeader   Content-Length: 0
-   BerespHeader   Last-Modified: Thu, 20 Mar 2025 21:54:52 GMT
-   Timestamp      Beresp: 1742507692.147852 1.285999 1.285804
-   BerespHeader   Date: Thu, 20 Mar 2025 21:54:52 GMT
-   VCL_call       BACKEND_RESPONSE
-   VCL_return     deliver
-   Timestamp      Process: 1742507692.147862 1.286010 0.000010
-   Filters
-   Storage        malloc Transient
-   Fetch_Body     3 length -
-   Timestamp      BerespBody: 1742507692.147911 1.286059 0.000048
-   Length         0
-   BereqAcct      0 0 0 0 0 0
-   End
```

### (Resolved) Unhandled system calls

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

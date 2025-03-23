vcl 4.1;
import tinykvm;

backend default none;

sub vcl_init {
    # Tell TinyKVM how to contact Varnish (Unix Socket *ONLY*).
    tinykvm.init_self_requests("/tmp/tinykvm.sock");

    tinykvm.configure("deno-varnish",
        """{
            "filename": "/deno-varnish",
            "verbose": true,
            "max_memory": 70000,
            "environment": [
                "RUST_BACKTRACE=full",
                "DENO_V8_FLAGS=--jitless,--single-threaded,--single-threaded-gc",
                "SCRIPT=/main.js"
            ],
            "allowed_paths": [
                "/proc/self/mountinfo",
                "/proc/self/maps",
                "/proc/self/cgroup",
                "/proc/stat",
                "/sys/devices/system/cpu/online",
                "/sys/devices/system/cpu/cpu0/tsc_freq_khz",
                "/sys/fs/cgroup/cgroup.controllers",
                "/sys/fs/cgroup/cpu.max",
                "/dev/urandom",
                "/main.js"
            ]
        }""");
       tinykvm.start("deno-varnish");
}

sub vcl_recv {
    return(pass);
}

sub vcl_backend_fetch {
    set bereq.backend = tinykvm.program("deno-varnish", bereq.url);
}

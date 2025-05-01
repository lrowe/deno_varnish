vcl 4.1;
import tinykvm;
import std;

backend default none;

sub vcl_init {
    # Tell TinyKVM how to contact Varnish (Unix Socket *ONLY*).
    tinykvm.init_self_requests("/tmp/tinykvm.sock");

    tinykvm.configure("hello.ext.js",
        """{
            "filename": "/deno-varnish",
            "executable_heap": true,
            "address_space": 66000,
            "max_memory": 3000,
            "hugepage_arena_size": 64,
            "request_hugepage_arena_size": 32,
            "ephemeral": true,
            "environment": ["DENO_V8_FLAGS=--max-old-space-size=64,--max-semi-space-size=64"],
            "main_arguments": ["/mnt/hello.ext.js"],
            "warmup": { "num_requests": 100 },
            "allowed_paths": [
                "/lib/x86_64-linux-gnu/libz.so.1",
                "/lib/x86_64-linux-gnu/libgcc_s.so.1",
                "/lib/x86_64-linux-gnu/libm.so.6",
                "/lib/x86_64-linux-gnu/libc.so.6",
                "/lib64/ld-linux-x86-64.so.2",
                "/dev/urandom",
                "/mnt/hello.ext.js"
            ]
        }""");
    tinykvm.start("hello.ext.js");

    tinykvm.configure("renderer.ext.js",
        """{
            "filename": "/deno-varnish",
            "executable_heap": true,
            "address_space": 66000,
            "max_memory": 3200,
            "hugepage_arena_size": 64,
            "request_hugepage_arena_size": 32,
            "ephemeral": true,
            "environment": ["DENO_V8_FLAGS=--max-old-space-size=64,--max-semi-space-size=64"],
            "main_arguments": ["/mnt/renderer.ext.js"],
            "warmup": { "num_requests": 100 },
            "allowed_paths": [
                "/lib/x86_64-linux-gnu/libz.so.1",
                "/lib/x86_64-linux-gnu/libgcc_s.so.1",
                "/lib/x86_64-linux-gnu/libm.so.6",
                "/lib/x86_64-linux-gnu/libc.so.6",
                "/lib64/ld-linux-x86-64.so.2",
                "/dev/urandom",
                "/mnt/renderer.ext.js"
            ]
        }""");
    tinykvm.start("renderer.ext.js");

    tinykvm.configure("output.ext.js",
        """{
            "filename": "/deno-varnish",
            "current_working_directory": "/mnt",
            "executable_heap": true,
            "address_space": 66000,
            "max_memory": 3000,
            "hugepage_arena_size": 64,
            "request_hugepage_arena_size": 32,
            "ephemeral": true,
            "environment": ["DENO_V8_FLAGS=--max-old-space-size=64,--max-semi-space-size=64"],
            "main_arguments": ["/mnt/output.ext.js"],
            "warmup": { "num_requests": 100 },
            "allowed_paths": [
                "/lib/x86_64-linux-gnu/libz.so.1",
                "/lib/x86_64-linux-gnu/libgcc_s.so.1",
                "/lib/x86_64-linux-gnu/libm.so.6",
                "/lib/x86_64-linux-gnu/libc.so.6",
                "/lib64/ld-linux-x86-64.so.2",
                "/dev/urandom",
                "/output.html",
                "/mnt/output.html",
                "/mnt/output.ext.js"
            ]
        }""");
    tinykvm.start("output.ext.js");

    tinykvm.configure("blockon",
        """{
            "filename": "/blockon",
            "ephemeral": true,
            "executable_heap": true,
            "allowed_paths": [
                "/lib/x86_64-linux-gnu/libgcc_s.so.1",
                "/lib/x86_64-linux-gnu/libc.so.6",
                "/lib64/ld-linux-x86-64.so.2"
            ]
        }""");
    tinykvm.start("blockon");

    tinykvm.configure("onget",
        """{
            "filename": "/onget",
            "ephemeral": true,
            "executable_heap": true,
            "allowed_paths": [
                "/lib/x86_64-linux-gnu/libgcc_s.so.1",
                "/lib/x86_64-linux-gnu/libc.so.6",
                "/lib64/ld-linux-x86-64.so.2"
            ]
        }""");
    tinykvm.start("onget");

    tinykvm.configure("output.rs",
        """{
            "filename": "/output",
            "ephemeral": true,
            "executable_heap": true,
            "allowed_paths": [
                "/lib/x86_64-linux-gnu/libgcc_s.so.1",
                "/lib/x86_64-linux-gnu/libc.so.6",
                "/lib64/ld-linux-x86-64.so.2"
            ]
        }""");
    tinykvm.start("output.rs");

    return (ok);
}

sub vcl_recv {
    if (req.url == "/synth") {
        return (synth(701));
    } else if (req.url == "/output.synth") {
        return (synth(702));
    } else {
        return (pass);
    }
}

sub vcl_synth {
    if (resp.status == 701) {
        set resp.body = "Hello, World!";
        set resp.status = 200;
    } else if (resp.status == 702) {
        set resp.body = std.fileread("/mnt/output.html");
        set resp.status = 200;
    }
    return (deliver);
}

sub vcl_backend_fetch {
    set bereq.backend = tinykvm.program(regsub(bereq.url, "/", ""), bereq.url);
    return (fetch);
}

sub vcl_backend_response {
    set beresp.uncacheable = true;
}

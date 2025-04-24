vcl 4.1;
import tinykvm;
import std;

backend default none;

sub vcl_init {
    # Tell TinyKVM how to contact Varnish (Unix Socket *ONLY*).
    tinykvm.init_self_requests("/tmp/tinykvm.sock");

    tinykvm.configure("main.js",
        """{
            "filename": "/deno-varnish",
            "executable_heap": true,
            "address_space": 66000,
            "max_memory": 2800,
            "req_mem_limit_after_reset": 2000,
            "hugepage_arena_size": 64,
            "request_hugepage_arena_size": 32,
            "ephemeral": true,
            "ephemeral_keep_working_memory": true,
            "environment": ["DENO_V8_FLAGS=--max-old-space-size=64,--max-semi-space-size=64"],
            "main_arguments": ["/main.js"],
            "allowed_paths": [
                "/lib/x86_64-linux-gnu/libz.so.1",
                "/lib/x86_64-linux-gnu/libgcc_s.so.1",
                "/lib/x86_64-linux-gnu/libm.so.6",
                "/lib/x86_64-linux-gnu/libc.so.6",
                "/lib64/ld-linux-x86-64.so.2",
                "/dev/urandom",
                "/main.js"
            ]
        }""");
    tinykvm.start("main.js");

    tinykvm.configure("renderer.js",
        """{
            "filename": "/deno-varnish",
            "executable_heap": true,
            "address_space": 66000,
            "max_memory": 2800,
            "req_mem_limit_after_reset": 2000,
            "hugepage_arena_size": 64,
            "request_hugepage_arena_size": 32,
            "ephemeral": true,
            "ephemeral_keep_working_memory": true,
            "environment": ["DENO_V8_FLAGS=--max-old-space-size=64,--max-semi-space-size=64"],
            "main_arguments": ["/renderer.js"],
            "allowed_paths": [
                "/lib/x86_64-linux-gnu/libz.so.1",
                "/lib/x86_64-linux-gnu/libgcc_s.so.1",
                "/lib/x86_64-linux-gnu/libm.so.6",
                "/lib/x86_64-linux-gnu/libc.so.6",
                "/lib64/ld-linux-x86-64.so.2",
                "/dev/urandom",
                "/renderer.js"
            ]
        }""");
    tinykvm.start("renderer.js");

    tinykvm.configure("output.js",
        """{
            "filename": "/deno-varnish",
            "executable_heap": true,
            "address_space": 66000,
            "max_memory": 2800,
            "req_mem_limit_after_reset": 2000,
            "hugepage_arena_size": 64,
            "request_hugepage_arena_size": 32,
            "ephemeral": true,
            "ephemeral_keep_working_memory": true,
            "environment": ["DENO_V8_FLAGS=--max-old-space-size=64,--max-semi-space-size=64"],
            "main_arguments": ["/output.js"],
            "allowed_paths": [
                "/lib/x86_64-linux-gnu/libz.so.1",
                "/lib/x86_64-linux-gnu/libgcc_s.so.1",
                "/lib/x86_64-linux-gnu/libm.so.6",
                "/lib/x86_64-linux-gnu/libc.so.6",
                "/lib64/ld-linux-x86-64.so.2",
                "/dev/urandom",
                "/output.html",
                "/output.js"
            ]
        }""");
    tinykvm.start("output.js");

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
        set resp.body = std.fileread("/output.html");
        set resp.status = 200;
    }
    return (deliver);
}

sub vcl_backend_fetch {
    if (bereq.url == "/blockon") {
        set bereq.backend = tinykvm.program("blockon", bereq.url);
    } else if (bereq.url == "/onget") {
        set bereq.backend = tinykvm.program("onget", bereq.url);
    } else if (bereq.url == "/output.rs") {
        set bereq.backend = tinykvm.program("output.rs", bereq.url);
    } else if (bereq.url == "/output.js") {
        set bereq.backend = tinykvm.program("output.js", bereq.url);
    } else if (bereq.url == "/renderer.js") {
        set bereq.backend = tinykvm.program("renderer.js", bereq.url);
    } else {
        set bereq.backend = tinykvm.program("main.js", bereq.url);
    }
    return (fetch);
}

sub vcl_backend_response {
    set beresp.uncacheable = true;
}

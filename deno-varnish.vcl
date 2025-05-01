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
            "/mnt",
            "/mnt/output.html",
            "/mnt/output.ext.js"
        ]
    }""");
tinykvm.start("output.ext.js");

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

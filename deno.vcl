tinykvm.configure("hello.ffi.ts",
    """{
        "filename": "/usr/local/bin/deno",
        "executable_heap": true,
        "address_space": 66000,
        "max_memory": 3000,
        "hugepage_arena_size": 64,
        "request_hugepage_arena_size": 32,
        "ephemeral": true,
        "environment": [
            "RUST_BACKTRACE=1",
            "DENO_DIR=/nonexistent",
            "VARNISH_TINYKVM_API_PATH=/mnt/libkvm_api.so",
            "DENO_V8_FLAGS=--single-threaded,--max-old-space-size=64,--max-semi-space-size=64"
        ],
        "main_arguments": ["run","--allow-all", "/mnt/hello.ffi.ts"],
        "warmup": { "num_requests": 100 },
        "allowed_paths": [
            "/lib/x86_64-linux-gnu/libdl.so.2",
            "/lib/x86_64-linux-gnu/libgcc_s.so.1",
            "/lib/x86_64-linux-gnu/librt.so.1",
            "/lib/x86_64-linux-gnu/libpthread.so.0",
            "/lib/x86_64-linux-gnu/libm.so.6",
            "/lib/x86_64-linux-gnu/libc.so.6",
            "/lib64/ld-linux-x86-64.so.2",
            "/dev/urandom",
            "/",
            "/mnt/libkvm_api.so",
            "/mnt/varnish.ts",
            "/mnt/hello.ffi.ts"
        ]
    }""");
tinykvm.start("hello.ffi.ts");

tinykvm.configure("output.ffi.ts",
    """{
        "filename": "/usr/local/bin/deno",
        "current_working_directory": "/mnt",
        "executable_heap": true,
        "address_space": 66000,
        "max_memory": 3000,
        "hugepage_arena_size": 64,
        "request_hugepage_arena_size": 32,
        "ephemeral": true,
        "environment": [
            "RUST_BACKTRACE=1",
            "DENO_DIR=/nonexistent",
            "VARNISH_TINYKVM_API_PATH=/mnt/libkvm_api.so",
            "DENO_V8_FLAGS=--single-threaded,--max-old-space-size=64,--max-semi-space-size=64"
        ],
        "main_arguments": ["run","--allow-all", "/mnt/output.ffi.ts"],
        "warmup": { "num_requests": 100 },
        "allowed_paths": [
            "/lib/x86_64-linux-gnu/libdl.so.2",
            "/lib/x86_64-linux-gnu/libgcc_s.so.1",
            "/lib/x86_64-linux-gnu/librt.so.1",
            "/lib/x86_64-linux-gnu/libpthread.so.0",
            "/lib/x86_64-linux-gnu/libm.so.6",
            "/lib/x86_64-linux-gnu/libc.so.6",
            "/lib64/ld-linux-x86-64.so.2",
            "/dev/urandom",
            "/",
            "/mnt/libkvm_api.so",
            "/mnt/varnish.ts",
            "/mnt/output.ffi.ts",
            "/mnt/output.html"
        ]
    }""");
tinykvm.start("output.ffi.ts");

tinykvm.configure("renderer.ffi.ts",
    """{
        "filename": "/usr/local/bin/deno",
        "executable_heap": true,
        "address_space": 66000,
        "max_memory": 3000,
        "hugepage_arena_size": 64,
        "request_hugepage_arena_size": 32,
        "ephemeral": true,
        "environment": [
            "RUST_BACKTRACE=1",
            "DENO_DIR=/nonexistent",
            "VARNISH_TINYKVM_API_PATH=/mnt/libkvm_api.so",
            "DENO_V8_FLAGS=--single-threaded,--max-old-space-size=64,--max-semi-space-size=64"
        ],
        "main_arguments": ["run","--allow-all", "/mnt/renderer.ffi.ts"],
        "warmup": { "num_requests": 100 },
        "allowed_paths": [
            "/lib/x86_64-linux-gnu/libdl.so.2",
            "/lib/x86_64-linux-gnu/libgcc_s.so.1",
            "/lib/x86_64-linux-gnu/librt.so.1",
            "/lib/x86_64-linux-gnu/libpthread.so.0",
            "/lib/x86_64-linux-gnu/libm.so.6",
            "/lib/x86_64-linux-gnu/libc.so.6",
            "/lib64/ld-linux-x86-64.so.2",
            "/dev/urandom",
            "/",
            "/mnt/libkvm_api.so",
            "/mnt/varnish.ts",
            "/mnt/renderer.ffi.ts",
            "/mnt/renderer.ext.js"
        ]
    }""");
tinykvm.start("renderer.ffi.ts");

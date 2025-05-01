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

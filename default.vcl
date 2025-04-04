vcl 4.1;
import tinykvm;

backend default none;

sub vcl_init {
    # Tell TinyKVM how to contact Varnish (Unix Socket *ONLY*).
    tinykvm.init_self_requests("/tmp/tinykvm.sock");

    tinykvm.configure("deno-varnish",
        """{
            "filename": "/deno-varnish",
            "executable_heap": true,
            "address_space": 66000,
            "max_memory": 3600,
            "environment": [
                "DENO_V8_FLAGS=--max-heap-size=64,--max-old-space-size=64"
            ],
            "req_mem_limit_after_reset": 2000,
            "main_arguments": ["/main.js"],
            "allowed_paths": [
                "/dev/urandom",
                "/main.js"
            ]
        }""");
    tinykvm.start("deno-varnish");

    tinykvm.configure("blockon",
        """{
            "filename": "/blockon"
        }""");
    tinykvm.start("blockon");

    tinykvm.configure("onget",
        """{
            "filename": "/onget"
        }""");
    tinykvm.start("onget");
    return (ok);
}

sub vcl_recv {
    if (req.url == "/synth") {
        return (synth(200));
    } else {
        return (pass);
    }
}

sub vcl_synth {
    set resp.body = "Hello, World!";
    return (deliver);
}

sub vcl_backend_fetch {
    if (bereq.url == "/blockon") {
        set bereq.backend = tinykvm.program("blockon", bereq.url);
    } else if (bereq.url == "/onget") {
        set bereq.backend = tinykvm.program("onget", bereq.url);
    } else {
        set bereq.backend = tinykvm.program("deno-varnish", bereq.url);
    }
    return (fetch);
}

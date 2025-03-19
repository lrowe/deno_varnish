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
            "environment": [
                "DENO_V8_FLAGS=--jitless,--single-threaded,--single-threaded-gc",
                "SCRIPT=/main.js"
            ],
            "allowed_paths": [
                "/main.js"
            ]
        }""");
}

sub vcl_recv {
    return(pass);
}

sub vcl_backend_fetch {
    set bereq.backend = tinykvm.program("deno-varnish", bereq.url);
}

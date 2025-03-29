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
            "verbose": true,
            "max_memory": 70000,
            "main_arguments": ["/main.js"],
            "environment": [
                "RUST_BACKTRACE=full"
            ],
            "allowed_paths": [
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

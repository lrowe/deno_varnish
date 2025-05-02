vcl 4.1;
import tinykvm;
import std;

backend default none;

sub vcl_init {
    # Tell TinyKVM how to contact Varnish (Unix Socket *ONLY*).
    tinykvm.init_self_requests("/tmp/tinykvm.sock");

    tinykvm.library("file:///mnt/deno-compile.compute.json");
    tinykvm.library("file:///mnt/deno-run.compute.json");
    tinykvm.library("file:///mnt/deno-varnish.compute.json");
    tinykvm.library("file:///mnt/rust.compute.json");

    return (ok);
}

sub vcl_recv {
    if (req.url == "/hello.synth") {
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

use deno_varnish::varnish;

fn on_get(_url: &str, _arg: &str) {
    varnish::backend_response_str(200, "text/plain", "Hello, World!");
}

fn main() {
    varnish::set_backend_get(on_get);
    varnish::wait_for_requests();
}

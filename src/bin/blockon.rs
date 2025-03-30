use deno_varnish::varnish;

fn main() {
    loop {
        let _request = varnish::wait_for_requests_paused();
        varnish::backend_response_str(200, "text/plain", "Hello, World!");
    }
}

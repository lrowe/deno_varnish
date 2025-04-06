use deno_varnish::varnish;

const DATA: &[u8] = include_bytes!("../../output.html");

fn main() {
    loop {
        let _request = varnish::wait_for_requests_paused();
        varnish::backend_response(200, "text/html", DATA);
    }
}

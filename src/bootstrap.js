// Copyright 2018-2025 the Deno authors. MIT license.
import {
  op_varnish_backend_response,
  op_varnish_wait_for_requests_paused,
  op_varnish_request_url,
} from "ext:core/ops";

// TODO: (Request) -> Response like Deno.serve
const serve = async (opts_, handler_) => {
  const handler = typeof handler_ === 'function' ? handler_ : typeof opts_ === 'function' ? opts_ : opts_?.handler;
  const opts = typeof opts_ === 'object' ? opts_ : null;
  let warmups = opts?.warmups ?? 0;
  while (true) {
    const external = op_varnish_wait_for_requests_paused(warmups && warmups--);
    const url = op_varnish_request_url(external);
    const request = new Request(new URL(url, "http://localhost:8080"));
    const response = await handler(request);
    const content_type = response.headers.get("Content-Type") ?? "application/octet-stream";
    const body = await response.arrayBuffer();
    op_varnish_backend_response(external, response.status, content_type, body);
  }
};

globalThis.varnish = {
  serve,
}

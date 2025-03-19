// Copyright 2018-2025 the Deno authors. MIT license.
import { op_varnish_backend_response_str } from "ext:core/ops";
globalThis.varnish = {
  backend_response: (status, ctype, data) => {
    op_varnish_backend_response_str(status, ctype, data);
  }
}
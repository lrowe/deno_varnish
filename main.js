const body = "Hello, World!";

const handler = () => {
  return new Response(body);
};

(globalThis.varnish?.serve ?? Deno.serve)({ warmups: 100 }, handler);

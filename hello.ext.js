const body = "Hello, World!";
const handler = () => new Response(body);
(globalThis.varnish?.serve ?? Deno.serve)(handler);

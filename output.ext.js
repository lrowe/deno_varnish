const body = Deno.readTextFileSync("output.html");
const handler = () => new Response(body);
(globalThis.varnish?.serve ?? Deno.serve)(handler);

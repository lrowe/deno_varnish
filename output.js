const body = Deno.readTextFileSync("output.html");

const handler = () => {
  return new Response(body);
};

(globalThis.varnish?.serve ?? Deno.serve)({ warmups: 100 }, handler);

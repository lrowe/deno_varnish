const body = Deno.readTextFileSync("output.html");

const handler = () => {
  return new Response(body);
};

// Pre-warm
for (let i = 0; i < 50; i++) {
  console.time("handler");
  handler();
  console.timeEnd("handler");
}

(globalThis.varnish?.serve ?? Deno.serve)(handler);

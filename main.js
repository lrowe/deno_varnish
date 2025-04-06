console.log("Hello from deno_varnish");

const handler = () => {
  return new Response("Hello, World!");
};

// Pre-warm
for (let i = 0; i < 50; i++) {
  console.time("handler");
  handler();
  console.timeEnd("handler");
}

(globalThis.varnish?.serve ?? Deno.serve)(handler);

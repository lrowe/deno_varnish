console.log("Hello from deno_varnish");

const handler = (request) => {
  return new Response(`Hello from JS ${request.url}`);
};

varnish.serve(handler);

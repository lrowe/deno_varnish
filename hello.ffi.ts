import { serve } from "./varnish.ts";
const body = "Hello, World!";

const handler = () => {
  return new Response(body);
};

serve(handler);

import { serve } from "./varnish.ts";
// Only works when specifying absolute path
const body = Deno.readTextFileSync("/mnt/output.html");
const handler = () => new Response(body);
serve(handler);

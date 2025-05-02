import { serve } from "./varnish.ts";
// Only works when specifying absolute path (tinykvm bug)
const body = Deno.readTextFileSync(`${Deno.cwd()}/output.html`);
const handler = () => new Response(body);
serve(handler);

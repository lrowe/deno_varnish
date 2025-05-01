import { serve } from "./varnish.ts";
import handler from "./renderer.ext.js";
serve(handler);

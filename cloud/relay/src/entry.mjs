// Cloudflare imports the .wasm file as a compiled WebAssembly.Module.
import module from "./relay_bg.wasm";
import { fetch, initSync, Relay } from "./relay.js";

initSync({ module });

export { Relay };
export default { fetch };

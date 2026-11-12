// Released under Apache 2.0 license as described in the file LICENSE.
// Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
//
// Registers `ts-hook.mjs` so that Node can import KaTeX's TypeScript sources. Loaded with
// `node --experimental-strip-types --import ./tools/ts-register.mjs …`; it has no functions.

import {register} from "node:module";

register("./ts-hook.mjs", import.meta.url);

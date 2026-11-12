// Released under Apache 2.0 license as described in the file LICENSE.
// Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
//
// A Node module-resolution hook that lets Node (22.6 or later, with --experimental-strip-types)
// load KaTeX's TypeScript sources directly: relative imports without an extension resolve to the
// `.ts` or `.js` file next to them, and the test-only packages KaTeX's spec helpers import
// (jest-diff, jest-matcher-utils, jest-message-util) resolve to an empty stub. Used by
// `gen-tables.mjs` and `harvest-spec.mjs`; registered through `ts-register.mjs`.

import {existsSync, statSync} from "node:fs";
import {fileURLToPath} from "node:url";

// Packages that KaTeX's test helpers import but whose behaviour the harvest never needs.
const STUBBED = new Set(["jest-diff", "jest-matcher-utils", "jest-message-util"]);

// The URL of the stub module that stands in for every stubbed package.
const STUB_URL = "data:text/javascript," + encodeURIComponent(
    "export const diff = () => ''; export const RECEIVED_COLOR = (s) => s;" +
    "export const printReceived = (s) => String(s); export const printExpected = (s) => String(s);" +
    "export const formatStackTrace = (s) => s;" +
    "export const separateMessageFromStack = (s) => ({message: String(s), stack: ''});");

// Whether `p` names an existing regular file.
function isFile(p) {
    return existsSync(p) && statSync(p).isFile();
}

// Node's resolve hook: extensionless relative imports get `.ts`/`.js`/`/index.ts`; stubbed
// packages get the stub; everything else goes to Node's own resolver.
export async function resolve(specifier, context, next) {
    if (STUBBED.has(specifier)) {
        return {url: STUB_URL, shortCircuit: true};
    }
    if ((specifier.startsWith("./") || specifier.startsWith("../")) && context.parentURL) {
        const url = new URL(specifier, context.parentURL);
        const path = fileURLToPath(url);
        for (const ext of ["", ".ts", ".js", "/index.ts"]) {
            if (isFile(path + ext)) {
                return next(url.href + ext, context);
            }
        }
    }
    return next(specifier, context);
}

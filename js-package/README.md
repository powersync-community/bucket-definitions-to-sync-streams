This exposes the [Sync Config rewriter](github.com/powersync-community/bucket-definitions-to-sync-streams)
as a package usable from JavaScript.

## Instantiation

This package requires you to load a compiled WebAssembly file, which depends on your target platform.

On Node.JS, resolve and load the WASM file:

```TypeScript
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";

import { instantiate } from "@powersync-community/sync-config-rewriter";

const wasmBuffer = readFileSync(
  fileURLToPath(
    import.meta
      .resolve("@powersync-community/sync-config-rewriter/compiled.wasm"),
  ),
);

const module = await instantiate(wasmBuffer);
```

For web apps bundled with vite, use [explicit URL imports](https://vite.dev/guide/assets#explicit-url-imports):

```TypeScript
import { instantiate } from "@powersync-community/sync-config-rewriter";
import wasmUrl from "@powersync-community/sync-config-rewriter/compiled.wasm?url";

const module = await instantiate(fetch(wasmUrl));
```

## Development

To release a version of this package, update the `version` entry in
`package.json`, merge to `main` and manually trigger the `publish_npm`
workflow.

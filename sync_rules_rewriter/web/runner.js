import * as fs from "node:fs";
import * as dart2wasm from "./main.mjs";

const source = `
# TODO: Paste your sync rules here, they will get translated to sync streams as you type.
bucket_definitions:
  user_lists: # name for the bucket
    # Parameter Query, selecting a user_id parameter:
    parameters: SELECT request.user_id() as user_id 
    data: # Data Query, selecting data, filtering using the user_id parameter:
      - SELECT * FROM lists WHERE owner_id = bucket.user_id 
`;

const wasmBuffer = fs.readFileSync("web/main.wasm");
const app = await dart2wasm.compile(wasmBuffer);
const instantiated = await app.instantiate();

const syncRulesToSyncStream /*: (x: string) => {success: boolean, result: string} */ =
  instantiated.instantiatedModule.exports.syncRulesToSyncStream;

const { success, result } = syncRulesToSyncStream(source);
if (success) {
  console.log(result);
} else {
  console.error(result);
}

import { compile, compileStreaming } from "./compiled.mjs";

export async function instantiate(source) {
  let compiled;
  if (ArrayBuffer.isView(source) || source instanceof ArrayBuffer) {
    compiled = await compile(source);
  } else {
    compiled = await compileStreaming(source);
  }

  const instantiated = await compiled.instantiate();
  instantiated.invokeMain();
  const exports = instantiated.instantiatedModule.exports;
  return {
    syncRulesToSyncStreams: exports.syncRulesToSyncStreams,
  };
}

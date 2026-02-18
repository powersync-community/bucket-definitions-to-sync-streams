// Compile with dart compile wasm -E --enable-experimental-wasm-interop web/main.dart

import 'dart:js_interop';
// ignore: import_internal_library
import 'dart:_wasm';

import 'package:sync_rules_rewriter/sync_rules_rewriter.dart';

void main() {}

@pragma('wasm:export', 'syncRulesToSyncStream')
WasmExternRef? convert(WasmExternRef arg) {
  final input = (arg.toJS as JSString).toDart;

  final emitted = syncRulesToSyncStreams(input);
  return externRefForJSAny(emitted.toJS);
}

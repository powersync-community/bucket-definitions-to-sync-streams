// Compile with dart compile wasm -E --enable-experimental-wasm-interop web/main.dart

import 'dart:js_interop';
// ignore: import_internal_library
import 'dart:_wasm';

import 'package:sync_rules_rewriter/sync_rules_rewriter.dart';

void main() {}

extension type ConversionResult._(JSObject _) implements JSObject {
  external factory ConversionResult({
    required String result,
    required bool success,
  });
}

@pragma('wasm:export', 'syncRulesToSyncStream')
WasmExternRef? convert(WasmExternRef arg) {
  final input = (arg.toJS as JSString).toDart;
  ConversionResult result;

  try {
    result = ConversionResult(
      result: syncRulesToSyncStreams(input),
      success: true,
    );
  } catch (e) {
    result = ConversionResult(result: e.toString(), success: false);
  }

  return externRefForJSAny(result);
}

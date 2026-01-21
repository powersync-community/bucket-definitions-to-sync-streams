import 'dart:io';

import 'package:sync_rules_rewriter/sync_rules_rewriter.dart';

/// Usage: `dart run bin/rewrite.dart < /path/to/sync/rules.yaml`.
void main() async {
  final input = StringBuffer();
  await stdin.transform(systemEncoding.decoder).forEach(input.write);

  print(syncRulesToSyncStreams(input.toString()));
}

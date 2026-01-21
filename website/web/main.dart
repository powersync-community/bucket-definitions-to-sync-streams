import 'package:jaspr/client.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr_riverpod/jaspr_riverpod.dart';
import 'package:riverpod/legacy.dart';
import 'package:sync_rules_rewriter/sync_rules_rewriter.dart';

void main() {
  runApp(const ProviderScope(child: _App()), attachTo: '#app');
}

final class _App extends StatelessComponent {
  const _App();

  @override
  Component build(BuildContext context) {
    final (valid, output) = context.watch(_output);
    return div([
      textarea(
        [.text(context.watch(_input))],
        autofocus: true,
        autoComplete: .off,
        rows: 15,
        attributes: {'aria-invalid': (!valid).toString()},
        onInput: (contents) {
          context.read(_input.notifier).state = contents;
        },
      ),
      pre([
        code([.text(output)]),
      ]),
    ]);
  }
}

final _input = StateProvider(
  (ref) => '''
# TODO: Paste your sync rules here, they will get translated to sync streams as you type.
bucket_definitions:
  user_lists: # name for the bucket
    # Parameter Query, selecting a user_id parameter:
    parameters: SELECT request.user_id() as user_id 
    data: # Data Query, selecting data, filtering using the user_id parameter:
      - SELECT * FROM lists WHERE owner_id = bucket.user_id 
''',
);

final _output = Provider((ref) {
  final input = ref.watch(_input);
  try {
    return (true, syncRulesToSyncStreams(input));
  } catch (e) {
    return (false, 'Error: $e');
  }
});

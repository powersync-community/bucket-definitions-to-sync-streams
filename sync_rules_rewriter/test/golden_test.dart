import 'package:sync_rules_rewriter/sync_rules_rewriter.dart';
import 'package:test/test.dart';

void main() {
  test('simple', () {
    expect(
      syncRulesToSyncStreams('''
bucket_definitions:
  user_lists:
    parameters: SELECT request.user_id() as user_id
    data:
      - SELECT * FROM lists WHERE lists.owner_id = bucket.user_id
'''),
      '''
config:
  edition: 3
streams:
  migrated_to_streams:
    auto_subscribe: true
    queries:
      - SELECT * FROM lists WHERE lists.owner_id = auth.user_id()
''',
    );
  });

  test('existing config', () {
    expect(
      syncRulesToSyncStreams('''
bucket_definitions:
  a:
    data:
      - SELECT * FROM users

config:
  # preserved comment
  edition: 1
'''),
      '''
config:
  # preserved comment
  edition: 3
streams:
  migrated_to_streams:
    auto_subscribe: true
    queries:
      - SELECT * FROM users
''',
    );
  });

  test('existing stream', () {
    expect(
      syncRulesToSyncStreams('''
config:
  edition: 2
bucket_definitions:
  a:
    data: SELECT * FROM a
streams:
  b:
    query: SELECT * FROM b
'''),
      '''
config:
  edition: 3
streams:
  b:
    query: SELECT * FROM b
  migrated_to_streams:
    auto_subscribe: true
    queries:
      - SELECT * FROM a
''',
    );
  });

  test('priorities from yaml', () {
    expect(
      syncRulesToSyncStreams('''
bucket_definitions:
  a:
    priority: 2
    data: SELECT * FROM a
  b:
    data: SELECT * FROM b
'''),
      '''
config:
  edition: 3
streams:
  migrated_to_streams_prio_2:
    priority: 2
    auto_subscribe: true
    queries:
      - SELECT * FROM a
  migrated_to_streams_prio_3:
    auto_subscribe: true
    queries:
      - SELECT * FROM b
''',
    );
  });

  test('priority from sql', () {
    expect(
      syncRulesToSyncStreams('''
bucket_definitions:
  a:
    parameters: SELECT 1 AS _priority, request.user_id() as user;
    data: SELECT * FROM a WHERE owner = bucket.user
'''),
      '''
config:
  edition: 3
streams:
  migrated_to_streams:
    priority: 1
    auto_subscribe: true
    queries:
      - SELECT * FROM a WHERE owner = auth.user_id()
''',
    );
  });

  test('multiple parameter queries', () {
    expect(
      syncRulesToSyncStreams('''
bucket_definitions:
  user_lists:
    parameters:
      - SELECT id as list_id FROM lists WHERE owner_id = request.user_id()
      - SELECT list_id FROM user_lists WHERE user_lists.user_id = request.user_id()
    data:
      - SELECT * FROM lists WHERE lists.id = bucket.list_id
      - SELECT * FROM todos WHERE todos.list_id = bucket.list_id
'''),
      '''
config:
  edition: 3
streams:
  migrated_to_streams:
    auto_subscribe: true
    with:
      user_lists_param0: SELECT id AS list_id FROM lists WHERE owner_id = auth.user_id()
      user_lists_param1: SELECT list_id FROM user_lists WHERE user_lists.user_id = auth.user_id()
    queries:
      - "SELECT lists.* FROM lists,user_lists_param0,user_lists_param1 WHERE lists.id = user_lists_param0.list_id OR lists.id = user_lists_param1.list_id"
      - "SELECT todos.* FROM todos,user_lists_param0,user_lists_param1 WHERE todos.list_id = user_lists_param0.list_id OR todos.list_id = user_lists_param1.list_id"
''',
    );
  });

  test('yaml string syntax', () {
    expect(
      syncRulesToSyncStreams('''
bucket_definitions:
  owned_lists:
    parameters: |
        SELECT id as list_id FROM lists WHERE
           owner_id = request.user_id()
    data:
      - SELECT * FROM lists WHERE lists.id = bucket.list_id
      - SELECT * FROM todos WHERE todos.list_id = bucket.list_id
'''),
      '''
config:
  edition: 3
streams:
  migrated_to_streams:
    auto_subscribe: true
    with:
      owned_lists_param: SELECT id AS list_id FROM lists WHERE owner_id = auth.user_id()
    queries:
      - "SELECT lists.* FROM lists,owned_lists_param WHERE lists.id = owned_lists_param.list_id"
      - "SELECT todos.* FROM todos,owned_lists_param WHERE todos.list_id = owned_lists_param.list_id"
''',
    );
  });
}

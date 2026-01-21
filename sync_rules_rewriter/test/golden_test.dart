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
  edition: 2
streams:
  user_lists:
    auto_subscribe: true
    query: SELECT * FROM lists WHERE lists.owner_id = auth.user_id()
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
  edition: 2
streams:
  a:
    auto_subscribe: true
    query: SELECT * FROM users
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
  edition: 2
streams:
  a:
    auto_subscribe: true
    query: SELECT * FROM a
  b:
    query: SELECT * FROM b
''',
    );
  });

  test('priority from yaml', () {
    expect(
      syncRulesToSyncStreams('''
bucket_definitions:
  a:
    priority: 2
    data: SELECT * FROM a
'''),
      '''
config:
  edition: 2
streams:
  a:
    priority: 2
    auto_subscribe: true
    query: SELECT * FROM a
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
  edition: 2
streams:
  a:
    priority: 1
    auto_subscribe: true
    query: SELECT * FROM a WHERE owner = auth.user_id()
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
  edition: 2
streams:
  user_lists:
    auto_subscribe: true
    with:
      bucket0: SELECT id AS list_id FROM lists WHERE owner_id = auth.user_id()
      bucket1: SELECT list_id FROM user_lists WHERE user_lists.user_id = auth.user_id()
    data:
      - "SELECT lists.* FROM lists,bucket0,bucket1 WHERE lists.id = bucket0.list_id OR lists.id = bucket1.list_id"
      - "SELECT todos.* FROM todos,bucket0,bucket1 WHERE todos.list_id = bucket0.list_id OR todos.list_id = bucket1.list_id"
''',
    );
  });
}

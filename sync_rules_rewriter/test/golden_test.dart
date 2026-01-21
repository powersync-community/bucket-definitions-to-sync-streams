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
    with:
      bucket: SELECT auth.user_id() AS user_id
    query: "SELECT lists.* FROM lists,bucket WHERE lists.owner_id = bucket.user_id"
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
    with:
      bucket: SELECT auth.user_id() AS user
    query: "SELECT a.* FROM a,bucket WHERE a.owner = bucket.user"
''',
    );
  });
}

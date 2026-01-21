import 'package:source_span/source_span.dart';
import 'package:yaml_edit/yaml_edit.dart';
import 'package:yaml/yaml.dart';

import 'src/error.dart';
import 'src/pending_stream.dart';

export 'src/error.dart';

/// Translates sync rules with bucket definitions to equivalent sync streams.
String syncRulesToSyncStreams(String syncRules, {Uri? uri}) {
  final editor = YamlEditor(syncRules);
  final file = SourceFile.fromString(syncRules, url: uri);
  FileSpan translateSpan(SourceSpan span) {
    return file.span(span.start.offset, span.end.offset);
  }

  final diagnostics = <DiagnosticMessage>[];

  final buckets = editor.parseAt([
    'bucket_definitions',
  ], orElse: () => _nullSentinel);
  if (buckets.value is! Map) {
    return syncRules; // No buckets to translate
  }

  final syncStreams = <PendingSyncStream>[];
  var originalBucketDefinitions = 0;

  (buckets.value as Map).forEach((name, value) {
    originalBucketDefinitions++;

    final parameters = editor.parseAt([
      'bucket_definitions',
      name,
      'parameters',
    ], orElse: () => _nullSentinel);
    final data = editor.parseAt([
      'bucket_definitions',
      name,
      'data',
    ], orElse: () => _nullSentinel);
    final priority = editor.parseAt([
      'bucket_definitions',
      name,
      'priority',
    ], orElse: () => _nullSentinel);

    final pending = PendingSyncStream(
      name as String,
      diagnostics,
      switch (priority.value) {
        num i => i.toInt(),
        _ => 3,
      },
    );

    if (parameters.value is String) {
      pending.addParameter(translateSpan(parameters.span));
    } else if (parameters.value case List(:final length)) {
      for (var i = 0; i < length; i++) {
        final parameter = editor.parseAt([
          'bucket_definitions',
          name,
          'parameters',
          i,
        ]);

        if (parameter.value is String) {
          pending.addParameter(translateSpan(parameter.span));
        }
      }
    }

    if (data.value is String) {
      pending.addData(translateSpan(data.span));
    } else if (data.value case List(:final length)) {
      for (var i = 0; i < length; i++) {
        final data = editor.parseAt(['bucket_definitions', name, 'data', i]);

        if (data.value is String) {
          pending.addData(translateSpan(data.span));
        }
      }
    } else {
      return;
    }

    syncStreams.add(pending);
  });

  if (diagnostics.isNotEmpty) {
    throw TranslationFailedException(diagnostics);
  }

  var hasStreamsInYaml =
      editor.parseAt(['streams'], orElse: () => _nullSentinel) != _nullSentinel;

  if (syncStreams.isNotEmpty) {
    if (editor.parseAt(['config'], orElse: () => _nullSentinel) !=
        _nullSentinel) {
      editor.update(['config', 'edition'], 2);
    } else {
      editor.update(['config'], wrapAsYamlNode({'edition': 2}));
    }

    if (originalBucketDefinitions == syncStreams.length) {
      editor.remove(['bucket_definitions']);
    }

    for (final stream in syncStreams) {
      if (originalBucketDefinitions != syncStreams.length) {
        // We can't remove bucket_definitions because we were unable to
        // translate them all. But remove mapped definitions.
        editor.remove(['bucket_definitions', stream.name]);
      }

      final streamInYaml = wrapAsYamlNode(
        collectionStyle: CollectionStyle.BLOCK,
        {
          if (stream.priority != 3) 'priority': stream.priority,
          // Bucket definitions always have a single subscription.
          'auto_subscribe': true,
          if (stream.parameterQueries.isNotEmpty)
            'with': wrapAsYamlNode({
              for (final (i, param) in stream.parameterQueries.indexed)
                parameterCteName(stream.parameterQueries.length, i): param,
            }),
          if (stream.data.length > 1)
            'data': wrapAsYamlNode(stream.data)
          else
            'query': stream.data.single,
        },
      );

      if (hasStreamsInYaml) {
        editor.update(['streams', stream.name], streamInYaml);
      } else {
        editor.update(
          ['streams'],
          wrapAsYamlNode(collectionStyle: CollectionStyle.BLOCK, {
            stream.name: streamInYaml,
          }),
        );
        hasStreamsInYaml = true;
      }
    }
  }

  return editor.toString();
}

final _nullSentinel = wrapAsYamlNode(null);

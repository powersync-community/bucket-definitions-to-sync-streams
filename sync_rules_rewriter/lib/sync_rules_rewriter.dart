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

  FileSpan yamlSpan(YamlNode node) {
    return file.span(node.span.start.offset, node.span.end.offset);
  }

  FileSpan yamlContentSpan(YamlScalar node) {
    final all = yamlSpan(node);
    FileSpan removePrefix(String prefix) {
      final index = all.text.indexOf(prefix);
      return all.subspan(index + 1);
    }

    FileSpan removeQuotes(String quote) {
      final index = all.text.indexOf(quote);
      final end = all.text.lastIndexOf(quote);
      return all.subspan(index + 1, end);
    }

    switch (node.style) {
      case ScalarStyle.FOLDED:
        return removePrefix('>');
      case ScalarStyle.LITERAL:
        return removePrefix('|');
      case ScalarStyle.SINGLE_QUOTED:
        return removeQuotes("'");
      case ScalarStyle.DOUBLE_QUOTED:
        return removeQuotes('"');
      case ScalarStyle.PLAIN:
      case ScalarStyle.ANY:
      default:
        return all;
    }
  }

  final diagnostics = <DiagnosticMessage>[];

  final buckets = editor.parseAt([
    'bucket_definitions',
  ], orElse: () => _nullSentinel);
  if (buckets.value is! Map) {
    return syncRules; // No buckets to translate
  }

  final syncStreams = SyncStreamsCollection();
  var hasDefinitionWithFailedTranslation = false;

  (buckets.value as Map).forEach((name, value) {
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

    final pending = TranslationContext(
      name as String,
      diagnostics,
      switch (priority.value) {
        num i => i.toInt(),
        _ => 3,
      },
    );

    if (parameters.value is String) {
      pending.addParameter(yamlContentSpan(parameters as YamlScalar));
    } else if (parameters.value case List(:final length)) {
      for (var i = 0; i < length; i++) {
        final parameter = editor.parseAt([
          'bucket_definitions',
          name,
          'parameters',
          i,
        ]);

        if (parameter.value is String) {
          pending.addParameter(yamlContentSpan(parameter as YamlScalar));
        }
      }
    }

    if (data.value is String) {
      pending.addData(yamlContentSpan(data as YamlScalar));
    } else if (data.value case List(:final length)) {
      for (var i = 0; i < length; i++) {
        final data = editor.parseAt(['bucket_definitions', name, 'data', i]);

        if (data.value is String) {
          pending.addData(yamlContentSpan(data as YamlScalar));
        }
      }
    } else {
      hasDefinitionWithFailedTranslation = true;
      return;
    }

    syncStreams.addTranslatedStream(pending);
  });

  if (diagnostics.isNotEmpty) {
    throw TranslationFailedException(diagnostics);
  }

  var hasStreamsInYaml =
      editor.parseAt(['streams'], orElse: () => _nullSentinel) != _nullSentinel;

  final streams = syncStreams.pendingStreams.values.toList();
  if (streams.isNotEmpty) {
    if (editor.parseAt(['config'], orElse: () => _nullSentinel) !=
        _nullSentinel) {
      editor.update(['config', 'edition'], 3);
    } else {
      editor.update(['config'], wrapAsYamlNode({'edition': 3}));
    }

    if (!hasDefinitionWithFailedTranslation) {
      editor.remove(['bucket_definitions']);
    }

    for (final stream in streams) {
      if (hasDefinitionWithFailedTranslation) {
        // We can't remove bucket_definitions because we were unable to
        // translate them all. But remove mapped definitions.
        for (final (bucketName, _) in stream.queriesByDefinition) {
          editor.remove(['bucket_definitions', bucketName]);
        }
      }

      final dataQueries = stream.allQueries.toList();
      final streamInYaml = wrapAsYamlNode(
        collectionStyle: CollectionStyle.BLOCK,
        {
          if (stream.priority != 3) 'priority': stream.priority,
          // Bucket definitions always have a single subscription.
          'auto_subscribe': true,
          if (stream.ctes.isNotEmpty)
            'with': wrapAsYamlNode({
              for (final MapEntry(:key, :value) in stream.ctes.entries)
                key: value,
            }),
          // Even if the stream only has a single query, we want to write it as
          // a list so that users can easily add more.
          'queries': wrapAsYamlNode(dataQueries),
        },
      );

      final name = syncStreams.nameForStream(stream);
      if (hasStreamsInYaml) {
        editor.update(['streams', name], streamInYaml);
      } else {
        editor.update(
          ['streams'],
          wrapAsYamlNode(collectionStyle: CollectionStyle.BLOCK, {
            name: streamInYaml,
          }),
        );
        hasStreamsInYaml = true;
      }
    }
  }

  return editor.toString();
}

final _nullSentinel = wrapAsYamlNode(null);

import 'dart:math';

import 'package:source_span/source_span.dart';
import 'package:sqlparser/sqlparser.dart';

import 'error.dart';
import 'node_to_sql.dart';

final class PendingSyncStream {
  final String name;
  final List<DiagnosticMessage> messages;
  final List<String> parameterQueries = [];
  int priority;

  final List<String> data = [];

  PendingSyncStream(this.name, this.messages, this.priority);

  void addParameter(FileSpan span) {
    final root = _ToStreamTranslator(
      this,
      isDataQuery: false,
    ).transform(_parse(span), null);
    if (root != null) {
      parameterQueries.add(FixedNodeToSql.toSql(root));
    }
  }

  void addData(FileSpan span) {
    final root = _ToStreamTranslator(
      this,
      isDataQuery: true,
    ).transform(_parse(span), null);
    if (root != null) {
      data.add(FixedNodeToSql.toSql(root));
    }
  }

  AstNode _parse(FileSpan span) {
    final parsed = _engine.parseSpan(span);
    for (final error in parsed.errors) {
      messages.add(DiagnosticMessage(error.token.span, error.message));
    }
    return parsed.rootNode;
  }
}

final class _ToStreamTranslator extends Transformer<void> {
  final PendingSyncStream stream;
  String? defaultTableName;

  final int parameterQueryCount;

  _ToStreamTranslator(this.stream, {required bool isDataQuery})
    : parameterQueryCount = isDataQuery ? stream.parameterQueries.length : 0;

  @override
  AstNode? visitFunction(FunctionExpression e, void arg) {
    if (e.schemaName?.toLowerCase() == 'request') {
      if (_requestFunctions[e.name.toLowerCase()]
          case (final schema, final name)?) {
        return FunctionExpression(
          name: name,
          schemaName: schema,
          parameters: visit(e.parameters, null) as FunctionParameters,
        );
      }
    }

    return super.visitFunction(e, arg);
  }

  @override
  AstNode? visitStarResultColumn(StarResultColumn e, void arg) {
    if (e.tableName == null) {
      return StarResultColumn(defaultTableName);
    }

    return e;
  }

  @override
  AstNode? visitReference(Reference e, void arg) {
    if (e.entityName == null) {
      return Reference(columnName: e.columnName, entityName: defaultTableName);
    }

    return e;
  }

  @override
  AstNode? visitExpressionResultColumn(ExpressionResultColumn e, void arg) {
    if (e.as == '_priority') {
      if (e.expression case NumericLiteral(isInt: true, :final value)) {
        stream.priority = min(stream.priority, value.toInt());
      }

      return null;
    }

    return super.visitExpressionResultColumn(e, arg);
  }

  @override
  AstNode? visitSelectStatement(SelectStatement e, void arg) {
    // Join CTEs for parameter queries to main statement
    if (parameterQueryCount > 0 && e.from is TableReference) {
      final tableReference = e.from as TableReference;
      defaultTableName = tableReference.as ?? tableReference.tableName;

      e.from = JoinClause(
        primary: tableReference,
        joins: [
          for (var i = 0; i < parameterQueryCount; i++)
            Join(
              operator: .comma(),
              query: TableReference(parameterCteName(parameterQueryCount, i)),
            ),
        ],
      );
    }

    return super.visitSelectStatement(e, arg);
  }

  @override
  AstNode? visitBinaryExpression(BinaryExpression e, void arg) {
    // bucket parameter references can only appear as a direct child of an = or
    // IN operator.
    var expandLeft = _expandBucketReference(e.left);
    var expandRight = _expandBucketReference(e.right);

    // Transform a = bucket.b to a = bucket0.b OR a = bucket1.b OR ...
    if (expandLeft != null || expandRight != null) {
      expandLeft ??= [e.left];
      expandRight ??= [e.right];

      final replacementTerms = <BinaryExpression>[];
      for (final left in expandLeft) {
        for (final right in expandRight) {
          replacementTerms.add(
            BinaryExpression(
              transform(left, null) as Expression,
              e.operator,
              transform(right, null) as Expression,
            ),
          );
        }
      }

      return replacementTerms.reduce(
        (a, b) => BinaryExpression(a, Token(TokenType.or, e.span!), b),
      );
    }

    return super.visitBinaryExpression(e, arg);
  }

  Iterable<Expression>? _expandBucketReference(Expression e) {
    if (e case Reference(:final columnName, entityName: 'bucket')) {
      return Iterable.generate(parameterQueryCount, (i) {
        return Reference(
          columnName: columnName,
          entityName: parameterCteName(parameterQueryCount, i),
        );
      });
    }

    return null;
  }
}

String parameterCteName(int total, int index) {
  if (total == 1) {
    return 'bucket';
  } else {
    return 'bucket$index';
  }
}

const _requestFunctions = {
  'parameter': ('connection', 'parameter'),
  'parameters': ('connection', 'parameters'),
  'jwt': ('auth', 'parameters'),
  'user_id': ('auth', 'user_id'),
};

final _engine = SqlEngine(
  EngineOptions(
    version: SqliteVersion.current,
    supportSchemaInFunctionNames: true,
  ),
);

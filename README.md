# Bucket definitions to sync streams

This tool converts sync rules using [bucket definitions](https://docs.powersync.com/sync/rules/organize-data-into-buckets)
to [sync rules](https://docs.powersync.com/sync/streams/overview).

Usage:

```shell
dart run sync_rules_rewriter/bin/rewrite.dart < sync_rules.yaml
```

Alternatively, paste your sync rules into [this website](https://powersync-community.github.io/bucket-definitions-to-sync-streams/).

## Structure

- `sync_rules_rewriter` is a Dart package responsible for the translation.
- `website` is a standalone website with a small editor running the translation. View it locally by running `dart run webdev serve` in `website/`.


export declare function instantiate(
  source: ArrayBuffer | ArrayBufferView | Response | Promise<Response>,
): Promise<SyncConfigRewriter>;

export interface SyncConfigRewriter {
  /**
   * Translates a YAML file containing Sync Rules defined as (`bucket_definitions`)
   * into a file containing equivalent Sync Streams.
   */
  syncRulesToSyncStreams: (
    source: string,
  ) => CompilerError | TranslatedSyncStreams;
}

export interface DiagnosticMessage {
  startOffset: number;
  length: number;
  message: string;
}

export interface CompilerError {
  type: "error";
  diagnostics: DiagnosticMessage[];
  internalMessage: string;
}

export interface TranslatedSyncStreams {
  type: "success";
  result: string;
}

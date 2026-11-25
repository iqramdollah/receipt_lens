/// Build-time settings passed with --dart-define, so nothing secret lives in
/// the code. With no LLM_BASE_URL the app uses only the offline parser.
abstract final class AppConfig {
  static const llmBaseUrl = String.fromEnvironment('LLM_BASE_URL');
  static const llmModel = String.fromEnvironment('LLM_MODEL');
  static const llmApiKey = String.fromEnvironment('LLM_API_KEY');
  static const llmTimeoutSeconds = int.fromEnvironment(
    'LLM_TIMEOUT_SECONDS',
    defaultValue: 60,
  );

  static bool get hasLlm => llmBaseUrl.isNotEmpty;
}

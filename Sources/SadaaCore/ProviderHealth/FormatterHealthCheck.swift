import Foundation

public enum FormatterHealthCheck {
    public static func check(formatter: AzureChatFormatter,
                             endpoint: String,
                             now: @escaping () -> Date = { Date() }) async -> ProviderHealthResult {
        let startedAt = now()
        let context = FormattingContext(
            appBundleID: "ai.karko.sadaa",
            dictionaryWords: ["Claude Code", "Codex"],
            speakerContext: "Probe only. Format the transcript and return JSON.",
            language: .en,
            snippets: [],
            replacementRules: []
        )

        do {
            let formatted = try await formatter.format(
                rawTranscript: "hello world",
                context: context
            )
            let sample = formatted.text.trimmingCharacters(in: .whitespacesAndNewlines)
            let detail = sample.isEmpty ? "connected; empty probe response"
                                    : "connected; \"\(sample.prefix(80))\""
            return ProviderHealthCheck.result(
                providerName: "Azure GPT",
                endpoint: endpoint,
                ok: true,
                startedAt: startedAt,
                finishedAt: now(),
                message: detail
            )
        } catch {
            return ProviderHealthCheck.result(
                providerName: "Azure GPT",
                endpoint: endpoint,
                ok: false,
                startedAt: startedAt,
                finishedAt: now(),
                message: describe(error)
            )
        }
    }

    public static func describe(_ error: Error) -> String {
        if let provider = error as? ProviderError {
            switch provider {
            case .http(let status, let body):
                let detail = ProviderHealthCheck.sanitize(
                    body.trimmingCharacters(in: .whitespacesAndNewlines)
                )
                return detail.isEmpty ? "HTTP \(status) from provider" : "HTTP \(status): \(detail)"
            case .badResponse:
                return "unreadable formatter response"
            case .notConfigured(let what):
                return what
            case .timedOut:
                return "timed out"
            case .transport(let urlError):
                return urlError.localizedDescription
            }
        }
        return ProviderHealthCheck.sanitize(error.localizedDescription)
    }
}

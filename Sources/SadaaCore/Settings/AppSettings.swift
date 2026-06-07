import Foundation

public enum LanguagePin: String, CaseIterable, Sendable {
    case auto, en, de
}

/// Non-secret app configuration. API keys live in Keychain, never here.
public final class AppSettings {
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var azureEndpoint: String {
        get { defaults.string(forKey: "azureEndpoint") ?? "" }
        set { defaults.set(newValue, forKey: "azureEndpoint") }
    }

    public var azureDeployment: String {
        get { defaults.string(forKey: "azureDeployment") ?? "" }
        set { defaults.set(newValue, forKey: "azureDeployment") }
    }

    public var azureAPIVersion: String {
        get { defaults.string(forKey: "azureAPIVersion") ?? "2024-10-21" }
        set { defaults.set(newValue, forKey: "azureAPIVersion") }
    }

    public var languagePin: LanguagePin {
        get { LanguagePin(rawValue: defaults.string(forKey: "languagePin") ?? "") ?? .auto }
        set { defaults.set(newValue.rawValue, forKey: "languagePin") }
    }

    /// Seconds of silence before recording auto-stops. Spec section 8.
    public var silenceTimeout: TimeInterval {
        get { defaults.object(forKey: "silenceTimeout") as? TimeInterval ?? 60 }
        set { defaults.set(newValue, forKey: "silenceTimeout") }
    }

    /// How many past recordings to retain for retry/debugging. Spec section 5.
    public var recordingsToKeep: Int {
        get { defaults.object(forKey: "recordingsToKeep") as? Int ?? 10 }
        set { defaults.set(newValue, forKey: "recordingsToKeep") }
    }
}

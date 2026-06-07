import SwiftUI
import SadaaCore

struct SettingsView: View {
    let settings: AppSettings
    @State private var endpoint: String = ""
    @State private var deployment: String = ""
    @State private var apiVersion: String = ""
    @State private var apiKey: String = ""
    @State private var saved = false

    var body: some View {
        Form {
            Section("Azure OpenAI") {
                TextField("Endpoint (https://myres.openai.azure.com)",
                          text: $endpoint)
                TextField("Whisper deployment name", text: $deployment)
                TextField("API version", text: $apiVersion)
                SecureField("API key (stored in Keychain)", text: $apiKey)
            }
            HStack {
                Button("Save") { save() }
                    .keyboardShortcut(.defaultAction)
                if saved {
                    Text("Saved").foregroundStyle(.secondary)
                }
            }
        }
        .padding(20)
        .frame(width: 460)
        .onAppear(perform: load)
    }

    private func load() {
        endpoint = settings.azureEndpoint
        deployment = settings.azureDeployment
        apiVersion = settings.azureAPIVersion
        apiKey = Keychain.get(account: "azure-openai-key") ?? ""
    }

    private func save() {
        settings.azureEndpoint = endpoint
            .trimmingCharacters(in: .whitespacesAndNewlines)
        settings.azureDeployment = deployment
            .trimmingCharacters(in: .whitespacesAndNewlines)
        settings.azureAPIVersion = apiVersion
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !apiKey.isEmpty {
            try? Keychain.set(apiKey, account: "azure-openai-key")
        }
        saved = true
    }
}

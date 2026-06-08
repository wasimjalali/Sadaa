import SwiftUI
import SadaaCore

/// The windowed settings: Azure credentials (ported from the old SettingsView),
/// the language pin, and a read-only hotkey reference.
struct SettingsPage: View {
    let settings: AppSettings
    @ObservedObject var viewModel: SadaaViewModel

    @State private var endpoint = ""
    @State private var deployment = ""
    @State private var apiVersion = ""
    @State private var apiKey = ""
    @State private var formattingEnabled = true
    @State private var gptDeployment = ""
    @State private var speakerContext = ""
    @State private var saved = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Settings")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Theme.charcoal)
                    .padding(.bottom, 20)

                Form {
                    Section("Azure OpenAI") {
                        TextField("Endpoint (https://myres.openai.azure.com)",
                                  text: $endpoint)
                        TextField("Whisper deployment name", text: $deployment)
                        TextField("API version", text: $apiVersion)
                        SecureField("API key (stored in Keychain)", text: $apiKey)
                        HStack {
                            Button("Save") { save() }
                                .keyboardShortcut(.defaultAction)
                            if saved {
                                Text("Saved").foregroundStyle(.secondary)
                            }
                        }
                    }

                    Section("Smart formatting") {
                        Toggle("Format dictations with GPT", isOn: $formattingEnabled)
                        TextField("GPT deployment name (e.g. gpt-4o-mini)",
                                  text: $gptDeployment)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Speaker context")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            TextEditor(text: $speakerContext)
                                .frame(minHeight: 64)
                                .font(.system(size: 12))
                        }
                        Text("Hold Shift when you stop to skip formatting for one dictation.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Section("Language") {
                        Picker("Dictation language", selection: languageBinding) {
                            ForEach(LanguagePin.allCases, id: \.self) { pin in
                                Text(PageFormat.languageLabel(pin)).tag(pin)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    Section("Hotkey") {
                        Text("Toggle dictation: Right Option")
                        Text("Cancel recording: Esc")
                    }
                }
                .formStyle(.grouped)
                .scrollContentBackground(.hidden)
                .foregroundStyle(Theme.charcoal)
                .tint(Theme.navy)
                .frame(maxWidth: 560)
            }
            .padding(32)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear(perform: load)
    }

    // MARK: - Language

    private var languageBinding: Binding<LanguagePin> {
        Binding(
            get: { viewModel.languagePin },
            set: { newValue in
                settings.languagePin = newValue
                viewModel.refreshConfig()
            }
        )
    }

    // MARK: - Azure load/save

    private func load() {
        endpoint = settings.azureEndpoint
        deployment = settings.azureDeployment
        apiVersion = settings.azureAPIVersion
        apiKey = Keychain.get(account: "azure-openai-key") ?? ""
        formattingEnabled = settings.formattingEnabled
        gptDeployment = settings.gptDeployment
        speakerContext = settings.speakerContext
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
        settings.formattingEnabled = formattingEnabled
        settings.gptDeployment = gptDeployment
            .trimmingCharacters(in: .whitespacesAndNewlines)
        settings.speakerContext = speakerContext
        viewModel.refreshConfig()
        saved = true
    }
}

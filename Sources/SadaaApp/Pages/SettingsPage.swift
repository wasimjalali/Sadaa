import SwiftUI
import AppKit
import AVFoundation
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
    @State private var openaiEnabled = false
    @State private var openaiModel = ""
    @State private var openaiKey = ""
    @State private var maiEnabled = false
    @State private var maiEndpoint = ""
    @State private var maiKey = ""
    @State private var transcriptionRate = ""
    @State private var formatterRate = ""
    @State private var launchAtLogin = false
    @State private var launchError = ""
    @State private var micGranted = false
    @State private var axTrusted = false
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

                    Section("Fallback providers") {
                        Toggle("OpenAI API fallback", isOn: $openaiEnabled)
                        TextField("OpenAI model (e.g. whisper-1)", text: $openaiModel)
                        SecureField("OpenAI API key (Keychain)", text: $openaiKey)
                        Toggle("Azure Speech / MAI", isOn: $maiEnabled)
                        TextField("MAI endpoint (https://res.cognitiveservices.azure.com)",
                                  text: $maiEndpoint)
                        SecureField("MAI subscription key (Keychain)", text: $maiKey)
                        Text("Providers are tried in order: Azure OpenAI, then OpenAI, then MAI.")
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

                    Section("Cost") {
                        TextField("Transcription rate ($/min)", text: $transcriptionRate)
                        TextField("Formatter rate ($/1k chars)", text: $formatterRate)
                        Text("This month: \(PageFormat.minutes(viewModel.monthlyCost.minutes)), about \(PageFormat.dollars(viewModel.monthlyCost.cost)). An estimate for credit awareness.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Section("Hotkey") {
                        Text("Toggle dictation: Right Option")
                        Text("Cancel recording: Esc")
                        Text("Voice edit selection: Control + Option + E")
                    }

                    Section("General") {
                        Toggle("Launch Sadaa at login", isOn: $launchAtLogin)
                        if !launchError.isEmpty {
                            Text(launchError)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }

                    Section("Permissions") {
                        permissionRow(
                            title: "Microphone", granted: micGranted,
                            pane: "Privacy_Microphone")
                        permissionRow(
                            title: "Accessibility (for the hotkey)", granted: axTrusted,
                            pane: "Privacy_Accessibility")
                        Button("Refresh") { refreshPermissions() }
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

    // MARK: - Permissions

    private func permissionRow(title: String, granted: Bool, pane: String) -> some View {
        HStack {
            Image(systemName: granted ? "checkmark.circle.fill" : "exclamationmark.circle")
                .foregroundStyle(granted ? Theme.sage : Theme.gold)
            Text(title)
            Spacer()
            if !granted {
                Button("Open Settings") { openPrivacyPane(pane) }
                    .buttonStyle(.borderless)
            }
        }
    }

    private func openPrivacyPane(_ pane: String) {
        if let url = URL(string:
            "x-apple.systempreferences:com.apple.preference.security?\(pane)") {
            NSWorkspace.shared.open(url)
        }
    }

    private func refreshPermissions() {
        micGranted = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        axTrusted = AXIsProcessTrusted()
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
        openaiEnabled = settings.openaiEnabled
        openaiModel = settings.openaiModel
        openaiKey = Keychain.get(account: "openai-key") ?? ""
        maiEnabled = settings.maiEnabled
        maiEndpoint = settings.maiEndpoint
        maiKey = Keychain.get(account: "azure-speech-key") ?? ""
        transcriptionRate = String(settings.transcriptionRatePerMinute)
        formatterRate = String(settings.formatterRatePer1kChars)
        launchAtLogin = LoginItem.isEnabled
        refreshPermissions()
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

        settings.openaiEnabled = openaiEnabled
        settings.openaiModel = openaiModel
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !openaiKey.isEmpty {
            try? Keychain.set(openaiKey, account: "openai-key")
        }
        settings.maiEnabled = maiEnabled
        settings.maiEndpoint = maiEndpoint
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !maiKey.isEmpty {
            try? Keychain.set(maiKey, account: "azure-speech-key")
        }
        if let rate = Double(transcriptionRate.trimmingCharacters(in: .whitespaces)) {
            settings.transcriptionRatePerMinute = rate
        }
        if let rate = Double(formatterRate.trimmingCharacters(in: .whitespaces)) {
            settings.formatterRatePer1kChars = rate
        }

        do {
            try LoginItem.setEnabled(launchAtLogin)
            launchError = ""
        } catch {
            launchError = "Couldn't update login item: \(error.localizedDescription)"
            launchAtLogin = LoginItem.isEnabled
        }

        viewModel.refreshConfig()
        viewModel.refreshCost()
        saved = true
    }
}

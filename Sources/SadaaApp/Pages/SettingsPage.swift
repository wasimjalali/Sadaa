import SwiftUI
import AppKit
import AVFoundation
import Combine
import SadaaCore

/// The windowed settings. Every input is an explicitly labelled, bordered box so
/// it is obvious where to click and paste. Sections are cards on the cream page.
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
    @State private var maiModel = ""
    @State private var maiApiVersion = ""
    @State private var transcriptionRate = ""
    @State private var formatterRate = ""
    @State private var launchAtLogin = false
    @State private var launchError = ""
    @State private var micGranted = false
    @State private var axTrusted = false
    @State private var saved = false
    @State private var rateError = ""

    private let permissionTimer = Timer.publish(every: 1.5, on: .main, in: .common)
        .autoconnect()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Settings")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Theme.charcoal)

                azureCard
                formattingCard
                fallbackCard
                languageCostCard
                hotkeyCard
                generalCard
                permissionsCard
            }
            .padding(28)
            .frame(maxWidth: 600, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear(perform: load)
        .onReceive(permissionTimer) { _ in refreshPermissions() }
    }

    // MARK: - Reusable building blocks

    private func card<Content: View>(_ title: String,
                                     @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.charcoal)
            content()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.creamSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Theme.gold.opacity(0.18), lineWidth: 1)
        )
    }

    private func field(_ label: String, _ placeholder: String,
                       _ text: Binding<String>, secure: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.charcoal.opacity(0.85))
            Group {
                if secure {
                    SecureField(placeholder, text: text)
                } else {
                    TextField(placeholder, text: text)
                }
            }
            .textFieldStyle(.roundedBorder)
            .font(.system(size: 13))
        }
    }

    private func hint(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(Theme.charcoal.opacity(0.6))
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Cards

    private var azureCard: some View {
        card("Azure OpenAI / Foundry") {
            field("Endpoint", "https://your-resource.services.ai.azure.com", $endpoint)
            field("Transcription deployment", "gpt-4o-mini-transcribe", $deployment)
            field("API version", "2025-03-01-preview", $apiVersion)
            field("API key", "paste your key", $apiKey, secure: true)
            hint("Works with Azure OpenAI and Azure AI Foundry. The Foundry project URL also works. The deployment is your transcription model, not the chat one. Keys are saved in your macOS Keychain.")
            HStack(spacing: 10) {
                Button("Save") { save() }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.navy)
                    .keyboardShortcut(.defaultAction)
                if saved {
                    Label("Saved", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(Theme.sage)
                }
            }
        }
    }

    private var formattingCard: some View {
        card("Smart formatting") {
            Toggle("Format dictations with GPT", isOn: $formattingEnabled)
                .tint(Theme.navy)
            field("GPT deployment", "gpt-4o-mini", $gptDeployment)
            VStack(alignment: .leading, spacing: 5) {
                Text("Speaker context")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.charcoal.opacity(0.85))
                TextEditor(text: $speakerContext)
                    .frame(minHeight: 70)
                    .font(.system(size: 12))
                    .padding(6)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(Theme.charcoal.opacity(0.2), lineWidth: 1))
            }
            hint("Hold Shift when you stop to skip formatting for one dictation.")
        }
    }

    private var fallbackCard: some View {
        card("Fallback providers (optional)") {
            Toggle("Use OpenAI if Azure fails", isOn: $openaiEnabled)
                .tint(Theme.navy)
            field("OpenAI model", "whisper-1", $openaiModel)
            field("OpenAI API key", "paste your key", $openaiKey, secure: true)
            hint("OpenAI uses api.openai.com automatically, so there is no endpoint to set.")
            Divider()
            Toggle("Use Azure Speech (MAI)", isOn: $maiEnabled)
                .tint(Theme.navy)
            field("Azure Speech endpoint",
                  "https://your-resource.cognitiveservices.azure.com", $maiEndpoint)
            field("Azure Speech key", "paste your key", $maiKey, secure: true)
            field("Azure Speech model", "mai-transcribe-1.5", $maiModel)
            field("Azure Speech API version", "2025-10-15", $maiApiVersion)
            hint("Azure Speech is a separate Azure resource from Azure OpenAI. Leave this off unless you have MAI-Transcribe enabled. Order tried: Azure OpenAI, then OpenAI, then Azure Speech.")
        }
    }

    private var languageCostCard: some View {
        card("Language and cost") {
            VStack(alignment: .leading, spacing: 5) {
                Text("Dictation language")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.charcoal.opacity(0.85))
                Picker("", selection: languageBinding) {
                    ForEach(LanguagePin.allCases, id: \.self) { pin in
                        Text(PageFormat.languageLabel(pin)).tag(pin)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            field("Transcription rate ($/min)", "0.006", $transcriptionRate)
            field("Formatter rate ($/1k chars)", "0.002", $formatterRate)
            if !rateError.isEmpty {
                Text(rateError).font(.caption).foregroundStyle(.red)
            }
            hint("This month: \(PageFormat.minutes(viewModel.monthlyCost.minutes)), about \(PageFormat.dollars(viewModel.monthlyCost.cost)). An estimate for credit awareness.")
        }
    }

    private var hotkeyCard: some View {
        card("Hotkey") {
            VStack(alignment: .leading, spacing: 5) {
                Text("Activation key (tap to start and stop dictation)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.charcoal.opacity(0.85))
                Picker("", selection: hotkeyBinding) {
                    ForEach(HotkeyOption.all) { option in
                        Text(option.label).tag(option.keycode)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(maxWidth: 240, alignment: .leading)
            }
            HStack(spacing: 6) {
                Image(systemName: viewModel.hotkeyActive
                      ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(viewModel.hotkeyActive ? Theme.sage : Theme.gold)
                Text(viewModel.hotkeyActive
                     ? "Hotkey is active."
                     : "Hotkey is not active. Grant Accessibility below.")
                    .font(.caption)
                    .foregroundStyle(Theme.charcoal.opacity(0.7))
            }
            hint("Cancel a recording with Esc. Voice-edit a selection by tapping Right Command.")
        }
    }

    private var generalCard: some View {
        card("General") {
            Toggle("Launch Sadaa at login", isOn: $launchAtLogin)
                .tint(Theme.navy)
            if !launchError.isEmpty {
                Text(launchError).font(.caption).foregroundStyle(.red)
            }
            Button("Apply") { save() }
                .buttonStyle(.bordered)
        }
    }

    private var permissionsCard: some View {
        card("Permissions") {
            permissionRow(title: "Microphone", granted: micGranted,
                          pane: "Privacy_Microphone")
            permissionRow(title: "Accessibility (for the hotkey)", granted: axTrusted,
                          pane: "Privacy_Accessibility")
            hint("Reinstalling the app can reset the Accessibility grant. If the hotkey stops working after an update, toggle Sadaa off and on in System Settings, Privacy and Security, Accessibility.")
        }
    }

    // MARK: - Bindings

    private var languageBinding: Binding<LanguagePin> {
        Binding(
            get: { viewModel.languagePin },
            set: { newValue in
                settings.languagePin = newValue
                viewModel.refreshConfig()
            }
        )
    }

    private var hotkeyBinding: Binding<Int> {
        Binding(
            get: { viewModel.hotkeyKeycode },
            set: { viewModel.setHotkeyKeycode($0) }
        )
    }

    // MARK: - Permissions

    private func permissionRow(title: String, granted: Bool, pane: String) -> some View {
        HStack {
            Image(systemName: granted ? "checkmark.circle.fill" : "exclamationmark.circle")
                .foregroundStyle(granted ? Theme.sage : Theme.gold)
            Text(title).foregroundStyle(Theme.charcoal)
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

    // MARK: - Load / save

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
        maiModel = settings.maiModel
        maiApiVersion = settings.maiApiVersion
        transcriptionRate = String(settings.transcriptionRatePerMinute)
        formatterRate = String(settings.formatterRatePer1kChars)
        launchAtLogin = LoginItem.isEnabled
        refreshPermissions()
    }

    private func save() {
        settings.azureEndpoint = endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        settings.azureDeployment = deployment.trimmingCharacters(in: .whitespacesAndNewlines)
        settings.azureAPIVersion = apiVersion.trimmingCharacters(in: .whitespacesAndNewlines)
        saveKey(apiKey, account: "azure-openai-key")
        settings.formattingEnabled = formattingEnabled
        settings.gptDeployment = gptDeployment.trimmingCharacters(in: .whitespacesAndNewlines)
        settings.speakerContext = speakerContext

        settings.openaiEnabled = openaiEnabled
        settings.openaiModel = openaiModel.trimmingCharacters(in: .whitespacesAndNewlines)
        saveKey(openaiKey, account: "openai-key")
        settings.maiEnabled = maiEnabled
        settings.maiEndpoint = maiEndpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        saveKey(maiKey, account: "azure-speech-key")
        let trimmedMaiModel = maiModel.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedMaiModel.isEmpty { settings.maiModel = trimmedMaiModel }
        let trimmedMaiVersion = maiApiVersion.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedMaiVersion.isEmpty { settings.maiApiVersion = trimmedMaiVersion }

        // Validate rates instead of silently keeping the old value. Accept a
        // comma decimal too, so "0,006" works.
        rateError = ""
        if let rate = parseRate(transcriptionRate) {
            settings.transcriptionRatePerMinute = rate
        } else if !transcriptionRate.trimmingCharacters(in: .whitespaces).isEmpty {
            rateError = "Rates must be numbers, like 0.006."
            transcriptionRate = String(settings.transcriptionRatePerMinute)
        }
        if let rate = parseRate(formatterRate) {
            settings.formatterRatePer1kChars = rate
        } else if !formatterRate.trimmingCharacters(in: .whitespaces).isEmpty {
            rateError = "Rates must be numbers, like 0.006."
            formatterRate = String(settings.formatterRatePer1kChars)
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
        saved = rateError.isEmpty
        if saved {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { saved = false }
        }
    }

    /// Writes a key, or removes it from the Keychain when the field is cleared,
    /// so blanking a key actually revokes it.
    private func saveKey(_ value: String, account: String) {
        if value.isEmpty {
            Keychain.delete(account: account)
        } else {
            try? Keychain.set(value, account: account)
        }
    }

    /// Parses a rate, tolerating a comma decimal separator.
    private func parseRate(_ text: String) -> Double? {
        let normalized = text.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: ",", with: ".")
        return normalized.isEmpty ? nil : Double(normalized)
    }
}

import SwiftUI
import AppKit
import AVFoundation
import Combine
import SadaaCore

/// Flat local control room for provider setup, formatting, hotkeys, permissions,
/// usage, and storage.
struct SettingsPage: View {
    let settings: AppSettings
    @ObservedObject var viewModel: SadaaViewModel

    @State private var endpoint = ""
    @State private var deployment = ""
    @State private var preset: TranscriptionPreset = .fast
    @State private var fastDeployment = ""
    @State private var accurateDeployment = ""
    @State private var apiVersion = ""
    @State private var apiKey = ""
    @State private var formattingEnabled = true
    @State private var gptDeployment = ""
    @State private var speakerContext = ""
    @State private var transcriptionRate = ""
    @State private var formatterRate = ""
    @State private var launchAtLogin = false
    @State private var launchError = ""
    @State private var soundEffects = true
    @State private var micGranted = false
    @State private var axTrusted = false
    @State private var providerHealth: ProviderHealthResult?
    @State private var saved = false
    @State private var rateError = ""

    private let permissionTimer = Timer.publish(every: 1.5, on: .main, in: .common)
        .autoconnect()

    private var localDataURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Sadaa")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                systemStrip
                settingsSurface
            }
            .padding(30)
            .frame(maxWidth: 1120, alignment: .topLeading)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .background(Theme.cream)
        .onAppear(perform: load)
        .onReceive(permissionTimer) { _ in refreshPermissions() }
    }

    private var header: some View {
        CommandPageHeader(
            eyebrow: "Local Control Room",
            title: "Settings",
            subtitle: "One place for Azure, formatting, language, hotkeys, permissions, local storage, and cost awareness."
        ) {
            HStack(spacing: 8) {
                Button {
                    save()
                } label: {
                    Label("Save", systemImage: "checkmark.circle.fill")
                }
                .buttonStyle(SettingsCommandButtonStyle(tint: Theme.navy, filled: true))
                .keyboardShortcut(.defaultAction)

                Button {
                    checkProviderConfiguration()
                } label: {
                    Label("Test", systemImage: "waveform.badge.magnifyingglass")
                }
                .buttonStyle(SettingsCommandButtonStyle(tint: Theme.gold, filled: false))

                savedBadge(saved && launchError.isEmpty && rateError.isEmpty)
            }
        }
    }

    private var systemStrip: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4),
            spacing: 12
        ) {
            CommandMetric(
                icon: viewModel.azureConfigured ? "checkmark.seal.fill" : "exclamationmark.triangle.fill",
                value: viewModel.azureConfigured ? "Ready" : "Needs setup",
                label: "Azure transcription",
                tint: viewModel.azureConfigured ? Theme.sage : Theme.warning
            )
            CommandMetric(
                icon: viewModel.hotkeyActive ? "keyboard.fill" : "keyboard",
                value: viewModel.hotkeyActive ? "Active" : "Off",
                label: "global hotkeys",
                tint: viewModel.hotkeyActive ? Theme.sage : Theme.warning
            )
            CommandMetric(
                icon: "clock",
                value: PageFormat.minutes(viewModel.monthlyCost.minutes),
                label: "monthly audio",
                tint: Theme.navy
            )
            CommandMetric(
                icon: "creditcard",
                value: PageFormat.dollars(viewModel.monthlyCost.cost),
                label: "estimated spend",
                tint: Theme.gold
            )
        }
    }

    private var settingsSurface: some View {
        CommandPanel {
            VStack(alignment: .leading, spacing: 0) {
                SettingsBand(icon: "cloud.fill",
                             title: "Azure",
                             detail: "Transcription endpoint, deployment, version, and Keychain secret.") {
                    azureControls
                }
                settingsDivider
                SettingsBand(icon: "speedometer",
                             title: "Models",
                             detail: "Focused presets for speed or accuracy, without extra provider clutter.") {
                    modelControls
                }
                settingsDivider
                SettingsBand(icon: "sparkles",
                             title: "Formatting",
                             detail: "AI-specialist cleanup, terminology context, and language behavior.") {
                    formattingControls
                }
                settingsDivider
                SettingsBand(icon: "keyboard.fill",
                             title: "Hotkeys",
                             detail: "Three distinct tap keys for dictation, voice edit, and language switching.") {
                    hotkeyControls
                }
                settingsDivider
                SettingsBand(icon: "slider.horizontal.3",
                             title: "Local App",
                             detail: "Startup behavior, sound, monthly estimates, permissions, and data location.") {
                    localControls
                }
            }
        }
    }

    private var settingsDivider: some View {
        Rectangle()
            .fill(Theme.line)
            .frame(height: 1)
            .padding(.vertical, 18)
    }

    private var azureControls: some View {
        VStack(alignment: .leading, spacing: 14) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                settingsField("Endpoint", "https://your-resource.services.ai.azure.com", $endpoint)
                settingsField("API version", "2025-03-01-preview", $apiVersion)
                settingsField("Active transcription deployment", "gpt-4o-mini-transcribe", $deployment)
                settingsField("API key", "Stored in Keychain", $apiKey, secure: true)
            }

            HStack(spacing: 10) {
                Button {
                    save()
                } label: {
                    Label("Save Azure", systemImage: "checkmark")
                }
                .buttonStyle(SettingsCommandButtonStyle(tint: Theme.navy, filled: true))

                Button {
                    checkProviderConfiguration()
                } label: {
                    Label("Test Azure", systemImage: "waveform.badge.magnifyingglass")
                }
                .buttonStyle(SettingsCommandButtonStyle(tint: Theme.gold, filled: false))

                if let providerHealth {
                    PremiumStatusBadge(
                        icon: providerHealth.ok ? "checkmark.circle.fill" : "exclamationmark.triangle.fill",
                        text: "\(providerHealth.providerName): \(providerHealth.message)",
                        tint: providerHealth.ok ? Theme.sage : Theme.warning
                    )
                } else {
                    PremiumStatusBadge(icon: "lock.fill", text: "Keychain secured", tint: Theme.navy)
                }
            }
        }
    }

    private var modelControls: some View {
        VStack(alignment: .leading, spacing: 14) {
            Picker("Preset", selection: $preset) {
                ForEach(TranscriptionPreset.allCases, id: \.self) { option in
                    Text(presetLabel(option)).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .tint(Theme.navy)
            .accentColor(Theme.navy)
            .labelsHidden()
            .frame(maxWidth: 360)
            .onChange(of: preset) { _, newValue in
                switch newValue {
                case .fast:
                    deployment = fastDeployment
                case .accurate:
                    deployment = accurateDeployment
                }
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                settingsField("Fast deployment", "gpt-4o-mini-transcribe", $fastDeployment)
                settingsField("Accurate deployment", "gpt-4o-transcribe", $accurateDeployment)
            }
        }
    }

    private var formattingControls: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                SettingsToggleRow(
                    title: "Smart formatting",
                    detail: formattingEnabled ? "Enabled" : "Raw transcript mode",
                    isOn: $formattingEnabled
                )
                .onChange(of: formattingEnabled) { _, isOn in
                    settings.formattingEnabled = isOn
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Language")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Theme.muted)
                    Picker("", selection: languageBinding) {
                        ForEach(LanguagePin.allCases, id: \.self) { pin in
                            Text(PageFormat.languageLabel(pin)).tag(pin)
                        }
                    }
                    .pickerStyle(.segmented)
                    .tint(Theme.navy)
                    .accentColor(Theme.navy)
                    .labelsHidden()
                }
                .frame(maxWidth: 340)
            }

            settingsField("GPT formatting deployment", "gpt-4o-mini", $gptDeployment)

            VStack(alignment: .leading, spacing: 8) {
                Text("Speaker context")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.muted)
                TextEditor(text: $speakerContext)
                    .font(.system(size: 12))
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .frame(minHeight: 92)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.line, lineWidth: 1))
            }
        }
    }

    private var hotkeyControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                hotkeyPicker("Dictation", selection: hotkeyBinding)
                hotkeyPicker("Voice edit", selection: voiceEditBinding)
                hotkeyPicker("Language", selection: languageSwitchBinding)
            }

            PremiumStatusBadge(
                icon: viewModel.hotkeyActive ? "checkmark.circle.fill" : "exclamationmark.triangle.fill",
                text: viewModel.hotkeyActive ? "Hotkeys active" : "Accessibility needed",
                tint: viewModel.hotkeyActive ? Theme.sage : Theme.warning
            )
        }
    }

    private var localControls: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                SettingsToggleRow(title: "Launch at login",
                                  detail: launchAtLogin ? "Enabled" : "Manual launch",
                                  isOn: $launchAtLogin)
                SettingsToggleRow(title: "Sound effects",
                                  detail: soundEffects ? "Chimes on" : "Silent",
                                  isOn: $soundEffects)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                settingsField("Transcription rate ($/min)", "0.006", $transcriptionRate)
                settingsField("Formatter rate ($/1k chars)", "0.002", $formatterRate)
            }

            if !rateError.isEmpty {
                PremiumStatusBadge(icon: "exclamationmark.triangle.fill", text: rateError, tint: Theme.red)
            }
            if !launchError.isEmpty {
                PremiumStatusBadge(icon: "exclamationmark.triangle.fill", text: launchError, tint: Theme.red)
            }

            HStack(alignment: .center, spacing: 10) {
                permissionChip("Microphone", granted: micGranted, pane: "Privacy_Microphone")
                permissionChip("Accessibility", granted: axTrusted, pane: "Privacy_Accessibility")

                Spacer(minLength: 8)

                Button {
                    revealLocalData()
                } label: {
                    Label("Open Data Folder", systemImage: "folder")
                }
                .buttonStyle(SettingsCommandButtonStyle(tint: Theme.navy, filled: false))

                Button {
                    save()
                } label: {
                    Label("Apply", systemImage: "checkmark")
                }
                .buttonStyle(SettingsCommandButtonStyle(tint: Theme.navy, filled: true))
            }
        }
    }

    // MARK: - Controls

    private func settingsField(_ label: String,
                               _ placeholder: String,
                               _ text: Binding<String>,
                               secure: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Theme.muted)
            Group {
                if secure {
                    SecureField(placeholder, text: text)
                } else {
                    TextField(placeholder, text: text)
                }
            }
            .textFieldStyle(.plain)
            .font(.system(size: 13))
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.line, lineWidth: 1))
        }
    }

    private func hotkeyPicker(_ title: String, selection: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Theme.muted)
            Picker("", selection: selection) {
                ForEach(HotkeyOption.all) { option in
                    Text(option.label).tag(option.keycode)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.line, lineWidth: 1))
    }

    private func permissionChip(_ title: String, granted: Bool, pane: String) -> some View {
        Button {
            if !granted { openPrivacyPane(pane) }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: granted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .font(.system(size: 11, weight: .bold))
                Text(title)
                    .font(.system(size: 11, weight: .bold))
            }
        }
        .buttonStyle(SettingsCommandButtonStyle(tint: granted ? Theme.sage : Theme.warning, filled: false))
        .help(granted ? "\(title) granted" : "Open \(title) privacy settings")
    }

    private func savedBadge(_ visible: Bool) -> some View {
        Label("Saved", systemImage: "checkmark.circle.fill")
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(Theme.sage)
            .opacity(visible ? 1 : 0)
            .scaleEffect(visible ? 1 : 0.92)
            .animation(.spring(response: 0.3, dampingFraction: 0.86), value: visible)
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

    private var voiceEditBinding: Binding<Int> {
        Binding(
            get: { viewModel.voiceEditKeycode },
            set: { viewModel.setVoiceEditKeycode($0) }
        )
    }

    private var languageSwitchBinding: Binding<Int> {
        Binding(
            get: { viewModel.languageSwitchKeycode },
            set: { viewModel.setLanguageSwitchKeycode($0) }
        )
    }

    // MARK: - Permissions and storage

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

    private func revealLocalData() {
        try? FileManager.default.createDirectory(at: localDataURL, withIntermediateDirectories: true)
        NSWorkspace.shared.activateFileViewerSelecting([localDataURL])
    }

    // MARK: - Load / save

    private func load() {
        endpoint = settings.azureEndpoint
        deployment = settings.azureDeployment
        preset = settings.transcriptionPreset
        fastDeployment = settings.fastTranscriptionDeployment
        accurateDeployment = settings.accurateTranscriptionDeployment
        apiVersion = settings.azureAPIVersion
        apiKey = Keychain.get(account: "azure-openai-key") ?? ""
        formattingEnabled = settings.formattingEnabled
        gptDeployment = settings.gptDeployment
        speakerContext = settings.speakerContext
        transcriptionRate = String(settings.transcriptionRatePerMinute)
        formatterRate = String(settings.formatterRatePer1kChars)
        launchAtLogin = LoginItem.isEnabled
        soundEffects = settings.soundEffectsEnabled
        refreshPermissions()
    }

    private func save() {
        settings.azureEndpoint = endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        settings.azureDeployment = deployment.trimmingCharacters(in: .whitespacesAndNewlines)
        settings.transcriptionPreset = preset
        let trimmedFastDeployment = fastDeployment.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedFastDeployment.isEmpty { settings.fastTranscriptionDeployment = trimmedFastDeployment }
        let trimmedAccurateDeployment = accurateDeployment.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedAccurateDeployment.isEmpty { settings.accurateTranscriptionDeployment = trimmedAccurateDeployment }
        let trimmedAPIVersion = apiVersion.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedAPIVersion.isEmpty { settings.azureAPIVersion = trimmedAPIVersion }
        saveKey(apiKey, account: "azure-openai-key")
        settings.gptDeployment = gptDeployment.trimmingCharacters(in: .whitespacesAndNewlines)
        settings.speakerContext = speakerContext
        settings.soundEffectsEnabled = soundEffects

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
            rateError = "Rates must be numbers, like 0.002."
            formatterRate = String(settings.formatterRatePer1kChars)
        }

        do {
            try LoginItem.setEnabled(launchAtLogin)
            launchError = ""
        } catch {
            launchError = "Couldn't update login item: \(error.localizedDescription)"
            launchAtLogin = LoginItem.isEnabled
        }

        load()
        viewModel.refreshConfig()
        viewModel.refreshCost()
        saved = rateError.isEmpty && launchError.isEmpty
        if saved {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { saved = false }
        }
    }

    private func saveKey(_ value: String, account: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            Keychain.delete(account: account)
        } else {
            try? Keychain.set(trimmed, account: account)
        }
    }

    private func parseRate(_ text: String) -> Double? {
        let normalized = text.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: ",", with: ".")
        return normalized.isEmpty ? nil : Double(normalized)
    }

    private func checkProviderConfiguration() {
        let trimmedEndpoint = endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDeployment = deployment.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAPIVersion = apiVersion.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedEndpoint.isEmpty, !trimmedDeployment.isEmpty, !trimmedKey.isEmpty else {
            providerHealth = ProviderHealthCheck.result(
                providerName: "Azure OpenAI",
                endpoint: trimmedEndpoint,
                ok: false,
                startedAt: Date(),
                finishedAt: Date(),
                message: "missing endpoint, deployment, or key"
            )
            return
        }

        guard let endpointURL = URL(string: trimmedEndpoint), endpointURL.host != nil else {
            providerHealth = ProviderHealthCheck.result(
                providerName: "Azure OpenAI",
                endpoint: trimmedEndpoint,
                ok: false,
                startedAt: Date(),
                finishedAt: Date(),
                message: "invalid endpoint URL"
            )
            return
        }

        let provider = AzureOpenAIProvider(config: .init(
            endpoint: endpointURL,
            apiKey: trimmedKey,
            deployment: trimmedDeployment,
            apiVersion: trimmedAPIVersion.isEmpty ? settings.azureAPIVersion : trimmedAPIVersion
        ))
        let biasWords = MemoryBiasBuilder.biasList(
            terms: viewModel.languageMemory.terms,
            baseVocabulary: BaseVocabulary.terms,
            budget: 50,
            language: MemoryLanguage(languagePin: viewModel.languagePin)
        )
        let hint = TranscriptionHint(languagePin: viewModel.languagePin,
                                     dictionaryWords: biasWords)
        providerHealth = ProviderHealthResult(
            providerName: "Azure OpenAI",
            ok: false,
            latencyMilliseconds: nil,
            message: "testing provider...",
            redactedEndpoint: ProviderHealthCheck.redactedEndpoint(trimmedEndpoint)
        )

        Task {
            let result = await ProviderHealthCheck.check(
                provider: provider,
                endpoint: trimmedEndpoint,
                hint: hint
            )
            await MainActor.run {
                providerHealth = result
            }
        }
    }

    private func presetLabel(_ preset: TranscriptionPreset) -> String {
        switch preset {
        case .fast: return "Fast"
        case .accurate: return "Accurate"
        }
    }
}

private struct SettingsBand<Content: View>: View {
    let icon: String
    let title: String
    let detail: String
    let content: Content

    init(icon: String, title: String, detail: String, @ViewBuilder content: () -> Content) {
        self.icon = icon
        self.title = title
        self.detail = detail
        self.content = content()
    }

    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.gold)
                    .frame(width: 18)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.navy)
                    Text(detail)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(width: 255, alignment: .leading)

            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct SettingsToggleRow: View {
    let title: String
    let detail: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.ink)
                Text(detail)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.muted)
            }
            Spacer(minLength: 10)
            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .labelsHidden()
                .tint(Theme.navy)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.line, lineWidth: 1))
    }
}

private struct SettingsCommandButtonStyle: ButtonStyle {
    let tint: Color
    var filled: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(filled ? Theme.white : tint)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(filled ? tint : tint.opacity(configuration.isPressed ? 0.16 : 0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(filled ? tint.opacity(0.2) : tint.opacity(0.26), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.85), value: configuration.isPressed)
    }
}

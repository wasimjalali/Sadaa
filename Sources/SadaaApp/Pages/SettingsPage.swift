import SwiftUI
import AppKit
import SadaaCore

struct SettingsPage: View {
    let settings: AppSettings
    @ObservedObject var viewModel: SadaaViewModel

    @State private var providerKind: SpeechProviderKind = .azureOpenAI
    @State private var azureEndpoint = ""
    @State private var azureDeployment = ""
    @State private var azureAPIVersion = ""
    @State private var azureKey = ""
    @State private var compatibleEndpoint = ""
    @State private var compatibleModel = ""
    @State private var compatibleKey = ""
    @State private var hasAzureKey = false
    @State private var hasCompatibleKey = false

    @State private var formattingEnabled = true
    @State private var gptDeployment = ""
    @State private var speakerContext = ""
    @State private var silenceTimeout = 60.0
    @State private var recordingsToKeep = 10
    @State private var transcriptionRate = "0.006"
    @State private var formatterRate = "0.002"
    @State private var soundEffectsEnabled = true
    @State private var launchAtLogin = false

    @State private var saveMessage = ""
    @State private var saveIsError = false
    @State private var isTesting = false
    @State private var testResult: ProviderHealthResult?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                statusLine
                generalSection
                speechSection
                writingSection
                dataSection
            }
            .padding(32)
            .frame(maxWidth: 920, alignment: .topLeading)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .background(Theme.surface)
        .onAppear(perform: load)
    }

    private var header: some View {
        CommandPageHeader(
            title: "Settings",
            subtitle: "Choose how Sadaa listens, writes and stores your local data."
        ) {
            WrappingHStack(horizontalSpacing: 10, verticalSpacing: 8) {
                Button(isTesting ? "Testing" : "Test connection") { testConnection() }
                    .buttonStyle(.bordered)
                    .tint(Theme.brand)
                    .controlSize(.large)
                    .clickableCursor()
                    .disabled(isTesting)
                Button("Save settings") { save() }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.brand)
                    .controlSize(.large)
                    .clickableCursor()
            }
        }
    }

    private var statusLine: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Circle()
                    .fill(viewModel.providerConfigured ? Theme.success : Theme.warning)
                    .frame(width: 8, height: 8)
                Text(viewModel.providerConfigured
                     ? "\(viewModel.providerName) is ready"
                     : "Speech provider needs setup")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Spacer()
                if !saveMessage.isEmpty {
                    Text(saveMessage)
                        .font(.system(size: 12))
                        .foregroundStyle(saveIsError ? Theme.danger : Theme.success)
                }
            }

            if let result = testResult {
                Text(result.ok
                     ? "Connected to \(result.providerName) in \(result.latencyMilliseconds ?? 0) ms."
                     : result.message)
                    .font(.system(size: 12))
                    .foregroundStyle(result.ok ? Theme.success : Theme.danger)
            }
        }
        .padding(14)
        .background(Theme.surfaceSubtle, in: RoundedRectangle(cornerRadius: 10))
    }

    private var generalSection: some View {
        settingsSection(
            title: "General",
            detail: "Language, shortcuts and app behavior."
        ) {
            VStack(spacing: 16) {
                settingsRow("Language", detail: "Auto-detect, English or German") {
                    BrandedMenuPicker(
                        title: "Language",
                        selection: languageBinding,
                        options: [
                            ("Auto-detect", LanguagePin.auto),
                            ("English", LanguagePin.en),
                            ("German", LanguagePin.de),
                        ]
                    )
                    .frame(width: 170)
                }

                Divider().overlay(Theme.line)

                settingsRow("Dictation hotkey", detail: "Tap once to start and again to stop") {
                    hotkeyPicker(selection: hotkeyBinding)
                }

                settingsRow("Language hotkey", detail: "Quickly switch between English and German") {
                    hotkeyPicker(selection: languageSwitchBinding)
                }

                Divider().overlay(Theme.line)

                settingsRow("Start at login", detail: "Keep Sadaa ready in the menu bar") {
                    Toggle("", isOn: launchBinding).labelsHidden()
                }
                settingsRow("Sound cues", detail: "Play a quiet tone when recording starts and stops") {
                    Toggle("", isOn: $soundEffectsEnabled).labelsHidden()
                }

                HStack(spacing: 10) {
                    Button("Microphone settings") { openPrivacyPane("Privacy_Microphone") }
                        .clickableCursor()
                    Button("Accessibility settings") { openPrivacyPane("Privacy_Accessibility") }
                        .clickableCursor()
                }
                .buttonStyle(.borderless)
                .font(.system(size: 12, weight: .medium))
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var speechSection: some View {
        settingsSection(
            title: "Speech provider",
            detail: "Connect Azure OpenAI or any standard OpenAI-compatible Whisper endpoint."
        ) {
            VStack(alignment: .leading, spacing: 16) {
                Picker("Provider", selection: $providerKind) {
                    Text("Azure OpenAI").tag(SpeechProviderKind.azureOpenAI)
                    Text("OpenAI-compatible").tag(SpeechProviderKind.openAICompatible)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 420)
                .tint(Theme.brand)
                .clickableCursor()

                if providerKind == .azureOpenAI {
                    azureFields
                } else {
                    compatibleFields
                }
            }
        }
    }

    private var azureFields: some View {
        VStack(alignment: .leading, spacing: 12) {
            field("Endpoint", "https://your-resource.openai.azure.com", $azureEndpoint)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    field("Transcription deployment", "gpt-4o-mini-transcribe", $azureDeployment)
                    field("API version", "2025-03-01-preview", $azureAPIVersion)
                }
                VStack(spacing: 12) {
                    field("Transcription deployment", "gpt-4o-mini-transcribe", $azureDeployment)
                    field("API version", "2025-03-01-preview", $azureAPIVersion)
                }
            }
            secretField(
                title: "API key",
                placeholder: hasAzureKey ? "Saved in Keychain. Enter a new key to replace it." : "Enter Azure API key",
                value: $azureKey,
                hasSavedValue: hasAzureKey,
                clear: {
                    Keychain.delete(account: "azure-openai-key")
                    hasAzureKey = false
                    viewModel.refreshConfig()
                }
            )
        }
    }

    private var compatibleFields: some View {
        VStack(alignment: .leading, spacing: 12) {
            field("Base URL", "https://api.openai.com or http://127.0.0.1:8080", $compatibleEndpoint)
            field("Model", "whisper-1", $compatibleModel)
            secretField(
                title: "Bearer token",
                placeholder: hasCompatibleKey ? "Saved in Keychain. Enter a new token to replace it." : "Optional for local endpoints",
                value: $compatibleKey,
                hasSavedValue: hasCompatibleKey,
                clear: {
                    Keychain.delete(account: "openai-compatible-key")
                    hasCompatibleKey = false
                    viewModel.refreshConfig()
                }
            )
            Text("Sadaa sends standard multipart requests to /v1/audio/transcriptions. This works with OpenAI-compatible hosted and self-hosted Whisper services.")
                .font(.system(size: 11))
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var writingSection: some View {
        settingsSection(
            title: "Writing",
            detail: "Optional cleanup after transcription. Dictionary corrections still work when this is off."
        ) {
            VStack(alignment: .leading, spacing: 16) {
                settingsRow("Clean up punctuation and formatting", detail: "Uses your Azure GPT deployment when configured") {
                    Toggle("", isOn: $formattingEnabled).labelsHidden()
                }

                if formattingEnabled {
                    field("Azure GPT deployment", "gpt-4o-mini", $gptDeployment)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Writing context")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.ink)
                        TextEditor(text: $speakerContext)
                            .font(.system(size: 13))
                            .scrollContentBackground(.hidden)
                            .padding(10)
                            .frame(minHeight: 100)
                            .background(Theme.surfaceSubtle, in: RoundedRectangle(cornerRadius: 9))
                            .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(Theme.line, lineWidth: 1))
                    }
                    if providerKind == .openAICompatible {
                        Text("Text cleanup currently uses Azure OpenAI. Leave it off if you only want your OpenAI-compatible speech endpoint and local dictionary corrections.")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.muted)
                    }
                }
            }
        }
    }

    private var dataSection: some View {
        settingsSection(
            title: "Data and recording",
            detail: "Control local retention, silence detection and optional cost estimates."
        ) {
            VStack(spacing: 16) {
                settingsRow("Stop after silence", detail: "Automatically finish a recording after this many seconds") {
                    HStack(spacing: 8) {
                        Slider(value: $silenceTimeout, in: 15...120, step: 5).frame(width: 150)
                        Text("\(Int(silenceTimeout)) sec")
                            .font(.system(size: 11).monospacedDigit())
                            .foregroundStyle(Theme.muted)
                            .frame(width: 48, alignment: .trailing)
                    }
                }

                settingsRow("Keep recordings", detail: "Retained audio enables retry and reprocessing") {
                    Stepper("\(recordingsToKeep)", value: $recordingsToKeep, in: 0...50)
                        .frame(width: 110)
                }

                Divider().overlay(Theme.line)

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) {
                        field("Transcription estimate per minute", "0.006", $transcriptionRate)
                        field("Cleanup estimate per 1,000 characters", "0.002", $formatterRate)
                    }
                    VStack(spacing: 12) {
                        field("Transcription estimate per minute", "0.006", $transcriptionRate)
                        field("Cleanup estimate per 1,000 characters", "0.002", $formatterRate)
                    }
                }

                HStack {
                    Text("This month")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    Text("\(PageFormat.minutes(viewModel.monthlyCost.minutes)) · \(PageFormat.dollars(viewModel.monthlyCost.cost)) estimated")
                        .font(.system(size: 12).monospacedDigit())
                        .foregroundStyle(Theme.muted)
                }
            }
        }
    }

    private func settingsSection<Content: View>(
        title: String,
        detail: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.muted)
            }
            content()
        }
        .padding(20)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.line, lineWidth: 1))
    }

    private func settingsRow<Accessory: View>(
        _ title: String,
        detail: String,
        @ViewBuilder accessory: () -> Accessory
    ) -> some View {
        HStack(alignment: .center, spacing: 20) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.ink)
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 20)
            accessory()
        }
    }

    private func field(_ title: String, _ placeholder: String, _ value: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.ink)
            TextField(placeholder, text: value).premiumInputChrome()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func secretField(
        title: String,
        placeholder: String,
        value: Binding<String>,
        hasSavedValue: Bool,
        clear: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.ink)
                if hasSavedValue {
                    Text("Stored in Keychain")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.success)
                }
                Spacer()
                if hasSavedValue {
                    Button("Remove saved key", role: .destructive, action: clear)
                        .buttonStyle(.borderless)
                        .font(.system(size: 11))
                        .clickableCursor()
                }
            }
            SecureField(placeholder, text: value).premiumInputChrome()
        }
    }

    private func hotkeyPicker(selection: Binding<Int>) -> some View {
        BrandedMenuPicker(
            title: "Hotkey",
            selection: selection,
            options: HotkeyOption.all.map { ($0.label, $0.keycode) }
        )
        .frame(width: 170)
    }

    private var languageBinding: Binding<LanguagePin> {
        Binding(
            get: { viewModel.languagePin },
            set: {
                settings.languagePin = $0
                viewModel.refreshConfig()
            }
        )
    }

    private var hotkeyBinding: Binding<Int> {
        Binding(get: { viewModel.hotkeyKeycode }, set: { viewModel.setHotkeyKeycode($0) })
    }

    private var languageSwitchBinding: Binding<Int> {
        Binding(get: { viewModel.languageSwitchKeycode }, set: { viewModel.setLanguageSwitchKeycode($0) })
    }

    private var launchBinding: Binding<Bool> {
        Binding(
            get: { launchAtLogin },
            set: { newValue in
                do {
                    try LoginItem.setEnabled(newValue)
                    launchAtLogin = newValue
                    saveMessage = "Login setting updated"
                    saveIsError = false
                } catch {
                    saveMessage = "Could not update login setting"
                    saveIsError = true
                }
            }
        )
    }

    private func load() {
        providerKind = settings.speechProviderKind
        azureEndpoint = settings.azureEndpoint
        azureDeployment = settings.azureDeployment
        azureAPIVersion = settings.azureAPIVersion
        compatibleEndpoint = settings.compatibleEndpoint
        compatibleModel = settings.compatibleModel
        hasAzureKey = Keychain.exists(account: "azure-openai-key")
        hasCompatibleKey = Keychain.exists(account: "openai-compatible-key")
        formattingEnabled = settings.formattingEnabled
        gptDeployment = settings.gptDeployment
        speakerContext = settings.speakerContext
        silenceTimeout = settings.silenceTimeout
        recordingsToKeep = settings.recordingsToKeep
        transcriptionRate = String(settings.transcriptionRatePerMinute)
        formatterRate = String(settings.formatterRatePer1kChars)
        soundEffectsEnabled = settings.soundEffectsEnabled
        launchAtLogin = LoginItem.isEnabled
    }

    private func save() {
        saveMessage = ""
        saveIsError = false

        guard let transcriptionRateValue = decimal(transcriptionRate),
              let formatterRateValue = decimal(formatterRate)
        else {
            saveMessage = "Cost estimates must be valid numbers"
            saveIsError = true
            return
        }

        settings.speechProviderKind = providerKind
        settings.azureEndpoint = azureEndpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        settings.azureDeployment = azureDeployment.trimmingCharacters(in: .whitespacesAndNewlines)
        settings.azureAPIVersion = azureAPIVersion.trimmingCharacters(in: .whitespacesAndNewlines)
        settings.compatibleEndpoint = compatibleEndpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        settings.compatibleModel = compatibleModel.trimmingCharacters(in: .whitespacesAndNewlines)
        settings.formattingEnabled = formattingEnabled
        settings.gptDeployment = gptDeployment.trimmingCharacters(in: .whitespacesAndNewlines)
        settings.speakerContext = speakerContext
        settings.silenceTimeout = silenceTimeout
        settings.recordingsToKeep = recordingsToKeep
        settings.soundEffectsEnabled = soundEffectsEnabled

        settings.transcriptionRatePerMinute = transcriptionRateValue
        settings.formatterRatePer1kChars = formatterRateValue

        do {
            if !azureKey.isEmpty {
                try Keychain.set(azureKey, account: "azure-openai-key")
                hasAzureKey = true
                azureKey = ""
            }
            if !compatibleKey.isEmpty {
                try Keychain.set(compatibleKey, account: "openai-compatible-key")
                hasCompatibleKey = true
                compatibleKey = ""
            }
            viewModel.refreshConfig()
            viewModel.refreshCost()
            saveMessage = "Settings saved"
        } catch {
            saveMessage = "Could not save the Keychain value"
            saveIsError = true
        }
    }

    private func testConnection() {
        testResult = nil
        isTesting = true
        Task {
            let endpoint: String
            let provider: TranscriptionProvider
            switch providerKind {
            case .azureOpenAI:
                guard let url = URL(string: azureEndpoint),
                      !azureDeployment.isEmpty,
                      let key = azureKey.isEmpty ? Keychain.get(account: "azure-openai-key") : azureKey
                else {
                    await MainActor.run {
                        testResult = ProviderHealthCheck.result(
                            providerName: "Azure OpenAI",
                            endpoint: azureEndpoint,
                            ok: false,
                            startedAt: Date(),
                            finishedAt: Date(),
                            message: "Enter an endpoint, deployment and API key."
                        )
                        isTesting = false
                    }
                    return
                }
                endpoint = azureEndpoint
                provider = AzureOpenAIProvider(config: .init(
                    endpoint: url,
                    apiKey: key,
                    deployment: azureDeployment,
                    apiVersion: azureAPIVersion
                ))
            case .openAICompatible:
                guard let url = URL(string: compatibleEndpoint), !compatibleModel.isEmpty else {
                    await MainActor.run {
                        testResult = ProviderHealthCheck.result(
                            providerName: "OpenAI-compatible",
                            endpoint: compatibleEndpoint,
                            ok: false,
                            startedAt: Date(),
                            finishedAt: Date(),
                            message: "Enter a valid base URL and model."
                        )
                        isTesting = false
                    }
                    return
                }
                endpoint = compatibleEndpoint
                let key = compatibleKey.isEmpty
                    ? Keychain.get(account: "openai-compatible-key") ?? ""
                    : compatibleKey
                provider = OpenAICompatibleProvider(config: .init(
                    baseURL: url,
                    apiKey: key,
                    model: compatibleModel
                ))
            }

            let result = await ProviderHealthCheck.check(
                provider: provider,
                endpoint: endpoint,
                hint: TranscriptionHint(languagePin: viewModel.languagePin, dictionaryWords: [])
            )
            await MainActor.run {
                testResult = result
                isTesting = false
            }
        }
    }

    private func decimal(_ value: String) -> Double? {
        Double(value.replacingOccurrences(of: ",", with: "."))
    }

    private func openPrivacyPane(_ pane: String) {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") else { return }
        NSWorkspace.shared.open(url)
    }
}

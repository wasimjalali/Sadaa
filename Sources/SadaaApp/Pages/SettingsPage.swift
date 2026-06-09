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
    @State private var promptModeEnabled = false
    @State private var promptModeTarget: ModelPackID = .claude
    @State private var promptModeApps = ""
    @State private var promptModeDeployment = ""
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
    @State private var packsError = ""
    @State private var soundEffects = true
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

                // Ordered by how often you actually touch it: the daily controls
                // up top, one-time setup and troubleshooting toward the bottom.
                hotkeyCard
                languageCard
                formattingCard
                promptModeCard
                azureCard
                fallbackCard
                costCard
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
                                     icon: String? = nil,
                                     @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.gold)
                }
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.navy)
            }
            Rectangle()
                .fill(Theme.gold.opacity(0.22))
                .frame(height: 1)
                .padding(.bottom, 2)
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

    /// Small colored status pill. Sage means good, gold means needs attention.
    private func statusCapsule(_ text: String, good: Bool) -> some View {
        let tint = good ? Theme.sage : Theme.gold
        return HStack(spacing: 6) {
            Circle()
                .fill(tint)
                .frame(width: 7, height: 7)
            Text(text)
                .font(.caption)
                .foregroundStyle(Theme.charcoal.opacity(0.75))
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(
            Capsule().fill(tint.opacity(0.12))
        )
        .overlay(
            Capsule().strokeBorder(tint.opacity(0.35), lineWidth: 1)
        )
    }

    /// A labelled control row (picker or toggle) that picks up a soft cream
    /// highlight on hover, so the interactive area reads as a single unit.
    private func controlRow<Content: View>(_ label: String,
                                           @ViewBuilder _ content: () -> Content) -> some View {
        HoverHighlightRow(
            VStack(alignment: .leading, spacing: 5) {
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.charcoal.opacity(0.85))
                content()
            }
        )
    }

    /// Transient "Saved" confirmation shown next to a save button. Fades in and
    /// out and only appears when `visible`, so callers gate it on no validation
    /// error having fired.
    private func savedBadge(_ visible: Bool) -> some View {
        Label("Saved", systemImage: "checkmark.circle.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(Theme.sage)
            .symbolEffect(.bounce, value: visible)
            .opacity(visible ? 1 : 0)
            .scaleEffect(visible ? 1 : 0.92)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: visible)
    }

    // MARK: - Cards

    private var azureCard: some View {
        card("Azure OpenAI / Foundry", icon: "cloud") {
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
                savedBadge(saved && rateError.isEmpty)
            }
        }
    }

    private var formattingCard: some View {
        card("Smart formatting", icon: "wand.and.stars") {
            Toggle("Format dictations with GPT", isOn: $formattingEnabled)
                .tint(Theme.navy)
                // Write through immediately, same as the menu-bar toggle. Save
                // must not write this back, or a menu toggle made while this
                // page sits open would be silently reverted.
                .onChange(of: formattingEnabled) { _, isOn in
                    settings.formattingEnabled = isOn
                }
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

    private var promptModeCard: some View {
        card("Prompt mode", icon: "wand.and.stars") {
            Toggle("Optimize dictations into prompts in coding apps", isOn: $promptModeEnabled)
                .tint(Theme.navy)
                // Write through immediately; see the formatting toggle above.
                .onChange(of: promptModeEnabled) { _, isOn in
                    settings.promptModeEnabled = isOn
                }
            VStack(alignment: .leading, spacing: 5) {
                Text("Default target model")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.charcoal.opacity(0.85))
                Picker("", selection: $promptModeTarget) {
                    ForEach(ModelPackID.allCases, id: \.self) { id in
                        Text(id.displayName).tag(id)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            hint("Say \"this is for GPT\" or \"for Gemini\" at the start or end of a dictation to override the default for that one prompt.")
            VStack(alignment: .leading, spacing: 5) {
                Text("Apps (one bundle id per line)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.charcoal.opacity(0.85))
                TextEditor(text: $promptModeApps)
                    .frame(minHeight: 90)
                    .font(.system(size: 12, design: .monospaced))
                    .padding(6)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(Theme.charcoal.opacity(0.2), lineWidth: 1))
            }
            hint("Prompt mode only runs in these apps. Everywhere else, dictations use smart formatting.")
            field("Prompt deployment", "gpt-4o", $promptModeDeployment)
            hint("Leave empty to use the formatting deployment.")
            Button("Open packs folder") { openPacksFolder() }
                .buttonStyle(SettingsBorderedButtonStyle())
            if !packsError.isEmpty {
                Text(packsError).font(.caption).foregroundStyle(.red)
            }
            hint("The model packs are editable markdown. Edit a file to change how prompts are written for that model.")
        }
    }

    private func openPacksFolder() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory,
                                           in: .userDomainMask)[0]
            .appendingPathComponent("Sadaa")
            .appendingPathComponent("ModelPacks")
        do {
            try ModelPackLibrary.seedOverrides(into: dir)
            packsError = ""
        } catch {
            packsError = "Couldn't create the packs folder: \(error.localizedDescription)"
            return
        }
        NSWorkspace.shared.open(dir)
    }

    private var fallbackCard: some View {
        card("Fallback providers (optional)", icon: "arrow.triangle.branch") {
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

    private var languageCard: some View {
        card("Language", icon: "globe") {
            controlRow("Dictation language") {
                Picker("", selection: languageBinding) {
                    ForEach(LanguagePin.allCases, id: \.self) { pin in
                        Text(PageFormat.languageLabel(pin)).tag(pin)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            hint("Also available from the menu-bar icon. Auto-detect handles most cases; pin English or German if you switch a lot.")
        }
    }

    private var costCard: some View {
        card("Usage and cost", icon: "chart.bar") {
            hint("This month: \(PageFormat.minutes(viewModel.monthlyCost.minutes)), about \(PageFormat.dollars(viewModel.monthlyCost.cost)). An estimate for credit awareness.")
            field("Transcription rate ($/min)", "0.006", $transcriptionRate)
            field("Formatter rate ($/1k chars)", "0.002", $formatterRate)
            if !rateError.isEmpty {
                Text(rateError).font(.caption).foregroundStyle(.red)
            }
        }
    }

    private var hotkeyCard: some View {
        card("Hotkeys", icon: "keyboard") {
            controlRow("Dictation key (tap to start and stop dictation)") {
                Picker("", selection: hotkeyBinding) {
                    ForEach(HotkeyOption.all) { option in
                        Text(option.label).tag(option.keycode)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(maxWidth: 240, alignment: .leading)
            }
            controlRow("Voice-edit key (tap to rewrite the selected text by voice)") {
                Picker("", selection: voiceEditBinding) {
                    ForEach(HotkeyOption.all) { option in
                        Text(option.label).tag(option.keycode)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(maxWidth: 240, alignment: .leading)
            }
            statusCapsule(viewModel.hotkeyActive
                          ? "Hotkeys are active."
                          : "Hotkeys are not active. Grant Accessibility below.",
                          good: viewModel.hotkeyActive)
            hint("Pick two different keys. To voice-edit: select some text, tap \(HotkeyOption.label(for: viewModel.voiceEditKeycode)), speak your instruction (\"make it formal\", \"fix the grammar\"), then tap the key again. Cancel any recording with Esc.")
        }
    }

    private var generalCard: some View {
        card("General", icon: "gearshape") {
            Toggle("Launch Sadaa at login", isOn: $launchAtLogin)
                .tint(Theme.navy)
            if !launchError.isEmpty {
                Text(launchError).font(.caption).foregroundStyle(.red)
            }
            Toggle("Play a soft chime when dictation starts and stops", isOn: $soundEffects)
                .tint(Theme.navy)
            HStack(spacing: 10) {
                Button("Apply") { save() }
                    .buttonStyle(SettingsBorderedButtonStyle())
                savedBadge(saved && launchError.isEmpty && rateError.isEmpty)
            }
        }
    }

    private var permissionsCard: some View {
        card("Permissions", icon: "lock.shield") {
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

    private var voiceEditBinding: Binding<Int> {
        Binding(
            get: { viewModel.voiceEditKeycode },
            set: { viewModel.setVoiceEditKeycode($0) }
        )
    }

    // MARK: - Permissions

    private func permissionRow(title: String, granted: Bool, pane: String) -> some View {
        HStack(spacing: 10) {
            Text(title).foregroundStyle(Theme.charcoal)
            statusCapsule(granted ? "Granted" : "Needed", good: granted)
            Spacer()
            if !granted {
                Button("Open Settings") { openPrivacyPane(pane) }
                    .buttonStyle(SettingsBorderedButtonStyle())
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
        promptModeEnabled = settings.promptModeEnabled
        promptModeTarget = settings.promptModeDefaultTarget
        promptModeApps = settings.promptModeApps.joined(separator: "\n")
        promptModeDeployment = settings.promptModeDeployment
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
        soundEffects = settings.soundEffectsEnabled
        refreshPermissions()
    }

    private func save() {
        settings.azureEndpoint = endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        settings.azureDeployment = deployment.trimmingCharacters(in: .whitespacesAndNewlines)
        // A blank API version would persist an empty string and break every
        // request; keep the stored value instead (the field re-syncs below).
        let trimmedAPIVersion = apiVersion.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedAPIVersion.isEmpty { settings.azureAPIVersion = trimmedAPIVersion }
        saveKey(apiKey, account: "azure-openai-key")
        // formattingEnabled / promptModeEnabled write through from their
        // toggles, so a menu-bar toggle made while this page is open survives.
        settings.gptDeployment = gptDeployment.trimmingCharacters(in: .whitespacesAndNewlines)
        settings.promptModeDefaultTarget = promptModeTarget
        settings.promptModeApps = promptModeApps
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        settings.promptModeDeployment = promptModeDeployment.trimmingCharacters(in: .whitespacesAndNewlines)
        settings.speakerContext = speakerContext
        settings.soundEffectsEnabled = soundEffects

        settings.openaiEnabled = openaiEnabled
        // Same guard as the Azure fields: never persist an empty model.
        let trimmedOpenAIModel = openaiModel.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedOpenAIModel.isEmpty { settings.openaiModel = trimmedOpenAIModel }
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

        // Re-sync every field from what was actually stored, so a blanked
        // box whose old value was kept (API version, models, rates) shows
        // that value again instead of sitting empty under a green Saved badge.
        load()

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

/// Wraps a control row in a soft cream highlight that fades in on hover.
private struct HoverHighlightRow<Content: View>: View {
    let content: Content
    @State private var hovering = false

    init(_ content: Content) {
        self.content = content
    }

    var body: some View {
        content
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 9)
                    .fill(Theme.cream.opacity(hovering ? 0.8 : 0))
            )
            .contentShape(RoundedRectangle(cornerRadius: 9))
            .onHover { hovering = $0 }
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: hovering)
    }
}

/// Bordered, navy-tinted secondary button with hover and pressed feedback.
/// Used for the non-primary actions on the page so they feel consistent.
private struct SettingsBorderedButtonStyle: ButtonStyle {
    @State private var hovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Theme.navy)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Theme.navy.opacity(hovering ? 0.1 : 0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Theme.navy.opacity(hovering ? 0.45 : 0.25), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .onHover { hovering = $0 }
            .animation(.spring(response: 0.3, dampingFraction: 0.8),
                       value: configuration.isPressed)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: hovering)
    }
}

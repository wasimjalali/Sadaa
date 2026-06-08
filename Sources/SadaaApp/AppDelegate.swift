import AppKit
import AVFoundation
import ApplicationServices
import Carbon.HIToolbox
import SadaaCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private let settings = AppSettings()
    private let hotkeys = HotkeyManager()
    private let hud = HUDPanel()
    private let inserter = TextInserter()
    private let mainWindow = MainWindowController()
    private var viewModel: SadaaViewModel?
    private var history: DictationHistory?
    private var dictionary: DictionaryStore?
    private var snippets: SnippetStore?
    private var notes: NotesStore?
    private var controller: DictationController?
    private var voiceEditController: VoiceEditController?
    private var recordingTimer: Timer?
    private var recordingSeconds = 0
    private var currentLevel: Float = 0
    private var axPollTimer: Timer?

    /// A dictation is mid-flight (recording or processing).
    private var isDictationBusy: Bool {
        switch controller?.state {
        case .recording, .transcribing, .delivering: return true
        default: return false
        }
    }
    /// A voice edit is mid-flight (recording or rewriting).
    private var isVoiceEditBusy: Bool {
        switch voiceEditController?.state {
        case .recording, .rewriting: return true
        default: return false
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        setUpStatusItem()
        setUpController()
        requestPermissions()
        startHotkeys()
        if let viewModel {
            mainWindow.show(viewModel: viewModel, settings: settings)
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication,
                                       hasVisibleWindows flag: Bool) -> Bool {
        openMainWindow()
        return true
    }

    // MARK: - Wiring

    private func setUpController() {
        let recorder = AudioRecorder(silenceTimeout: settings.silenceTimeout)
        recorder.onLevel = { [weak self] level in
            DispatchQueue.main.async { self?.currentLevel = level }
        }
        let sadaaDir = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Sadaa")
        let appSupport = sadaaDir.appendingPathComponent("Recordings")
        guard let store = try? RecordingStore(directory: appSupport) else {
            fatalError("Cannot create recordings directory at \(appSupport.path)")
        }

        try? FileManager.default.createDirectory(
            at: sadaaDir, withIntermediateDirectories: true)
        let history = DictationHistory(
            fileURL: sadaaDir.appendingPathComponent("history.json"))
        self.history = history

        let dictionary = DictionaryStore(
            fileURL: sadaaDir.appendingPathComponent("dictionary.json"))
        self.dictionary = dictionary

        let snippets = SnippetStore(
            fileURL: sadaaDir.appendingPathComponent("snippets.json"))
        self.snippets = snippets

        let notes = NotesStore(
            fileURL: sadaaDir.appendingPathComponent("notes.json"))
        self.notes = notes

        let viewModel = SadaaViewModel(
            settings: settings,
            history: history,
            dictionary: dictionary,
            snippets: snippets,
            notes: notes,
            onToggle: { [weak self] in self?.controller?.toggle() })
        self.viewModel = viewModel

        let controller = DictationController(
            recorder: recorder,
            providers: { [settings] in Self.buildProviders(settings: settings) },
            store: store,
            hint: { [settings, dictionary] in
                TranscriptionHint(languagePin: settings.languagePin,
                                  dictionaryWords: dictionary.biasList(budget: 50))
            },
            recordingsToKeep: settings.recordingsToKeep,
            deliver: { [weak self] text in
                let outcome = self?.inserter.deliver(text)
                if outcome == .clipboardOnly {
                    self?.hud.show(.error("Copied. Press Cmd-V to paste."))
                    self?.hud.hide(after: 4)
                }
            },
            record: { [weak self] record in
                guard let self else { return }
                let cost = CostEstimator.estimate(
                    durationSeconds: record.durationSeconds,
                    transcriptionRatePerMinute: self.settings.transcriptionRatePerMinute,
                    characters: record.text.count,
                    formatterRatePer1kChars: self.settings.formatterRatePer1kChars)
                self.history?.append(record.withEstimatedCost(cost))
                self.viewModel?.refreshRecent()
                self.viewModel?.refreshCost()
            },
            format: { [settings] raw, ctx in
                // Rebuilt per dictation so toggling formatting or editing the
                // GPT deployment applies immediately, with no relaunch. When
                // unconfigured we hand back the raw text unchanged.
                guard let formatter = Self.buildFormatter(settings: settings) else {
                    return FormattingResult(text: raw, newTerms: [])
                }
                return try await formatter.format(rawTranscript: raw, context: ctx)
            },
            context: { [settings, dictionary, snippets] in
                FormattingContext(
                    appBundleID: NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
                    dictionaryWords: dictionary.biasList(budget: 50),
                    speakerContext: settings.speakerContext,
                    language: settings.languagePin,
                    snippets: snippets.all())
            },
            suggestTerms: { [weak self] terms in
                self?.dictionary?.suggest(terms)
                self?.viewModel?.refreshDictionary()
            },
            formatterFellBack: { [weak self] in
                self?.hud.show(.error("Inserted raw text (formatter offline)."))
                self?.hud.hide(after: 4)
            },
            servedByFallback: { [weak self] name in
                self?.hud.show(.error("Used \(name). Your primary provider was unavailable."))
                self?.hud.hide(after: 4)
            },
            isSecureInputActive: { IsSecureEventInputEnabled() }
        )
        controller.onStateChange = { [weak self] state in
            self?.render(state: state)
            self?.viewModel?.refreshState(state)
            self?.viewModel?.canRetry = self?.controller?.canRetry ?? false
        }
        viewModel.onRetry = { [weak self] in self?.controller?.retryLast() }
        self.controller = controller

        // Voice edit gets its own recordings folder so its retention never
        // competes with dictation's.
        let voiceEditStore = (try? RecordingStore(
            directory: sadaaDir.appendingPathComponent("VoiceEditRecordings"))) ?? store
        setUpVoiceEdit(store: voiceEditStore, dictionary: dictionary, snippets: snippets)
    }

    /// Voice edit gets its own recorder so it never fights the dictation flow.
    /// The formatter is resolved per use so configuring GPT later works without
    /// a relaunch; the rewrite throws a clear error when it is not configured.
    private func setUpVoiceEdit(store: RecordingStore,
                                dictionary: DictionaryStore,
                                snippets: SnippetStore) {
        let recorder = AudioRecorder(silenceTimeout: settings.silenceTimeout)
        let controller = VoiceEditController(
            recorder: recorder,
            providers: { [settings] in Self.buildProviders(settings: settings) },
            store: store,
            hint: { [settings, dictionary] in
                TranscriptionHint(languagePin: settings.languagePin,
                                  dictionaryWords: dictionary.biasList(budget: 50))
            },
            readSelection: { Self.readSelection() },
            rewrite: { [settings, dictionary, snippets] selection, instruction in
                guard let formatter = Self.buildFormatter(settings: settings) else {
                    throw ProviderError.notConfigured(
                        "Set a GPT deployment in Settings to use voice edit.")
                }
                let context = FormattingContext(
                    appBundleID: NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
                    dictionaryWords: dictionary.biasList(budget: 50),
                    speakerContext: settings.speakerContext,
                    language: settings.languagePin,
                    snippets: snippets.all())
                return try await formatter.rewrite(selection: selection,
                                                   instruction: instruction,
                                                   context: context)
            },
            replace: { [weak self] edited in _ = self?.inserter.deliver(edited) })
        controller.onStateChange = { [weak self] state in
            self?.renderVoiceEdit(state)
        }
        self.voiceEditController = controller
    }

    /// Reads the current selection: Accessibility first, then a Cmd-C fallback
    /// for the apps where AX returns nothing (Terminal, VS Code, browsers).
    private static func readSelection() -> String? {
        if let viaAX = readSelectionViaAX() { return viaAX }
        return readSelectionViaCopy()
    }

    private static func readSelectionViaAX() -> String? {
        guard AXIsProcessTrusted() else { return nil }
        let systemWide = AXUIElementCreateSystemWide()
        var focusedRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
                systemWide, kAXFocusedUIElementAttribute as CFString, &focusedRef) == .success,
              let focusedRef,
              CFGetTypeID(focusedRef) == AXUIElementGetTypeID() else { return nil }
        let element = focusedRef as! AXUIElement
        var selRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
                element, kAXSelectedTextAttribute as CFString, &selRef) == .success,
              let text = selRef as? String, !text.isEmpty else { return nil }
        return text
    }

    /// Copies the selection via a synthetic Cmd-C and reads it back, restoring
    /// the user's clipboard afterwards. The brief bounded wait runs on the
    /// user-initiated voice-edit start, not on any audio path.
    private static func readSelectionViaCopy() -> String? {
        guard AXIsProcessTrusted() else { return nil }
        let pasteboard = NSPasteboard.general
        let saved = Clipboard.snapshot(pasteboard)
        let before = pasteboard.changeCount
        guard let source = CGEventSource(stateID: .combinedSessionState),
              let down = CGEvent(keyboardEventSource: source, virtualKey: 8, keyDown: true),  // C
              let up = CGEvent(keyboardEventSource: source, virtualKey: 8, keyDown: false)
        else { return nil }
        down.flags = .maskCommand
        up.flags = .maskCommand
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)

        var copied: String?
        let deadline = Date().addingTimeInterval(0.2)
        while Date() < deadline {
            if pasteboard.changeCount != before {
                copied = pasteboard.string(forType: .string)
                break
            }
            usleep(10_000)   // 10ms
        }
        Clipboard.restore(saved, to: pasteboard)
        let trimmed = copied?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (trimmed?.isEmpty == false) ? copied : nil
    }

    /// The fallback chain, in order: Azure OpenAI, then OpenAI, then MAI. Each
    /// link is included only when configured. Spec section 3.5.
    private static func buildProviders(settings: AppSettings)
        -> [TranscriptionProvider] {
        var chain: [TranscriptionProvider] = []

        if let endpoint = URL(string: settings.azureEndpoint),
           !settings.azureEndpoint.isEmpty,
           !settings.azureDeployment.isEmpty,
           let key = Keychain.get(account: "azure-openai-key") {
            chain.append(AzureOpenAIProvider(config: .init(
                endpoint: endpoint, apiKey: key,
                deployment: settings.azureDeployment,
                apiVersion: settings.azureAPIVersion)))
        }

        if settings.openaiEnabled,
           let key = Keychain.get(account: "openai-key"), !key.isEmpty {
            chain.append(OpenAIProvider(config: .init(
                apiKey: key, model: settings.openaiModel)))
        }

        if settings.maiEnabled,
           let endpoint = URL(string: settings.maiEndpoint),
           !settings.maiEndpoint.isEmpty,
           let key = Keychain.get(account: "azure-speech-key"), !key.isEmpty {
            chain.append(AzureSpeechProvider(config: .init(
                endpoint: endpoint, apiKey: key,
                apiVersion: settings.maiApiVersion,
                model: settings.maiModel)))
        }

        return chain
    }

    /// Builds the smart formatter from settings, or nil when formatting is off
    /// or unconfigured (in which case dictations are delivered raw).
    private static func buildFormatter(settings: AppSettings) -> AzureChatFormatter? {
        guard settings.formattingEnabled,
              !settings.gptDeployment.isEmpty,
              let endpoint = URL(string: settings.azureEndpoint),
              !settings.azureEndpoint.isEmpty,
              let key = Keychain.get(account: "azure-openai-key")
        else { return nil }
        let config = AzureChatFormatter.Config(
            endpoint: endpoint, apiKey: key,
            deployment: settings.gptDeployment,
            apiVersion: settings.azureAPIVersion)
        return AzureChatFormatter(config: config)
    }

    private func startHotkeys() {
        hotkeys.activationKeycode = Int64(settings.hotkeyKeycode)
        viewModel?.onHotkeyKeycodeChange = { [weak self] code in
            self?.hotkeys.activationKeycode = Int64(code)
        }
        hotkeys.onToggle = { [weak self] in
            guard let self else { return }
            // Don't start a dictation while a voice edit is mid-flight.
            guard !self.isVoiceEditBusy else {
                self.hud.show(.error("Finish the voice edit first."))
                self.hud.hide(after: 3)
                return
            }
            let raw = NSEvent.modifierFlags.contains(.shift)
            self.controller?.toggle(rawMode: raw)
        }
        hotkeys.onCancel = { [weak self] in
            // Route Esc to whichever flow is actually recording.
            if self?.controller?.state == .recording {
                self?.controller?.cancel()
            } else if self?.voiceEditController?.state == .recording {
                self?.voiceEditController?.cancel()
            }
        }
        hotkeys.onVoiceEdit = { [weak self] in
            guard let self else { return }
            // Don't start a voice edit while a dictation is mid-flight.
            guard !self.isDictationBusy else {
                self.hud.show(.error("Finish dictating first."))
                self.hud.hide(after: 3)
                return
            }
            guard Self.buildFormatter(settings: self.settings) != nil else {
                self.hud.show(.error("Set a GPT deployment in Settings to use voice edit."))
                self.hud.hide(after: 5)
                return
            }
            self.voiceEditController?.toggle()
        }
        hotkeys.isRecordingActive = { [weak self] in
            self?.controller?.state == .recording
                || self?.voiceEditController?.state == .recording
        }

        // Gate on real trust first. CGEvent.tapCreate returns a non-nil but
        // DEAD tap when the process is not Accessibility-trusted, so checking
        // tap != nil is not enough - we would early-return and never start the
        // poll, leaving the hotkey dead until a full relaunch.
        if AXIsProcessTrusted() && tryStartHotkeys() { return }

        // Not Accessibility-trusted yet. Poll until the user grants it, then
        // start the tap without requiring a relaunch.
        hud.show(.error("Enable Accessibility for Sadaa in System Settings to use the hotkey."))
        hud.hide(after: 6)
        axPollTimer?.invalidate()
        axPollTimer = Timer.scheduledTimer(withTimeInterval: 2.0,
                                           repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                guard AXIsProcessTrusted() else { return }
                if self.tryStartHotkeys() {
                    self.axPollTimer?.invalidate()
                    self.axPollTimer = nil
                }
            }
        }
    }

    /// Attempts to start the global hotkey tap. Returns true on success, and
    /// publishes the active state so the Settings UI reflects reality.
    @discardableResult
    private func tryStartHotkeys() -> Bool {
        do {
            try hotkeys.start()
            viewModel?.hotkeyActive = true
            return true
        } catch {
            viewModel?.hotkeyActive = false
            return false
        }
    }

    // MARK: - State rendering

    private func render(state: DictationState) {
        switch state {
        case .idle:
            stopRecordingTimer()
            setIcon("waveform", tint: nil)
            hud.hide(after: 0.4)
        case .recording:
            startRecordingTimer()
            setIcon("record.circle.fill", tint: .systemRed)
        case .transcribing:
            stopRecordingTimer()
            setIcon("waveform", tint: .systemOrange)
            hud.show(.transcribing)
        case .delivering:
            hud.show(.delivering)
        case .error(let message):
            stopRecordingTimer()
            setIcon("waveform", tint: nil)
            hud.show(.error(message))
            hud.hide(after: 6)
        }
    }

    private func renderVoiceEdit(_ state: VoiceEditState) {
        switch state {
        case .idle:
            setIcon("waveform", tint: nil)
            hud.hide(after: 0.4)
        case .recording:
            setIcon("pencil", tint: .systemRed)
            hud.show(.recording(seconds: 0, level: 0))
        case .rewriting:
            setIcon("waveform", tint: .systemOrange)
            hud.show(.transcribing)
        case .error(let message):
            setIcon("waveform", tint: nil)
            hud.show(.error(message))
            hud.hide(after: 6)
        }
    }

    private func startRecordingTimer() {
        recordingSeconds = 0
        hud.show(.recording(seconds: 0, level: 0))
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1,
                                              repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.recordingSeconds += 1
                self.hud.show(.recording(seconds: self.recordingSeconds / 10,
                                         level: self.currentLevel))
            }
        }
    }

    private func stopRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
    }

    private func setIcon(_ symbol: String, tint: NSColor?) {
        let image = NSImage(systemSymbolName: symbol,
                            accessibilityDescription: "Sadaa")
        image?.isTemplate = (tint == nil)
        statusItem?.button?.image = image
        statusItem?.button?.contentTintColor = tint
    }

    // MARK: - Status item and menu

    private func setUpStatusItem() {
        let item = NSStatusBar.system.statusItem(
            withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "waveform",
                                     accessibilityDescription: "Sadaa")
        let menu = NSMenu()

        let openItem = NSMenuItem(title: "Open Sadaa",
                                  action: #selector(openMainWindow),
                                  keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)
        menu.addItem(.separator())

        let toggleItem = NSMenuItem(title: "Start/Stop Dictation",
                                    action: #selector(menuToggle),
                                    keyEquivalent: "")
        toggleItem.target = self
        menu.addItem(toggleItem)
        menu.addItem(.separator())

        let languageMenu = NSMenu()
        for pin in LanguagePin.allCases {
            let title = ["auto": "Auto-detect", "en": "English",
                         "de": "German"][pin.rawValue]!
            let item = NSMenuItem(title: title,
                                  action: #selector(setLanguage(_:)),
                                  keyEquivalent: "")
            item.target = self
            item.representedObject = pin.rawValue
            item.state = settings.languagePin == pin ? .on : .off
            languageMenu.addItem(item)
        }
        let languageItem = NSMenuItem(title: "Language",
                                      action: nil, keyEquivalent: "")
        menu.setSubmenu(languageMenu, for: languageItem)
        menu.addItem(languageItem)

        let settingsItem = NSMenuItem(title: "Settings…",
                                      action: #selector(openMainWindow),
                                      keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Sadaa",
                                action: #selector(NSApplication.terminate(_:)),
                                keyEquivalent: "q"))
        item.menu = menu
        statusItem = item
    }

    @objc private func menuToggle() {
        controller?.toggle()
    }

    @objc private func setLanguage(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let pin = LanguagePin(rawValue: raw) else { return }
        settings.languagePin = pin
        sender.menu?.items.forEach { $0.state = .off }
        sender.state = .on
        viewModel?.refreshConfig()   // keep Home + Settings in sync with the menu
    }

    @objc private func openMainWindow() {
        if let viewModel {
            mainWindow.show(viewModel: viewModel, settings: settings)
        }
    }

    // MARK: - Permissions

    private func requestPermissions() {
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            if !granted {
                DispatchQueue.main.async { [weak self] in
                    self?.hud.show(.error(
                        "Enable Microphone for Sadaa in System Settings."))
                    self?.hud.hide(after: 6)
                }
            }
        }
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue()
                       as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }
}

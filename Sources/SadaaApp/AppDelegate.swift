import AppKit
import AVFoundation
import ApplicationServices
import Carbon.HIToolbox
import SadaaCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem?
    private var formattingMenuItem: NSMenuItem?
    private var promptModeMenuItem: NSMenuItem?
    private let settings = AppSettings()
    private let hotkeys = HotkeyManager()
    private let hud = HUDPanel()
    private let chimes = ChimePlayer()
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
    /// A fallback notice (formatter offline, optimizer failed) to surface once
    /// the dictation lands. Shown from render(.idle): showing it earlier is
    /// useless because the delivering/idle transitions repaint the HUD within
    /// milliseconds and the message is never seen.
    private var pendingDeliveryNotice: String?
    /// Previous dictation state, so the stop chime only plays when a recording
    /// actually ended (retryLast jumps straight to .transcribing).
    private var lastDictationState: DictationState = .idle

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

    /// Every way to start a dictation funnels through here, so the voice-edit
    /// mutex holds for the hotkey, the menu item, the mic button AND retry.
    /// Two live recorders would fight over the mic, the shared recording timer
    /// and the status icon.
    private func toggleDictation(rawMode: Bool = false) {
        guard !isVoiceEditBusy else {
            hud.show(.error("Finish the voice edit first."))
            hud.hide(after: 3)
            return
        }
        controller?.toggle(rawMode: rawMode)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        installMainMenu()
        chimes.isEnabled = { [settings] in settings.soundEffectsEnabled }
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

    /// Sadaa is an accessory app, so no menu bar is visible, but AppKit still
    /// routes key equivalents through NSApp.mainMenu. Without an Edit menu,
    /// Cmd-V (the user's or TextInserter's synthetic one) dies inside Sadaa's
    /// own windows, so dictating into the Notes page lost the text.
    private func installMainMenu() {
        let mainMenu = NSMenu()

        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Quit Sadaa",
                        action: #selector(NSApplication.terminate(_:)),
                        keyEquivalent: "q")
        appItem.submenu = appMenu
        mainMenu.addItem(appItem)

        let editItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo",
                         action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo",
                         action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut",
                         action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy",
                         action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste",
                         action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All",
                         action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = editMenu
        mainMenu.addItem(editItem)

        NSApp.mainMenu = mainMenu
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
            onToggle: { [weak self] in self?.toggleDictation() })
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
                self?.inserter.deliver(text) { outcome in
                    if outcome == .clipboardOnly {
                        self?.hud.show(.error("Copied. Press Cmd-V to paste."))
                        self?.hud.hide(after: 4)
                    }
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
            format: { [weak self, settings] raw, ctx in
                // Rebuilt per dictation so toggling formatting or editing the
                // GPT deployment applies immediately, with no relaunch. When
                // unconfigured we hand back the raw text unchanged.
                // Prompt Mode: in the listed coding and chatbot apps, rewrite
                // the dictation into an optimized prompt for the target model
                // instead of just cleaning it up. The target can be named by
                // voice; otherwise the app implies it (Claude desktop means
                // Claude, ChatGPT means GPT) and the settings default is the
                // final fallback. Smart formatting stays the master switch:
                // when it's off, no GPT touches the dictation, Prompt Mode
                // included, exactly as the menu copy promises.
                if settings.formattingEnabled,
                   settings.promptModeEnabled,
                   let bundle = ctx.appBundleID,
                   settings.promptModeApps.contains(bundle),
                   let formatter = Self.buildPromptModeFormatter(settings: settings) {
                    let target = ModelPackResolver.resolve(
                        transcript: raw,
                        defaultTarget: ModelPackResolver.appImpliedTarget(bundleID: bundle)
                            ?? settings.promptModeDefaultTarget)
                    let pack = ModelPackLibrary.pack(
                        for: target, overridesDirectory: Self.modelPacksDirectory())
                    await MainActor.run { self?.hud.show(.optimizing(target: target.displayName)) }
                    do {
                        return try await formatter.optimize(
                            rawTranscript: raw, context: ctx, pack: pack)
                    } catch {
                        // Optimizer failure means raw text, with its own notice:
                        // "formatter offline" here would misdirect any debugging.
                        await MainActor.run {
                            self?.pendingDeliveryNotice =
                                "Inserted raw text (prompt optimizer failed)."
                        }
                        return FormattingResult(text: raw, newTerms: [], mode: .raw)
                    }
                }
                guard let formatter = Self.buildFormatter(settings: settings) else {
                    return FormattingResult(text: raw, newTerms: [], mode: .raw)
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
                self?.pendingDeliveryNotice = "Inserted raw text (formatter offline)."
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
        viewModel.onRetry = { [weak self] in
            guard let self else { return }
            // Same mutex as starting a dictation: retry transcribes and delivers.
            guard !self.isVoiceEditBusy else {
                self.hud.show(.error("Finish the voice edit first."))
                self.hud.hide(after: 3)
                return
            }
            self.controller?.retryLast()
        }
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
        // Feed the HUD's live level meter, same as dictation, so the pill
        // animates while a voice edit is recording.
        recorder.onLevel = { [weak self] level in
            DispatchQueue.main.async { self?.currentLevel = level }
        }
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
            replace: { [weak self] edited in
                self?.inserter.deliver(edited) { outcome in
                    if outcome == .clipboardOnly {
                        self?.hud.show(.error("Copied. Press Cmd-V to paste."))
                        self?.hud.hide(after: 4)
                    }
                }
            })
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

        // Wait for the trigger key to fully release before synthesizing Cmd-C.
        // While Right Option (or any non-command modifier) is still down, the
        // combined session state merges it and Cmd-C becomes Cmd-Option-C,
        // which copies nothing. This is what broke voice-edit in Slack and
        // other Electron/browser apps, where AX gives no selection so the copy
        // fallback is the only path. A fixed delay was a guess; poll the live
        // modifier flags instead so it works no matter how long the key is held.
        waitForTriggerModifiersToClear(timeout: 0.5)

        let before = pasteboard.changeCount
        guard let source = CGEventSource(stateID: .combinedSessionState),
              let down = CGEvent(keyboardEventSource: source, virtualKey: 8, keyDown: true),  // C
              let up = CGEvent(keyboardEventSource: source, virtualKey: 8, keyDown: false)
        else { return nil }
        down.flags = .maskCommand
        up.flags = .maskCommand
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)

        // Wait up to 800ms for the copy to land; some apps (Slack, other
        // Electron, browsers) are slow. The loop breaks as soon as the clipboard
        // changes, so the ceiling only costs time when a copy genuinely fails.
        var copied: String?
        let deadline = Date().addingTimeInterval(0.8)
        while Date() < deadline {
            if pasteboard.changeCount != before {
                copied = pasteboard.string(forType: .string)
                if copied != nil { break }
            }
            usleep(10_000)   // 10ms
        }
        Clipboard.restore(saved, to: pasteboard)
        let trimmed = copied?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (trimmed?.isEmpty == false) ? copied : nil
    }

    /// Blocks until every modifier that could contaminate a synthetic Cmd-C is
    /// released, or the timeout elapses. We tolerate Command (we set it
    /// ourselves) but Option, Control, Shift and Fn would each turn Cmd-C into a
    /// different shortcut that copies nothing. Returns immediately once clear.
    private static func waitForTriggerModifiersToClear(timeout: TimeInterval) {
        let contaminating: CGEventFlags =
            [.maskAlternate, .maskControl, .maskShift, .maskSecondaryFn]
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let flags = CGEventSource.flagsState(.combinedSessionState)
            if flags.intersection(contaminating).isEmpty { return }
            usleep(10_000)   // 10ms
        }
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

    /// Builds the Prompt Mode formatter. Same Azure config as buildFormatter but
    /// uses the Prompt Mode deployment when set, falling back to the formatting
    /// deployment when it is empty. Returns nil when Azure is unconfigured.
    private static func buildPromptModeFormatter(settings: AppSettings) -> AzureChatFormatter? {
        let deployment = settings.promptModeDeployment.isEmpty
            ? settings.gptDeployment : settings.promptModeDeployment
        guard !deployment.isEmpty,
              let endpoint = URL(string: settings.azureEndpoint),
              !settings.azureEndpoint.isEmpty,
              let key = Keychain.get(account: "azure-openai-key")
        else { return nil }
        let config = AzureChatFormatter.Config(
            endpoint: endpoint, apiKey: key,
            deployment: deployment,
            apiVersion: settings.azureAPIVersion)
        return AzureChatFormatter(config: config)
    }

    /// Where user-overridable model packs live: <Application Support>/Sadaa/ModelPacks.
    private static func modelPacksDirectory() -> URL {
        FileManager.default.urls(for: .applicationSupportDirectory,
                                 in: .userDomainMask)[0]
            .appendingPathComponent("Sadaa")
            .appendingPathComponent("ModelPacks")
    }

    private func startHotkeys() {
        hotkeys.activationKeycode = Int64(settings.hotkeyKeycode)
        hotkeys.voiceEditKeycode = Int64(settings.voiceEditKeycode)
        viewModel?.onHotkeyKeycodeChange = { [weak self] code in
            self?.hotkeys.activationKeycode = Int64(code)
        }
        viewModel?.onVoiceEditKeycodeChange = { [weak self] code in
            self?.hotkeys.voiceEditKeycode = Int64(code)
        }
        hotkeys.onToggle = { [weak self] in
            guard let self else { return }
            self.toggleDictation(rawMode: NSEvent.modifierFlags.contains(.shift))
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
        defer { lastDictationState = state }
        switch state {
        case .idle:
            stopRecordingTimer()
            setIcon("waveform", tint: nil)
            if let notice = pendingDeliveryNotice {
                pendingDeliveryNotice = nil
                hud.show(.error(notice))
                hud.hide(after: 4)
            } else {
                hud.hide(after: 0.4)
            }
        case .recording:
            chimes.playStart()
            startRecordingTimer()
            setIcon("record.circle.fill", tint: .systemRed)
        case .transcribing:
            if lastDictationState == .recording { chimes.playStop() }
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
            stopRecordingTimer()
            setIcon("waveform", tint: nil)
            hud.hide(after: 0.4)
        case .recording:
            chimes.playStart()
            setIcon("pencil", tint: .systemRed)
            // Same ticking timer as dictation: the pill shows the running
            // seconds and the live audio level so you can see it is recording.
            startRecordingTimer()
        case .rewriting:
            chimes.playStop()
            stopRecordingTimer()
            setIcon("waveform", tint: .systemOrange)
            hud.show(.transcribing)
        case .error(let message):
            stopRecordingTimer()
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

        // Quick literal-dictation switch. When off, dictations are pure
        // transcription with no GPT in the loop, so they can never take action.
        let formattingItem = NSMenuItem(title: "Smart formatting",
                                        action: #selector(toggleSmartFormatting),
                                        keyEquivalent: "")
        formattingItem.target = self
        formattingItem.state = settings.formattingEnabled ? .on : .off
        menu.addItem(formattingItem)
        formattingMenuItem = formattingItem

        // Prompt mode: in coding apps, rewrite the dictation into an optimized
        // prompt for the target model instead of just cleaning it up.
        let promptModeItem = NSMenuItem(title: "Prompt mode",
                                        action: #selector(togglePromptMode),
                                        keyEquivalent: "")
        promptModeItem.target = self
        promptModeItem.state = settings.promptModeEnabled ? .on : .off
        menu.addItem(promptModeItem)
        promptModeMenuItem = promptModeItem

        let settingsItem = NSMenuItem(title: "Settings…",
                                      action: #selector(openMainWindow),
                                      keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Sadaa",
                                action: #selector(NSApplication.terminate(_:)),
                                keyEquivalent: "q"))
        menu.delegate = self
        item.menu = menu
        statusItem = item
    }

    /// Keep the menu's checkmarks in sync with settings each time it opens, so a
    /// change made on the Settings page is reflected here too.
    func menuWillOpen(_ menu: NSMenu) {
        formattingMenuItem?.state = settings.formattingEnabled ? .on : .off
        promptModeMenuItem?.state = settings.promptModeEnabled ? .on : .off
    }

    @objc private func menuToggle() {
        toggleDictation()
    }

    @objc private func toggleSmartFormatting() {
        // Off = pure transcription, no GPT, so dictation can never take action.
        // Takes effect on the next dictation (the formatter is built per use).
        settings.formattingEnabled.toggle()
        formattingMenuItem?.state = settings.formattingEnabled ? .on : .off
    }

    @objc private func togglePromptMode() {
        // Takes effect on the next dictation (the formatter is built per use).
        settings.promptModeEnabled.toggle()
        promptModeMenuItem?.state = settings.promptModeEnabled ? .on : .off
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

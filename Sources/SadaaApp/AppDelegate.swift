import AppKit
import AVFoundation
import SadaaCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private let settings = AppSettings()
    private let hotkeys = HotkeyManager()
    private let hud = HUDPanel()
    private let inserter = TextInserter()
    private let settingsWindow = SettingsWindowController()
    private var controller: DictationController?
    private var recordingTimer: Timer?
    private var recordingSeconds = 0
    private var currentLevel: Float = 0
    private var recordingActive = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        setUpStatusItem()
        setUpController()
        requestPermissions()
        startHotkeys()
    }

    // MARK: - Wiring

    private func setUpController() {
        let recorder = AudioRecorder(silenceTimeout: settings.silenceTimeout)
        recorder.onLevel = { [weak self] level in
            DispatchQueue.main.async { self?.currentLevel = level }
        }
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Sadaa/Recordings")
        guard let store = try? RecordingStore(directory: appSupport) else {
            fatalError("Cannot create recordings directory at \(appSupport.path)")
        }

        let controller = DictationController(
            recorder: recorder,
            providers: { [settings] in Self.buildProviders(settings: settings) },
            store: store,
            hint: { [settings] in
                TranscriptionHint(languagePin: settings.languagePin,
                                  dictionaryWords: [])
            },
            recordingsToKeep: settings.recordingsToKeep,
            deliver: { [weak self] text in
                let outcome = self?.inserter.deliver(text)
                if outcome == .clipboardOnly {
                    self?.hud.show(.error("Copied. Press Cmd-V to paste."))
                    self?.hud.hide(after: 4)
                }
            }
        )
        controller.onStateChange = { [weak self] state in
            self?.render(state: state)
        }
        self.controller = controller
    }

    private static func buildProviders(settings: AppSettings)
        -> [TranscriptionProvider] {
        guard let endpoint = URL(string: settings.azureEndpoint),
              !settings.azureEndpoint.isEmpty,
              !settings.azureDeployment.isEmpty,
              let key = Keychain.get(account: "azure-openai-key")
        else { return [] }
        let config = AzureOpenAIProvider.Config(
            endpoint: endpoint,
            apiKey: key,
            deployment: settings.azureDeployment,
            apiVersion: settings.azureAPIVersion)
        return [AzureOpenAIProvider(config: config)]
    }

    private func startHotkeys() {
        hotkeys.onToggle = { [weak self] in self?.controller?.toggle() }
        hotkeys.onCancel = { [weak self] in self?.controller?.cancel() }
        hotkeys.isRecordingActive = { [weak self] in
            self?.recordingActive ?? false
        }
        do {
            try hotkeys.start()
        } catch {
            hud.show(.error("Enable Accessibility for Sadaa in System Settings."))
            hud.hide(after: 6)
        }
    }

    // MARK: - State rendering

    private func render(state: DictationState) {
        switch state {
        case .idle:
            recordingActive = false
            stopRecordingTimer()
            setIcon("waveform", tint: nil)
            hud.hide(after: 0.4)
        case .recording:
            recordingActive = true
            startRecordingTimer()
            setIcon("record.circle.fill", tint: .systemRed)
        case .transcribing:
            recordingActive = false
            stopRecordingTimer()
            setIcon("waveform", tint: .systemOrange)
            hud.show(.transcribing)
        case .delivering:
            hud.show(.delivering)
        case .error(let message):
            recordingActive = false
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

        let toggleItem = NSMenuItem(title: "Start/Stop Dictation (Right Option)",
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
                                      action: #selector(openSettings),
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
    }

    @objc private func openSettings() {
        settingsWindow.show(settings: settings)
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

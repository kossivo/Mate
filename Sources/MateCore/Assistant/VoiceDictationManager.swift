import Foundation
import Speech
import AVFoundation

@MainActor
public final class VoiceDictationManager: ObservableObject {
    public static let shared = VoiceDictationManager()

    @Published public var isRecording: Bool = false
    @Published public var transcribedText: String = ""
    @Published public var errorMessage: String? = nil

    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    public init() {
        let currentLocale = Locale.current
        if currentLocale.identifier.starts(with: "vi") {
            speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "vi-VN"))
        } else {
            speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US")) ?? SFSpeechRecognizer()
        }
    }

    public func setLocale(identifier: String) {
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: identifier))
    }

    public func toggleRecording(onUpdate: @escaping (String) -> Void) {
        if isRecording {
            stopRecording()
        } else {
            startRecording(onUpdate: onUpdate)
        }
    }

    public func startRecording(onUpdate: @escaping (String) -> Void) {
        guard !isRecording else { return }

        SFSpeechRecognizer.requestAuthorization { [weak self] authStatus in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                guard authStatus == .authorized else {
                    self.errorMessage = "Microphone and speech recognition permission required."
                    return
                }

                #if os(iOS)
                let audioSession = AVAudioSession.sharedInstance()
                do {
                    try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
                    try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
                } catch {
                    self.errorMessage = "Audio session failed: \(error.localizedDescription)"
                    return
                }
                #endif

                do {
                    try self.startAudioEngine(onUpdate: onUpdate)
                    self.isRecording = true
                    self.errorMessage = nil
                } catch {
                    self.errorMessage = "Cannot start recording: \(error.localizedDescription)"
                    self.stopRecording()
                }
            }
        }
    }

    private func startAudioEngine(onUpdate: @escaping (String) -> Void) throws {
        recognitionTask?.cancel()
        recognitionTask = nil

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = false
        self.recognitionRequest = request

        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            throw NSError(domain: "VoiceDictation", code: 1, userInfo: [NSLocalizedDescriptionKey: "Speech recognizer is unavailable."])
        }

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            request.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if let result = result {
                    let text = result.bestTranscription.formattedString
                    self.transcribedText = text
                    onUpdate(text)
                }
                if error != nil || (result?.isFinal ?? false) {
                    self.stopRecording()
                }
            }
        }
    }

    public func stopRecording() {
        guard isRecording else { return }
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        isRecording = false

        #if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        #endif
    }
}

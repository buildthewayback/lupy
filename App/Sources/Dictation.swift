// Lupy macOS shell — push-to-talk dictation with Apple's Speech framework.
// No local model is downloaded or run by Lupy. The transcript is always shown for review
// before anything is sent. When the Mac supports it, recognition stays on-device.

import AVFoundation
import Observation
import Speech

@MainActor
@Observable
final class DictationController {
    var isRecording = false
    var transcript = ""
    var error: String?
    var onDevice = false

    private let audio = AVAudioEngine()
    @ObservationIgnored private var request: SFSpeechAudioBufferRecognitionRequest?
    @ObservationIgnored private var task: SFSpeechRecognitionTask?
    private let recognizer = SFSpeechRecognizer(locale: Locale.current) ?? SFSpeechRecognizer(locale: Locale(identifier: "en-US"))

    var privacyNote: String {
        onDevice ? "Recognition happens on this Mac." : "Your Mac sends the audio to Apple for recognition (on-device recognition is not available for this language)."
    }

    func toggle() { isRecording ? stop() : start() }

    func start() {
        error = nil
        SFSpeechRecognizer.requestAuthorization { status in
            Task { @MainActor in
                guard status == .authorized else {
                    self.error = "Speech recognition is not allowed. Enable it in System Settings → Privacy & Security → Speech Recognition."
                    return
                }
                self.begin()
            }
        }
    }

    private func begin() {
        guard let recognizer, recognizer.isAvailable else {
            error = "Speech recognition is not available right now."
            return
        }
        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        onDevice = recognizer.supportsOnDeviceRecognition
        if onDevice { req.requiresOnDeviceRecognition = true }
        let input = audio.inputNode
        let format = input.outputFormat(forBus: 0)
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            req.append(buffer)
        }
        audio.prepare()
        do {
            try audio.start()
        } catch {
            self.error = "The microphone is unavailable: \(error.localizedDescription)"
            input.removeTap(onBus: 0)
            return
        }
        request = req
        transcript = ""
        isRecording = true
        task = recognizer.recognitionTask(with: req) { result, err in
            let text = result?.bestTranscription.formattedString
            let isFinal = result?.isFinal ?? false
            Task { @MainActor in
                if let text { self.transcript = text }
                if err != nil || isFinal { self.finish() }
            }
        }
    }

    func stop() {
        request?.endAudio()
        finish()
    }

    private func finish() {
        if audio.isRunning { audio.stop() }
        audio.inputNode.removeTap(onBus: 0)
        task?.finish()
        task = nil
        request = nil
        isRecording = false
    }
}

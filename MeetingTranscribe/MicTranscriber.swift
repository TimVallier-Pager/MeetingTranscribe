import Foundation
import AVFoundation
import Speech

@MainActor
final class MicTranscriber: ObservableObject {
    @Published var transcript: String = ""
    @Published var status: String = "idle"

    private let engine = AVAudioEngine()
    private var task: SFSpeechRecognitionTask?
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))

    func start(onDeviceOnly: Bool) async throws {
        stop()  // reset any prior run

        status = "authorizing…"
        guard await Self.ensureAuthorization() else {
            status = "speech permission denied"
            throw NSError(domain: "SpeechAuth", code: 1)
        }
        guard let recognizer else {
            status = "unsupported locale"
            throw NSError(domain: "Speech", code: 2)
        }

        let supportsLocal = recognizer.supportsOnDeviceRecognition
        status = "starting (onDeviceOnly=\(onDeviceOnly), supportsLocal=\(supportsLocal))"
        print("[MicTranscriber] supportsOnDeviceRecognition =", supportsLocal)

        // 1) Create request upfront
        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        req.requiresOnDeviceRecognition = onDeviceOnly
        req.taskHint = .dictation

        // 2) Wire mic tap that appends *to this local req*
        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 2048, format: inputFormat) { buffer, _ in
            // (Optional) quick amplitude check:
            // let ch = buffer.format.channelCount
            // if let data = buffer.floatChannelData { print("amp:", data[0][0]) }
            req.append(buffer)
        }

        // 3) Start engine before starting the task
        engine.prepare()
        try engine.start()
        status = "listening… (\(Int(inputFormat.sampleRate)) Hz)"
        print("[MicTranscriber] audioEngine started (format:", inputFormat, ")")

        transcript = ""

        // 4) Start the recognition task
        task = recognizer.recognitionTask(with: req) { [weak self] result, error in
            guard let self else { return }
            if let r = result {
                let text = r.bestTranscription.formattedString
                self.transcript = text
                print("[MicTranscriber] partial:", text)
            }
            if let e = error {
                self.status = "error: \(e.localizedDescription.isEmpty ? String(describing: e) : e.localizedDescription)"
                print("[MicTranscriber] error:", e)
                self.stop()
            } else if result?.isFinal == true {
                self.status = "final"
                self.stop()
            }
        }
    }

    func stop() {
        // End audio to flush the request the canonical way
        if engine.isRunning {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
        }
        task?.cancel()
        task = nil
        status = "stopped"
    }

    private static func ensureAuthorization() async -> Bool {
        if SFSpeechRecognizer.authorizationStatus() == .authorized { return true }
        return await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { st in
                cont.resume(returning: st == .authorized)
            }
        }
    }
}

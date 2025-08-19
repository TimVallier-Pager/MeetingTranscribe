import Foundation
import Speech
import AVFoundation

@MainActor
final class SpeechTranscriber: ObservableObject {
    @Published var transcript: String = ""
    @Published var status: String = "idle"

    private var recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    func start(locale: Locale = .init(identifier: "en-US"), onDeviceOnly: Bool) async throws {
        status = "authorizing…"
        let ok = await Self.ensureAuthorization()
        guard ok else {
            status = "speech permission denied"
            throw NSError(domain: "SpeechAuth", code: 1)
        }

        let rec = SFSpeechRecognizer(locale: locale)
        guard let rec else {
            status = "unsupported locale"
            throw NSError(domain: "Speech", code: 2)
        }

        let supportsLocal = rec.supportsOnDeviceRecognition
        status = "starting (onDeviceOnly=\(onDeviceOnly), supportsLocal=\(supportsLocal))"
        print("[Speech] supportsOnDeviceRecognition = \(supportsLocal)")

        if onDeviceOnly && !supportsLocal {
            status = "on-device not available for locale"
            throw NSError(domain: "Speech", code: 3)
        }

        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        req.requiresOnDeviceRecognition = onDeviceOnly  // false = allow cloud
        // Optional hint—can help streaming stability
        recognizer = rec
        request = req
        transcript = ""
        status = "listening…"

        task = rec.recognitionTask(with: req) { [weak self] result, error in
            guard let self else { return }
            if let r = result {
                let text = r.bestTranscription.formattedString
                self.transcript = text
                print("[Speech] partial:", text)
            }
            if let e = error {
                self.status = "error: \(e.localizedDescription.isEmpty ? String(describing: e) : e.localizedDescription)"
                print("[Speech] error:", e)
                self.stop()
            } else if result?.isFinal == true {
                self.status = "final"
                self.stop()
            }
        }
    }

    func append(_ buffer: AVAudioPCMBuffer, when: AVAudioTime?) {
        // Lightweight heartbeat so we know audio is flowing into Speech
        if buffer.frameLength > 0 {
            // Show a dot “.” every time we append (debug)
            // print(".", terminator: "")
        }
        request?.append(buffer)
    }

    func stop() {
        request?.endAudio()
        task?.cancel()
        task = nil
        request = nil
        status = "stopped"
    }

    private static func ensureAuthorization() async -> Bool {
        if SFSpeechRecognizer.authorizationStatus() == .authorized { return true }
        return await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { status in
                cont.resume(returning: status == .authorized)
            }
        }
    }
}


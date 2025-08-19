import Foundation
import Speech

@MainActor
final class FileSpeechTester: ObservableObject {
    @Published var status: String = "idle"

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var task: SFSpeechRecognitionTask?

    func run(onDeviceOnly: Bool) async {
        status = "authorizing…"
        guard await ensureAuth() else { status = "permission denied"; return }
        guard let rec = recognizer else { status = "unsupported locale"; return }

        if onDeviceOnly && !rec.supportsOnDeviceRecognition {
            status = "on-device not available for this locale"
            return
        }

        // 1) Generate a short test audio file using macOS 'say'
        let tmp = FileManager.default.temporaryDirectory
        let url = tmp.appendingPathComponent("mt_test.aiff")

        do {
            try? FileManager.default.removeItem(at: url)

            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/say")
            p.arguments = ["-o", url.path, "This is a Meeting Transcribe speech test."]

            let errPipe = Pipe()
            p.standardError = errPipe

            try p.run()
            p.waitUntilExit()

            if p.terminationStatus != 0 {
                let err = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                status = "say failed (exit \(p.terminationStatus)): \(err.trimmingCharacters(in: .whitespacesAndNewlines))"
                return
            }
        } catch {
            status = "say failed: \(error.localizedDescription)"
            return
        }

        // 2) Transcribe the file with Apple's Speech
        let req = SFSpeechURLRecognitionRequest(url: url)
        req.requiresOnDeviceRecognition = onDeviceOnly   // false = allow network

        status = "recognizing file… (onDeviceOnly=\(onDeviceOnly))"
        task = rec.recognitionTask(with: req) { [weak self] result, error in
            guard let self else { return }
            if let r = result {
                self.status = "ok: " + r.bestTranscription.formattedString
            }
            if let e = error {
                self.status = "error: " + (e.localizedDescription.isEmpty ? String(describing: e) : e.localizedDescription)
            }
        }
    }

    private func ensureAuth() async -> Bool {
        if SFSpeechRecognizer.authorizationStatus() == .authorized { return true }
        return await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { st in
                cont.resume(returning: st == .authorized)
            }
        }
    }
}

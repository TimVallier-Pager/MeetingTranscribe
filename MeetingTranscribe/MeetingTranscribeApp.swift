import SwiftUI
import AppKit

@main
struct MeetingTranscribeApp: App {
    @StateObject private var fileTester = FileSpeechTester()
    @State private var systemCapture = SystemAudioCapture()
    @State private var isSystemCapturing = false

    @StateObject private var micTranscriber = MicTranscriber()
    @State private var micOnDeviceOnly = false
    @State private var micRunning = false

    var body: some Scene {
        MenuBarExtra("Transcribe", systemImage: "waveform") {
            VStack(alignment: .leading, spacing: 10) {
                Text("Meeting Transcribe").font(.headline)

                // System audio (unchanged)
                Button(isSystemCapturing ? "Stop system audio" : "Start system audio") {
                    Task { @MainActor in
                        if isSystemCapturing {
                            systemCapture.stop()
                            isSystemCapturing = false
                        } else {
                            await systemCapture.start()
                            isSystemCapturing = true
                        }
                    }
                }

                // Mic -> Speech (unified)
                Toggle("On-device only", isOn: $micOnDeviceOnly)

                Button(micRunning ? "Stop mic transcription" : "Start mic transcription") {
                    if micRunning {
                        micTranscriber.stop()
                        micRunning = false
                    } else {
                        Task { @MainActor in
                            do {
                                if isSystemCapturing {  // avoid graph conflicts
                                    systemCapture.stop()
                                    isSystemCapturing = false
                                }
                                try await micTranscriber.start(onDeviceOnly: micOnDeviceOnly) // start unified pipeline
                                micRunning = true
                            } catch {
                                print("[App] mic start error:", error.localizedDescription)
                            }
                        }
                    }
                }

                if micRunning {
                    Text(micTranscriber.status)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Divider()
                    ScrollView {
                        Text(micTranscriber.transcript.isEmpty ? "…listening…" : micTranscriber.transcript)
                            .font(.system(.body, design: .rounded))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 160)
                }
                Button("Run speech test (file)") {
                    Task { @MainActor in
                        // Force non-local for this test
                        await fileTester.run(onDeviceOnly: false)
                    }
                }
                Text(fileTester.status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Divider()
                Button("Quit") { NSApplication.shared.terminate(nil) }
            }
            .padding(12)
            .frame(width: 340)
        }
    }
}

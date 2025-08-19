import Foundation
import AVFoundation

final class MicrophoneCapture {
    private let engine = AVAudioEngine()
    var onBuffer: ((AVAudioPCMBuffer, AVAudioTime?) -> Void)?

    func start() throws {
        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0) // e.g., 48kHz mono on most Macs

        // Remove any old taps, then tap with the *native* format
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 2048, format: inputFormat) { [weak self] buffer, when in
            self?.onBuffer?(buffer, when) // forward to Speech
        }

        try engine.start()
        print("Mic capture: STARTED (format: \(inputFormat))")
    }

    func stop() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        print("Mic capture: STOPPED")
    }
}


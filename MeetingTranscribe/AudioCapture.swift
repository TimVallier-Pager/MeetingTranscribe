//
//  AudioCapture.swift
//  MeetingTranscribe
//
//  Created by Tim Vallier on 8/18/25.
//

import Foundation
import ScreenCaptureKit
import CoreMedia

final class SystemAudioCapture: NSObject, SCStreamOutput {
    private var stream: SCStream?
    private let queue = DispatchQueue(label: "system-audio-capture")

    @MainActor
    func start() async {
        do {
            let shareable = try await SCShareableContent.current
            guard let mainDisplay = shareable.displays.first else {
                print("No displays found")
                return
            }

            // Note: this initializer only takes `display` and `excludingWindows`
            let filter = SCContentFilter(display: mainDisplay, excludingWindows: [])

            let cfg = SCStreamConfiguration()
            cfg.capturesAudio = true

            let stream = SCStream(filter: filter, configuration: cfg, delegate: nil)

            try stream.addStreamOutput(
                self,
                type: SCStreamOutputType.audio,          // be explicit; no `.audio` shorthand
                sampleHandlerQueue: queue
            )

            // ADD THIS LINE (no-op screen output to stop warnings)
            try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: queue)
            
            try await stream.startCapture()
            self.stream = stream
            print("System audio capture: STARTED")
        } catch {
            print("System audio capture error: \(error.localizedDescription)")
        }
    }

    @MainActor
    func stop() {
        guard let stream = stream else { return }
        Task {
            do {
                try stream.removeStreamOutput(self, type: SCStreamOutputType.audio)
                try await stream.stopCapture()
                self.stream = nil
                print("System audio capture: STOPPED")
            } catch {
                print("Stop error: \(error.localizedDescription)")
            }
        }
    }

    // Audio buffers arrive here
    func stream(_ stream: SCStream, didOutputSampleBuffer sbuf: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio else { return }   // ignore screen frames
        print("audio buffer received")
    }
}

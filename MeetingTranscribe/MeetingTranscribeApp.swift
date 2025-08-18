//
//  MeetingTranscribeApp.swift
//  MeetingTranscribe
//
//  Created by Tim Vallier on 8/18/25.
//

import SwiftUI
import AppKit

@main
struct MeetingTranscribeApp: App {
    var body: some Scene {
        MenuBarExtra("Transcribe", systemImage: "waveform") {
            VStack(alignment: .leading, spacing: 10) {
                Text("Meeting Transcribe").font(.headline)
                // (We’ll add Start/Stop controls next step)
                Divider()
                Button("Quit") { NSApplication.shared.terminate(nil) }
            }
            .padding(12)
            .frame(width: 260)
        }
    }
}


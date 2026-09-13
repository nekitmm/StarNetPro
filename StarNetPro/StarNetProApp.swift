//
//  StarNetProApp.swift
//  StarNetPro
//
//  Created by Sunny Ma on 2025/7/30.
//

import SwiftUI

@main
struct StarNetProApp: App {
    @StateObject private var processor = StarNetProcessor()

    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(processor)
                .frame(minWidth: 800, minHeight: 600)
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open Image...") {
                    processor.openImage()
                }
                .keyboardShortcut("o")

                Divider()

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q")
            }

            CommandMenu("Process") {
                Button("Remove Stars") {
                    processor.processImage()
                }
                .keyboardShortcut("r", modifiers: [.command])
                .disabled(processor.isProcessing || processor.inputImage == nil)

                Button("Cancel Processing") {
                    processor.cancelProcessing()
                }
                .keyboardShortcut(".", modifiers: [.command])
                .disabled(!processor.isProcessing)
            }
        }
    }
}

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
                .disabled(!processor.workspaceAvailable || processor.busy)

                Divider()

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q")
            }

            CommandMenu("StarNet2 CLI") {
                Button("Choose Executable…", action: processor.chooseCLI)
                    .disabled(processor.busy)
                Button("Use Automatic Location", action: processor.useAutomaticCLI)
                    .disabled(processor.busy)
            }

            CommandMenu("Process") {
                Button("Remove Stars") {
                    processor.processImage()
                }
                .keyboardShortcut("r", modifiers: [.command])
                .disabled(!processor.canProcess)

                Button("Cancel Processing") {
                    processor.cancelProcessing()
                }
                .keyboardShortcut(".", modifiers: [.command])
                .disabled(!processor.isProcessing)
            }
        }
    }
}

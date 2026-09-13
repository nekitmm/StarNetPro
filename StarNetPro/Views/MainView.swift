//
//  ContentView.swift
//  StarNetPro
//
//  Created by Sunny Ma on 2025/7/30.
//

import SwiftUI

struct MainView: View {
    @EnvironmentObject var processor: StarNetProcessor

    var body: some View {
        NavigationView {
            // 侧边栏
            SidebarView()
                .frame(minWidth: 230, idealWidth: 260, maxWidth: 300)

            // 主内容区
            VStack(alignment: .leading, spacing: 20) {
                // Image Preview区
                ImagePreviewSection()

                // 处理面板
                ProcessingPanel()

                // 日志视图
                LogView(logText: $processor.log)
                    .frame(height: 250)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button(action: processor.openImage) {
                    Label("Open Image", systemImage: "photo")
                }
            }

            ToolbarItem(placement: .automatic) {
                Button(action: processor.processImage) {
                    Label(processor.isProcessing ? "Processing..." : "Start Processing",
                          systemImage: processor.isProcessing ? "stop.fill" : "play.fill")
                }
                .disabled(processor.isProcessing || processor.inputImage == nil)
                .keyboardShortcut("r", modifiers: [.command])
            }
        }
    }
}

// 侧边栏视图
struct SidebarView: View {
    @EnvironmentObject var processor: StarNetProcessor

    var body: some View {
        List {
            Section(header: Text("Settings")) {
                VStack(alignment: .leading, spacing: 15) {
                    HStack {
                        Text("Stride:")
                        Slider(value: Binding(
                            get: { Double(processor.strideValue) },
                            set: { processor.strideValue = Int($0) }
                        ), in: 32...384, step: 32)
                        Text("\(processor.strideValue)")
                            .frame(width: 40)
                    }

                    Text("Smaller strides may reduce artifacts but take longer.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("A stride of 256 is a good starting point.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Toggle("Stars Only", isOn: $processor.maskmode)
                        .toggleStyle(SwitchToggleStyle())

                    Text("Enable to export stars; disable for a starless image.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 5)
            }

            Section(header: Text("Help & Support")) {
                Link("StarNet Documentation", destination: URL(string: "https://www.starnetastro.com/instructions/")!)
                Link("StarNetPro Github", destination: URL(string: "https://github.com/NEPaladin/StarNetPro/")!)
                Spacer()
                Button("Report an Issue") {
                    NSWorkspace.shared.open(URL(string: "https://github.com/NEPaladin/StarNetPro/issues")!)
                }
            }
        }
        .listStyle(SidebarListStyle())
    }
}

// Image Preview区域
struct ImagePreviewSection: View {
    @EnvironmentObject var processor: StarNetProcessor

    var body: some View {
        VStack(alignment: .leading) {
            Text("Image Preview")
                .font(.headline)
                .padding(.bottom, 5)

            if processor.inputImage == nil {
                FileDropView()
                    .frame(height: 300)
            } else {
                ComparisonView(
                    originalImage: processor.inputImage,
                    processedImage: processor.outputImage
                )
                .frame(height: 320)

                HStack {
                    Button("Show in Finder") {
                        processor.showInFinder(url: processor.inputPath)
                    }

                    Spacer()

                    if processor.outputImage != nil {
                        Button("Show Saved Result") {
                            processor.showInFinder(url: processor.outputPath)
                        }
                    }
                }
                .padding(.top, 5)
            }
        }
    }
}

// Processing面板
struct ProcessingPanel: View {
    @EnvironmentObject var processor: StarNetProcessor

    var body: some View {
        VStack(alignment: .leading) {
            Text("Processing")
                .font(.headline)
                .padding(.bottom, 5)

            if processor.isProcessing {
                VStack {

                    HStack {
                        Spacer()
                        Button(action: processor.cancelProcessing) {
                            Label("Cancel", systemImage: "pause.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }
                }
            } else {
                HStack {
                    if processor.inputImage != nil {
                        Button(action: processor.processImage) {
                            Label("Process Image", systemImage: "play.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    } else {
                        Button(action: processor.openImage) {
                            Label("Choose Image", systemImage: "")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }
                }
            }
        }
    }
}

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
        Group {
            if !processor.hasCompletedInitialCheck {
                ProgressView("Opening StarNetPro…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if processor.workspaceAvailable {
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
                        .disabled(processor.busy)
                    }

                    ToolbarItem(placement: .automatic) {
                        Button(action: processor.processImage) {
                            Label(processor.isProcessing ? "Processing..." : "Start Processing",
                                  systemImage: processor.isProcessing ? "stop.fill" : "play.fill")
                        }
                        .disabled(!processor.canProcess)
                        .keyboardShortcut("r", modifiers: [.command])
                    }
                }
            } else {
                CLIOnboardingView()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            processor.becameActive()
        }
        .sheet(isPresented: $processor.showLicense) {
            LicenseView()
                .environmentObject(processor)
        }
    }
}

// 侧边栏视图
struct SidebarView: View {
    @EnvironmentObject var processor: StarNetProcessor
    @State private var showAdvanced = false

    var body: some View {
        List {
            Section(header: Text("StarNet2 CLI")) {
                Text(processor.cliInfo?.version ?? "—")
                    .textSelection(.enabled)
            }
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

                    Toggle("Linear image", isOn: $processor.linearImage)
                        .toggleStyle(.checkbox)
                        .help("Enable for unstretched images. StarNet2 stretches for processing, then returns the result to linear data.")

                    Text("Star layers").font(.headline)
                    Toggle("Difference", isOn: $processor.createDifference)
                        .toggleStyle(.checkbox)
                        .help("Save stars for recombination using Add (Linear Dodge).")
                    Toggle("Unscreen", isOn: $processor.createUnscreen)
                        .toggleStyle(.checkbox)
                        .help("Save stars for recombination using Screen.")
                    Text("Save separate TIFFs alongside the starless image.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 5)
                .disabled(processor.busy)
            }

            Section {
                Button {
                    showAdvanced.toggle()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: showAdvanced ? "chevron.down" : "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 12)
                            .accessibilityHidden(true)
                        Text("Advanced")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Advanced")
                .accessibilityValue(showAdvanced ? "Expanded" : "Collapsed")
                .accessibilityHint("Show or hide technical settings")

                if showAdvanced {
                    CLISetupView()
                        .padding(.vertical, 8)
                    Link("StarNetPro GitHub", destination: URL(string: "https://github.com/leohgyang/StarNetPro/")!)
                    Button("Report an Issue") {
                        NSWorkspace.shared.open(URL(string: "https://github.com/leohgyang/StarNetPro/issues")!)
                    }
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
                        Button("Show Saved Results") {
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
                    ProgressView(value: processor.progress)
                    Text(processor.progressLabel)
                        .font(.caption)

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
                        .disabled(!processor.canProcess)
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

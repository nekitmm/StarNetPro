//
//  ComparisonView.swift
//  StarNetPro
//
//  Created by Sunny Ma on 2025/7/30.
//

import SwiftUI

struct ComparisonView: View {
    @EnvironmentObject var processor: StarNetProcessor
    let originalImage: NSImage?
    let processedImage: NSImage?
    @State private var sliderPosition: CGFloat = 0.5
    @State private var viewWidth: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 原始图像
                if let original = originalImage {
                    Image(nsImage: original)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .cornerRadius(8)
                        .shadow(radius: 3)
                }

                // 处理后的图像（带遮罩）
                if let processed = processedImage {
                    Image(nsImage: processed)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .cornerRadius(8)
                        .shadow(radius: 3)
                        .mask(
                            HStack(spacing: 0) {
                                Rectangle()
                                    .frame(width: sliderPosition * geometry.size.width)
                                Spacer(minLength: 0)
                            }
                        )
                } else if originalImage != nil {
                    // 处理前的提示
                    VStack {
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                }

                // 控制滑块
                if originalImage != nil && processedImage != nil {
                    VStack {
                        Text("←       |       →")
                            .foregroundColor(.primary)
                            .padding(8)
                            .background(.regularMaterial)
                            .cornerRadius(5)
                            .padding(.top, 10)

                        Spacer()

                        Slider(value: $sliderPosition, in: 0...1)
                            .frame(width: geometry.size.width * 0.8)
                            .padding(.bottom, 20)
                    }
                }
            }
            .frame(minHeight:280)
            .frame(maxHeight:320)
            .onAppear {
                viewWidth = geometry.size.width
            }
            .onChange(of: geometry.size) { newSize in
                viewWidth = newSize.width
            }
        }
        .contextMenu {
            // 上下文菜单 - 使用更安全的可选绑定
            if let inputPath = processor.inputPath {
                Button(action: {
                    processor.showInFinder(url: inputPath)
                }) {
                    Label("Show Original in Finder", systemImage: "photo")
                }
            }

            if let outputPath = processor.outputPath, processor.outputImage != nil {
                Button(action: {
                    processor.showInFinder(url: outputPath)
                }) {
                    Label("Show Result in Finder", systemImage: "star")
                }
            }

            Divider()

            Button(action: {
                if let image = processor.outputImage ?? processor.inputImage {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.writeObjects([image])
                }
            }) {
                Label("Copy Image", systemImage: "doc.on.doc")
            }
        }
    }
}

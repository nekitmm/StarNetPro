//
//  FileDropView.swift
//  StarNetPro
//
//  Created by Sunny Ma on 2025/7/30.
//

import SwiftUI
import UniformTypeIdentifiers

struct FileDropView: View {
    @EnvironmentObject var processor: StarNetProcessor

    var body: some View {
        VStack {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 48))
                .padding(.bottom, 10)

            Text("Drop an astrophotography image here")
                .font(.title2)

            Text("Supported formats: TIFF, PNG, JPEG")
                .foregroundColor(.secondary)
                .padding(.top, 5)

            Button("Or Choose a File...") {
                processor.openImage()
            }
            .padding(.top, 15)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(30)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8]))
                .foregroundColor(.secondary)
        )
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            guard let provider = providers.first else { return false }

            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { data, error in
                if let data = data as? Data,
                   let url = URL(dataRepresentation: data, relativeTo: nil) {
                    DispatchQueue.main.async {
                        processor.loadImage(at: url)
                    }
                }
            }
            return true
        }
    }
}

//
//  LogView.swift
//  StarNetPro
//
//  Created by Sunny Ma on 2025/7/30.
//

import SwiftUI

struct LogView: View {
    @Binding var logText: String

    var body: some View {
        VStack(alignment: .leading) {
            Text("Processing Log")
                .font(.headline)
                .padding(.bottom, 5)

            ScrollViewReader { proxy in
                ScrollView {
                    Text(logText)
                        .font(.system(size: 11, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .id("logEnd")
                }
                .frame(minHeight: 100)
                .frame(maxHeight: 150)
                .background(Color(.textBackgroundColor))
                .cornerRadius(6)
                .onChange(of: logText) { _ in
                    withAnimation {
                        proxy.scrollTo("logEnd", anchor: .bottom)
                    }
                }
            }
        }
    }
}

// 预览提供程序
struct LogView_Previews: PreviewProvider {
    static var previews: some View {
        LogView(logText: .constant("2023-08-15 14:30:25 - Start Processing...\n2023-08-15 14:31:10 - Processing complete!"))
            .frame(width: 500, height: 200)
            .previewLayout(.sizeThatFits)
    }
}

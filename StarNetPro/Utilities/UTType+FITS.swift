//
//  UTType+FITS.swift
//  StarNetPro
//
//  Created by Sunny Ma on 2025/7/31.
//

import UniformTypeIdentifiers

extension UTType {
    // 定义 FITS 类型
    static let fits = UTType(filenameExtension: "fits")!
    static let fit = UTType(filenameExtension: "fit")!

    // 添加天文图像类型
    static var astronomyTypes: [UTType] {
        [.tiff, .png, .jpeg, .fits, .fit]
    }
}

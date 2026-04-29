//
//  AIProxyUtils.swift
//
//
//  Created by Lou Zell on 7/9/24.
//
//  This fork removes the hosted-proxy backend. What remains here is the
//  Foundation-only URLSession used by DirectService, plus image-encoding
//  helpers gated by Apple-platform availability.
//

import Foundation

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

enum AIProxyUtils {

    nonisolated static let directURLSession = URLSession(
        configuration: .ephemeral,
        delegate: DirectURLSessionDataDelegate(),
        delegateQueue: nil
    )

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
    nonisolated static func encodeImageAsJpeg(
        _ image: NSImage,
        _ compressionQuality: CGFloat
    ) -> Data? {
        return image.jpegData(compressionQuality: compressionQuality)
    }

    nonisolated static func encodeImageAsURL(
        _ image: NSImage,
        _ compressionQuality: CGFloat
    ) -> URL? {
        guard let jpegData = self.encodeImageAsJpeg(image, compressionQuality) else {
            return nil
        }
        return URL(string: "data:image/jpeg;base64,\(jpegData.base64EncodedString())")
    }

#elseif canImport(UIKit)
    nonisolated static func encodeImageAsJpeg(
        _ image: UIImage,
        _ compressionQuality: CGFloat
    ) -> Data? {
        return image.jpegData(compressionQuality: compressionQuality)
    }

    nonisolated static func encodeImageAsURL(
        _ image: UIImage,
        _ compressionQuality: CGFloat
    ) -> URL? {
        guard let jpegData = self.encodeImageAsJpeg(image, compressionQuality) else {
            return nil
        }
        return URL(string: "data:image/jpeg;base64,\(jpegData.base64EncodedString())")
    }
#endif
}

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
extension NSImage {
    nonisolated func jpegData(compressionQuality: CGFloat = 1.0) -> Data? {
        guard let tiffData = self.tiffRepresentation else {
            return nil
        }
        guard let bitmapImage = NSBitmapImageRep(data: tiffData) else {
            return nil
        }
        let jpegData = bitmapImage.representation(
            using: .jpeg,
            properties: [.compressionFactor: compressionQuality]
        )
        return jpegData
    }
}
#endif

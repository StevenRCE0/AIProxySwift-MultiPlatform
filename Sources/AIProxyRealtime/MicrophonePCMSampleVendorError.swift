//
//  MicrophonePCMSampleVendorError.swift
//  AIProxy
//
//  Created by Lou Zell on 2/20/25.
//

import Foundation
import AIProxy

nonisolated public enum MicrophonePCMSampleVendorError: LocalizedError, Sendable {
    case couldNotConfigureAudioUnit(String)

    public var errorDescription: String? {
        switch self {
        case .couldNotConfigureAudioUnit(let message):
            return message
        }
    }
}

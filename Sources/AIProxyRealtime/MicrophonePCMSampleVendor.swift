//
//  MicrophonePCMSampleVendor.swift
//  AIProxy
//
//  Created by Lou Zell on 5/29/25.
//

import AVFoundation
import AIProxy

@AIProxyActor protocol MicrophonePCMSampleVendor: AnyObject {
    func start() throws -> AsyncStream<AVAudioPCMBuffer>
    func stop()
}

//
//  OpenAIService+Realtime.swift
//  AIProxyRealtime
//
//  Re-attaches the upstream `realtimeSession(...)` API to `OpenAIService`
//  when this target is linked. The core `AIProxy` target stays free of
//  AVFoundation; consumers opt in by adding `import AIProxyRealtime`.
//

import AIProxy
import Foundation

extension OpenAIService {
    /// Starts a realtime session.
    ///
    /// - Parameters:
    ///   - model: The model to use. See the available model names in the `realtime` section here:
    ///            https://developers.openai.com/api/docs/models
    ///   - configuration: The session configuration object, see this reference:
    ///                    https://platform.openai.com/docs/api-reference/realtime-client-events/session/update#realtime-client-events/session/update-session
    ///   - logLevel: The threshold level that this library begins emitting log messages.
    ///               For example, if you set this to `info`, then you'll see all `info`, `warning`, `error`, and `critical` logs.
    ///
    /// - Returns: A realtime session manager that the caller can send and receive messages with.
    public func realtimeSession(
        model: String,
        configuration: OpenAIRealtimeSessionConfiguration,
        logLevel: AIProxyLogLevel
    ) async throws -> OpenAIRealtimeSession {
        AIProxyLogLevel.callerDesiredLogLevel = logLevel
        let webSocketTask = try await self.webSocketTask(
            path: "/v1/realtime?model=\(model)"
        )
        return OpenAIRealtimeSession(
            webSocketTask: webSocketTask,
            sessionConfiguration: configuration
        )
    }
}

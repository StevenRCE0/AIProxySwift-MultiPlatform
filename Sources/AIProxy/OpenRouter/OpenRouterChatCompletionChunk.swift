//
//  OpenRouterChatCompletionChunk.swift
//  AIProxy
//
//  Created by Lou Zell on 12/30/24.
//

nonisolated public struct OpenRouterChatCompletionChunk: Decodable, Sendable {
    /// A list of chat completion choices. Can contain more than one elements if
    /// OpenRouterChatCompletionRequestBody's `n` property is greater than 1. Can also be empty for
    /// the last chunk, which contains usage information only.
    public let choices: [Choice]

    /// The model used for the chat completion.
    public let model: String?

    /// The provider used to fulfill the chat completion.
    public let provider: String?

    /// This property is nil for all chunks except for the last chunk, which contains the token
    /// usage statistics for the entire request.
    public let usage: OpenRouterChatCompletionResponseBody.Usage?
    
    public init(choices: [Choice], model: String?, provider: String?, usage: OpenRouterChatCompletionResponseBody.Usage?) {
        self.choices = choices
        self.model = model
        self.provider = provider
        self.usage = usage
    }
}

// MARK: Chunk.Choice
extension OpenRouterChatCompletionChunk {
    nonisolated public struct Choice: Decodable, Sendable {
        public let delta: Delta
        public let finishReason: String?

        public init(delta: Delta, finishReason: String?) {
            self.delta = delta
            self.finishReason = finishReason
        }

        private enum CodingKeys: String, CodingKey {
            case delta
            case finishReason = "finish_reason"
        }
    }
}

// MARK: Chunk.Choice.Delta
extension OpenRouterChatCompletionChunk.Choice {
    nonisolated public struct Delta: Codable, Sendable {
        public let role: String

        /// Output content. For reasoning models, these chunks arrive after `reasoning` has finished.
        public let content: String?

        /// Reasoning content. For reasoning models, these chunks arrive before `content`.
        public let reasoning: String?

        public let toolCalls: [ToolCall]?

        /// Audio output delta. Present when the response includes audio (`modalities: ["audio"]`).
        public let audio: AudioDelta?

        public init(
            role: String,
            content: String? = nil,
            reasoning: String? = nil,
            toolCalls: [OpenRouterChatCompletionChunk.Choice.Delta.ToolCall]? = nil,
            audio: AudioDelta? = nil
        ) {
            self.role = role
            self.content = content
            self.reasoning = reasoning
            self.toolCalls = toolCalls
            self.audio = audio
        }

        private enum CodingKeys: String, CodingKey {
            case audio
            case role
            case content
            case reasoning
            case toolCalls = "tool_calls"
        }
    }
}

// MARK: - AudioDelta
extension OpenRouterChatCompletionChunk.Choice.Delta {
    nonisolated public struct AudioDelta: Codable, Sendable {
        public let id: String?
        public let data: String?
        public let transcript: String?
        public let expiresAt: Int?

        public init(id: String? = nil, data: String? = nil, transcript: String? = nil, expiresAt: Int? = nil) {
            self.id = id
            self.data = data
            self.transcript = transcript
            self.expiresAt = expiresAt
        }

        private enum CodingKeys: String, CodingKey {
            case id
            case data
            case transcript
            case expiresAt = "expires_at"
        }
    }
}

extension OpenRouterChatCompletionChunk.Choice.Delta {
    nonisolated public struct ToolCall: Codable, Sendable {
        public let index: Int?
        /// The function that the model instructs us to call
        public let function: Function?
    }
}

extension OpenRouterChatCompletionChunk.Choice.Delta.ToolCall {
    nonisolated public struct Function: Codable, Sendable {
        /// The name of the function to call.
        public let name: String?

        /// The arguments to call the function with.
        public let arguments: String?
    }
}

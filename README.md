# AIProxySwift-MultiPlatform

A trimmed fork of [AIProxySwift](https://github.com/lzell/AIProxySwift) used by [KeepTalking](https://github.com/StevenRCE0/AIProxySwift-MultiPlatform). The upstream hosted-proxy backend, DeviceCheck, and StoreKit plumbing are removed; what remains is a pure BYOK (bring-your-own-key) Swift client you can use on any Apple platform — and the Foundation-only core also builds on Linux.

## Products

| Product | Platforms | Description |
|---|---|---|
| `AIProxy` | iOS 15+, macOS 13+, visionOS 1+, watchOS 9+, Linux | Foundation-only BYOK core — chat completions, embeddings, images, and more across 17+ providers |
| `AIProxyRealtime` | iOS 15+, macOS 13+, visionOS 1+ | OpenAI Realtime API over WebSocket + AVFoundation audio capture/playback |

Link only `AIProxy` if you don't need live audio. `AIProxyRealtime` depends on `AIProxy` and adds AVFoundation/AudioToolbox; it is not available on Linux or watchOS.

## Providers (AIProxy target)

- OpenAI
- Anthropic
- OpenRouter
- Gemini
- Groq
- Mistral
- DeepSeek
- Fireworks AI
- Together AI
- Perplexity
- ElevenLabs
- Replicate
- Fal
- Stability AI
- DeepL
- Brave
- EachAI

## Installation

### Swift Package Manager

Add to your `Package.swift`:

```swift
.package(
    url: "https://github.com/StevenRCE0/AIProxySwift-MultiPlatform",
    branch: "multiplatform-subset"
),
```

Then depend on whichever product you need:

```swift
// Core only (also works on Linux):
.product(name: "AIProxy", package: "AIProxySwift-MultiPlatform")

// Core + Realtime audio (Apple platforms only):
.product(name: "AIProxyRealtime", package: "AIProxySwift-MultiPlatform")
```

### Local path (monorepo / side-by-side checkout)

```swift
.package(name: "AIProxyMultiPlatform", path: "../AIProxySwift-MultiPlatform")
```

## Quick start

All services are constructed via `AIProxy.direct*Service` factory methods that route straight to the provider with your API key — no proxy backend involved.

```swift
import AIProxy

// OpenAI
let openAI = AIProxy.directOpenAIService(unprotectedAPIKey: "sk-...")
let response = try await openAI.chatCompletionRequest(body: .init(
    model: "gpt-4o-mini",
    messages: [.init(role: .user, content: .text("Hello!"))]
))
print(response.choices.first?.message.content ?? "")

// Anthropic
let anthropic = AIProxy.directAnthropicService(unprotectedAPIKey: "sk-ant-...")
let message = try await anthropic.messageRequest(body: .init(
    model: "claude-sonnet-4-5",
    messages: [.init(role: "user", content: .text("Hello!"))]
))

// OpenRouter
let openRouter = AIProxy.directOpenRouterService(unprotectedAPIKey: "sk-or-...")
let orResponse = try await openRouter.chatCompletionRequest(body: .init(
    model: "openai/gpt-4o-mini",
    messages: [.init(role: .user, content: .text("Hello!"))]
))
```

## Realtime API (AIProxyRealtime target)

`AIProxyRealtime` attaches to `OpenAIService` via the `webSocketTask(path:headers:)` bridge — a single public method on the core service that `AIProxyRealtime` uses to open a WebSocket without duplicating auth logic.

```swift
import AIProxy
import AIProxyRealtime

let openAI = AIProxy.directOpenAIService(unprotectedAPIKey: "sk-...")
// AIProxyRealtime uses openAI.webSocketTask(path:headers:) internally.
let session = OpenAIRealtimeSession(service: openAI)
try await session.connect(model: "gpt-4o-realtime-preview")
```

Audio capture and playback are handled by `MicrophonePCMSampleVendor` and `AudioPCMPlayer` respectively — both backed by AVFoundation, with an AudioToolbox fallback path for macOS.

## Tool / function calling

`AIProxyJSONValue` is the canonical type for JSON schema definitions in tool parameters. It behaves like `[String: Any]` but is fully `Codable`:

```swift
let parameters: [String: AIProxyJSONValue] = [
    "type": .string("object"),
    "properties": .object([
        "city": .object([
            "type": .string("string"),
            "description": .string("The city name"),
        ]),
    ]),
    "required": .array([.string("city")]),
]
```

## Differences from upstream AIProxySwift

| Upstream | This fork |
|---|---|
| Hosted proxy backend (`AIProxy.com`) | Removed — BYOK only |
| DeviceCheck / app attestation | Removed |
| StoreKit rate-limit purchasing | Removed |
| macOS / Linux support | Added (Foundation-only core) |
| Realtime in main target | Extracted to separate `AIProxyRealtime` target |

Upstream bug fixes and new provider support can be cherry-picked; the hosted-proxy plumbing is isolated enough that merging the `Sources/AIProxy` provider subdirectories is straightforward.

## License

Apache 2.0 — same as upstream AIProxySwift.

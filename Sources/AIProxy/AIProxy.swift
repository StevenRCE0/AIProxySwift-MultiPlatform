//
//  AIProxy.swift
//
//  Public facade for the AIProxy library.
//
//  This fork removes the hosted-proxy backend (DeviceCheck, anonymous account,
//  receipt validation, certificate pinning, ProxiedService) entirely. Only the
//  DirectService (BYOK) path is supported. Consumers configure their own API
//  key and talk to the upstream provider directly.
//

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

public enum AIProxy {

    // MARK: - Configuration

    /// Configures library-wide logging knobs.
    ///
    /// - Parameters:
    ///   - logLevel: threshold for SDK logs printed to the console.
    ///   - printRequestBodies: print API request bodies (logged at .debug).
    ///   - printResponseBodies: print API response bodies (logged at .debug).
    nonisolated public static func configure(
        logLevel: AIProxyLogLevel,
        printRequestBodies: Bool = false,
        printResponseBodies: Bool = false
    ) {
        AIProxyLogLevel.callerDesiredLogLevel = logLevel
        self.configuration = AIProxyConfiguration(
            printRequestBodies: printRequestBodies,
            printResponseBodies: printResponseBodies
        )
    }

    /// Backing store for `configuration`. Access through the property below.
    nonisolated(unsafe) static private var _configuration: AIProxyConfiguration?
    nonisolated static var configuration: AIProxyConfiguration? {
        get {
            ProtectedPropertyQueue.configuration.sync { self._configuration }
        }
        set {
            ProtectedPropertyQueue.configuration.async(flags: .barrier) { self._configuration = newValue }
        }
    }

    nonisolated public static var printRequestBodies: Bool {
        self.configuration?.printRequestBodies ?? false
    }

    nonisolated public static var printResponseBodies: Bool {
        self.configuration?.printResponseBodies ?? false
    }

    // MARK: - Image encoding helpers

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
    nonisolated public static func encodeImageAsJpeg(
        image: NSImage,
        compressionQuality: CGFloat
    ) -> Data? {
        return AIProxyUtils.encodeImageAsJpeg(image, compressionQuality)
    }

    nonisolated public static func encodeImageAsURL(
        image: NSImage,
        compressionQuality: CGFloat
    ) -> URL? {
        return AIProxyUtils.encodeImageAsURL(image, compressionQuality)
    }
#elseif canImport(UIKit)
    nonisolated public static func encodeImageAsJpeg(
        image: UIImage,
        compressionQuality: CGFloat
    ) -> Data? {
        return AIProxyUtils.encodeImageAsJpeg(image, compressionQuality)
    }

    nonisolated public static func encodeImageAsURL(
        image: UIImage,
        compressionQuality: CGFloat
    ) -> URL? {
        return AIProxyUtils.encodeImageAsURL(image, compressionQuality)
    }
#endif

    // MARK: - Direct service factories (BYOK)

    /// Service that makes requests directly to OpenAI. BYOK only — no proxy protections.
    nonisolated public static func openAIDirectService(
        unprotectedAPIKey: String,
        baseURL: String? = nil,
        requestFormat: OpenAIRequestFormat = .standard
    ) -> OpenAIService {
        return OpenAIDirectService(
            unprotectedAPIKey: unprotectedAPIKey,
            requestFormat: requestFormat,
            baseURL: baseURL
        )
    }

    nonisolated public static func geminiDirectService(
        unprotectedAPIKey: String
    ) -> GeminiService {
        return GeminiDirectService(unprotectedAPIKey: unprotectedAPIKey)
    }

    nonisolated public static func anthropicDirectService(
        unprotectedAPIKey: String,
        baseURL: String? = nil
    ) -> AnthropicService {
        return AnthropicDirectService(
            unprotectedAPIKey: unprotectedAPIKey,
            baseURL: baseURL
        )
    }

    nonisolated public static func stabilityAIDirectService(
        unprotectedAPIKey: String
    ) -> StabilityAIService {
        return StabilityAIDirectService(unprotectedAPIKey: unprotectedAPIKey)
    }

    nonisolated public static func deepLDirectService(
        unprotectedAPIKey: String,
        accountType: DeepLAccountType
    ) -> DeepLService {
        return DeepLDirectService(
            unprotectedAPIKey: unprotectedAPIKey,
            accountType: accountType
        )
    }

    nonisolated public static func togetherAIDirectService(
        unprotectedAPIKey: String
    ) -> TogetherAIService {
        return TogetherAIDirectService(unprotectedAPIKey: unprotectedAPIKey)
    }

    nonisolated public static func replicateDirectService(
        unprotectedAPIKey: String
    ) -> ReplicateService {
        return ReplicateDirectService(unprotectedAPIKey: unprotectedAPIKey)
    }

    nonisolated public static func elevenLabsDirectService(
        unprotectedAPIKey: String
    ) -> ElevenLabsService {
        return ElevenLabsDirectService(unprotectedAPIKey: unprotectedAPIKey)
    }

    nonisolated public static func falDirectService(
        unprotectedAPIKey: String
    ) -> FalService {
        return FalDirectService(unprotectedAPIKey: unprotectedAPIKey)
    }

    nonisolated public static func groqDirectService(
        unprotectedAPIKey: String,
        baseURL: String? = nil
    ) -> GroqService {
        return GroqDirectService(
            unprotectedAPIKey: unprotectedAPIKey,
            baseURL: baseURL
        )
    }

    nonisolated public static func perplexityDirectService(
        unprotectedAPIKey: String
    ) -> PerplexityService {
        return PerplexityDirectService(unprotectedAPIKey: unprotectedAPIKey)
    }

    nonisolated public static func mistralDirectService(
        unprotectedAPIKey: String
    ) -> MistralService {
        return MistralDirectService(unprotectedAPIKey: unprotectedAPIKey)
    }

    nonisolated public static func eachAIDirectService(
        unprotectedAPIKey: String
    ) -> EachAIService {
        return EachAIDirectService(unprotectedAPIKey: unprotectedAPIKey)
    }

    nonisolated public static func openRouterDirectService(
        unprotectedAPIKey: String,
        baseURL: String? = nil
    ) -> OpenRouterService {
        return OpenRouterDirectService(
            unprotectedAPIKey: unprotectedAPIKey,
            baseURL: baseURL
        )
    }

    nonisolated public static func deepSeekDirectService(
        unprotectedAPIKey: String,
        baseURL: String? = nil
    ) -> DeepSeekService {
        return DeepSeekDirectService(
            unprotectedAPIKey: unprotectedAPIKey,
            baseURL: baseURL
        )
    }

    nonisolated public static func fireworksAIDirectService(
        unprotectedAPIKey: String
    ) -> FireworksAIService {
        return FireworksAIDirectService(unprotectedAPIKey: unprotectedAPIKey)
    }

    nonisolated public static func braveDirectService(
        unprotectedAPIKey: String
    ) -> BraveService {
        return BraveDirectService(unprotectedAPIKey: unprotectedAPIKey)
    }
}

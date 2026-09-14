//
//  ExampleProviders.swift
//  SophonExample
//
//  The providers the example offers, the OpenAI-compatible clients behind
//  them, and which one the demo pages use (persisted across launches).
//

import Foundation
import SophonAnthropic
import SophonGemini
import SophonOpenAI

@MainActor
enum ExampleProviders {
    // MARK: - Constants

    private static let selectionKey = "example.selectedProvider"

    // MARK: - Registry

    /// Held separately so its descriptor can route the listing through
    /// `listFreeModels()`: the `:free` roster rotates monthly, so the catalog
    /// presets are a dated snapshot and the listing endpoint is the durable path.
    private static let openRouter = openRouterClient()

    static let all: [ExampleProviderDescriptor] = [
        ExampleProviderDescriptor(
            title: "Gemini",
            client: GeminiAPIClient.shared,
            configuration: GeminiClientConfiguration.example,
            store: GeminiAPIClient.shared.modelStore
        ),
        ExampleProviderDescriptor(title: "OpenAI", client: openAIClient()),
        ExampleProviderDescriptor(title: "Groq", client: groqClient()),
        ExampleProviderDescriptor(title: "Mistral", client: mistralClient()),
        ExampleProviderDescriptor(
            title: "OpenRouter",
            client: openRouter,
            listModels: { try await openRouter.listFreeModels() },
            listModelsNote: "Only the models OpenRouter serves free right now (IDs ending in :free). "
                + "The free roster rotates monthly, so this listing, not the catalog presets, is the durable way to see what is free today."
        ),
        ExampleProviderDescriptor(title: "DeepSeek", client: deepSeekClient()),
        ExampleProviderDescriptor(title: "Qwen (international)", client: qwenClient(region: .international)),
        ExampleProviderDescriptor(title: "Qwen (China)", client: qwenClient(region: .china)),
        ExampleProviderDescriptor(title: "GLM (international)", client: glmClient(region: .international)),
        ExampleProviderDescriptor(title: "GLM (China)", client: glmClient(region: .china)),
        ExampleProviderDescriptor(title: "Kimi (international)", client: kimiClient(region: .international)),
        ExampleProviderDescriptor(title: "Kimi (China)", client: kimiClient(region: .china)),
        ExampleProviderDescriptor(title: "Doubao", client: doubaoClient()),
        ExampleProviderDescriptor(
            title: "Claude",
            client: AnthropicAPIClient.shared,
            configuration: AnthropicClientConfiguration.example,
            store: AnthropicAPIClient.shared.modelStore
        ),
    ]

    // MARK: - Selection

    /// The provider the demo pages talk to, persisted across launches by title
    /// (titles are stable; positions in `all` are not). Anything but a string
    /// under the key (an older build stored an array index) is ignored, so the
    /// first descriptor wins.
    static var selected: ExampleProviderDescriptor {
        get {
            guard let title = UserDefaults.standard.object(forKey: selectionKey) as? String else { return all[0] }
            return all.first { $0.title == title } ?? all[0]
        }
        set {
            UserDefaults.standard.set(newValue.title, forKey: selectionKey)
        }
    }

    // MARK: - OpenAI-compatible clients

    /// Keychain accounts are per provider and region: each is a separate key.
    private static func account(_ name: String) -> String {
        "dev.luminoid.sophon.example.\(name)APIKey"
    }

    private static func openAIClient() -> OpenAIAPIClient {
        OpenAIAPIClient(configuration: OpenAIClientConfiguration(keychainAccount: account("openAI")))
    }

    private static func groqClient() -> GroqAPIClient {
        GroqAPIClient(configuration: GroqClientConfiguration(keychainAccount: account("groq")))
    }

    private static func mistralClient() -> MistralAPIClient {
        MistralAPIClient(configuration: MistralClientConfiguration(keychainAccount: account("mistral")))
    }

    private static func openRouterClient() -> OpenRouterAPIClient {
        OpenRouterAPIClient(configuration: OpenRouterClientConfiguration(
            keychainAccount: account("openRouter"),
            appName: "Sophon Example",
            appURL: URL(string: "https://github.com/Luminoid/Sophon")
        ))
    }

    private static func deepSeekClient() -> DeepSeekAPIClient {
        DeepSeekAPIClient(configuration: DeepSeekClientConfiguration(keychainAccount: account("deepSeek")))
    }

    private static func qwenClient(region: OpenAIEndpointRegion) -> QwenAPIClient {
        QwenAPIClient(configuration: QwenClientConfiguration(keychainAccount: account("qwen.\(region.rawValue)"), endpoint: QwenModel.endpoint(region: region)))
    }

    private static func glmClient(region: OpenAIEndpointRegion) -> GLMAPIClient {
        GLMAPIClient(configuration: GLMClientConfiguration(keychainAccount: account("glm.\(region.rawValue)"), endpoint: GLMModel.endpoint(region: region)))
    }

    private static func kimiClient(region: OpenAIEndpointRegion) -> KimiAPIClient {
        KimiAPIClient(configuration: KimiClientConfiguration(keychainAccount: account("kimi.\(region.rawValue)"), endpoint: KimiModel.endpoint(region: region)))
    }

    private static func doubaoClient() -> DoubaoAPIClient {
        DoubaoAPIClient(configuration: DoubaoClientConfiguration(keychainAccount: account("doubao")))
    }
}

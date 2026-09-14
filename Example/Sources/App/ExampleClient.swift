//
//  ExampleClient.swift
//  SophonExample
//
//  The example app's Sophon wiring: one configuration and one shared client
//  per provider, plus a type-erased descriptor the demo pages switch between.
//  Real apps do exactly this for the providers they ship, with their own
//  Keychain accounts, model catalogs, retry policies, and log handlers.
//

import Foundation
import SophonAnthropic
import SophonCore
import SophonGemini
import SophonOpenAI

// MARK: - Configurations

extension GeminiClientConfiguration {
    /// Everything but the Keychain account is a package default: Sophon's
    /// recommended default and fallback models, every current preset,
    /// `.default` retry policy, `ai.*` UserDefaults keys, `os.Logger` logging.
    static let example = GeminiClientConfiguration(keychainAccount: "dev.luminoid.sophon.example.geminiAPIKey")
}

extension GeminiAPIClient {
    static let shared = GeminiAPIClient(configuration: .example)
}

extension AnthropicClientConfiguration {
    static let example = AnthropicClientConfiguration(keychainAccount: "dev.luminoid.sophon.example.anthropicAPIKey")
}

extension AnthropicAPIClient {
    static let shared = AnthropicAPIClient(configuration: .example)
}

// MARK: - Provider Descriptors

/// One row of a provider's model picker.
struct ExampleModelOption {
    let title: String
    let isSelected: Bool
    let select: @MainActor () -> Void
}

/// A provider as the demo pages see it: the cross-provider client plus the
/// few typed operations the settings page needs, captured as closures so the
/// pages never depend on a catalog type.
@MainActor
struct ExampleProviderDescriptor {
    let title: String
    let client: any LLMClient
    let configuration: any LLMProviderConfiguration
    let freeAccess: LLMProviderFreeAccess
    let keyHint: String
    let modelOptions: () -> [ExampleModelOption]
    let selectCustomModel: (String) -> Void
    let currentModelName: () -> String
    let isCustomModelSelected: () -> Bool

    init<Model: LLMModelPreset>(
        title: String,
        client: any LLMClient,
        configuration: any LLMProviderConfiguration,
        store: LLMModelStore<Model>,
        freeAccess: LLMProviderFreeAccess,
        keyHint: String
    ) {
        self.title = title
        self.client = client
        self.configuration = configuration
        self.freeAccess = freeAccess
        self.keyHint = keyHint
        modelOptions = {
            let current = store.current
            return store.availableModels.map { model in
                ExampleModelOption(title: model.displayName + (model.hasFreeTier ? " (free tier)" : ""), isSelected: model == current) {
                    store.select(model)
                }
            }
        }
        selectCustomModel = { store.select(Model.custom($0)) }
        currentModelName = { store.current.displayName }
        isCustomModelSelected = { store.current.isCustom }
    }

    /// Descriptor for an OpenAI-compatible client, keyed by its endpoint.
    init<Model: OpenAICompatibleModel>(title: String, client: OpenAICompatibleClient<Model>) {
        self.init(
            title: title,
            client: client,
            configuration: client.configuration,
            store: client.modelStore,
            freeAccess: Model.freeAccess,
            keyHint: client.configuration.endpoint.keyHintURL?.absoluteString ?? ""
        )
    }
}

/// The providers the example offers, and which one the demo pages use.
@MainActor
enum ExampleProviders {
    private static let selectionKey = "example.selectedProvider"

    static let all: [ExampleProviderDescriptor] = [
        ExampleProviderDescriptor(
            title: "Gemini",
            client: GeminiAPIClient.shared,
            configuration: GeminiClientConfiguration.example,
            store: GeminiAPIClient.shared.modelStore,
            freeAccess: GeminiModel.freeAccess,
            keyHint: "https://aistudio.google.com/apikey"
        ),
        ExampleProviderDescriptor(title: "OpenAI", client: openAIClient("openAI")),
        ExampleProviderDescriptor(title: "Groq", client: groqClient()),
        ExampleProviderDescriptor(title: "Mistral", client: mistralClient()),
        ExampleProviderDescriptor(title: "OpenRouter", client: openRouterClient()),
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
            store: AnthropicAPIClient.shared.modelStore,
            freeAccess: AnthropicModel.freeAccess,
            keyHint: AnthropicModel.keyHintURL?.absoluteString ?? ""
        ),
    ]

    /// The provider the demo pages talk to; persisted across launches.
    static var selected: ExampleProviderDescriptor {
        get {
            let index = UserDefaults.standard.integer(forKey: selectionKey)
            return all.indices.contains(index) ? all[index] : all[0]
        }
        set {
            let index = all.firstIndex { $0.title == newValue.title } ?? 0
            UserDefaults.standard.set(index, forKey: selectionKey)
        }
    }

    // MARK: - OpenAI-compatible clients

    /// Keychain accounts are per provider and region: each is a separate key.
    private static func account(_ name: String) -> String {
        "dev.luminoid.sophon.example.\(name)APIKey"
    }

    private static func openAIClient(_ name: String) -> OpenAIAPIClient {
        OpenAIAPIClient(configuration: OpenAIClientConfiguration(keychainAccount: account(name)))
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

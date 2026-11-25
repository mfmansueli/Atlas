//
//  ReviewRiskSignalTopic.swift
//  Atlas
//

import Foundation

/// Something an app's words or code can show, for the content and China
/// mainland checks: AI generation, chat, a community, ads. Each topic
/// lists the words looked for (English and Simplified Chinese, whole
/// words; capitals-only ones like "AI" match capitals only), phrases that
/// make a match mean something else, and the packages and modules that
/// show it in the project.
///
/// Words that are usually something else are left out, so a match is
/// worth a look: "chat" alone (an AI chat isn't messaging people),
/// "singles" (music), "slots" (booking), "summarize" without AI, "Gemini"
/// and "Claude" outside the review notes (a sign of the zodiac, a name).
enum ReviewRiskSignalTopic: String, CaseIterable, Hashable, Sendable {
    /// AI generation or synthetic content: chatbots, assistants,
    /// summaries, translation.
    case aiGeneration
    /// AI that makes images, videos, voices, faces or avatars: content
    /// people make and share (1.2.1(a) counts it as user content).
    case aiCreation
    /// A model from a US company: OpenAI, Anthropic, Google.
    case usAIProvider
    /// A model from another company: DeepSeek, Qwen, on-device models.
    case otherAIProvider
    case dating
    /// People messaging each other.
    case messaging
    /// People posting for others: a community, a forum, followers.
    case community
    /// Sharing with other people, a weaker sign than the rest.
    case sharing
    case liveStream
    case encryptedMessaging
    case simulatedGambling
    case webAccess
    case advertising
    case medical
    case wellness

    /// Words in store texts and the review notes.
    var words: [String] {
        switch self {
        case .aiGeneration:
            [
                "AI", "A.I.", "KI", "IA", "artificial intelligence", "chatbot", "chatbots", "chat bot", "AI chat", "AI assistant",
                "virtual assistant", "smart assistant", "text-to-speech", "text to speech", "AI voice", "AI summary",
                "AI summaries", "summarize with AI", "rewrite with AI", "translate with AI", "AI translation", "AI writing",
                "AI writer", "large language model", "LLM", "Apple Intelligence",
                "人工智能", "智能助手", "智能生成", "大模型", "聊天机器人", "AI写作", "AI聊天", "AI配音",
            ]
        case .aiCreation:
            [
                "AI-generated", "AI generated", "generative AI", "AI generator", "image generator", "image generation",
                "generate images", "video generator", "video generation", "generate videos", "text to image", "text-to-image",
                "text to video", "text-to-video", "voice clone", "voice cloning", "clone your voice", "voice changer", "face swap",
                "faceswap", "avatar maker", "AI avatar", "AI art", "AI photo", "AI photos", "deepfake",
                "AI绘画", "AI生成", "生成式", "换脸", "数字人", "语音克隆", "AI换装",
            ]
        case .usAIProvider:
            ["OpenAI", "ChatGPT", "GPT", "Anthropic", "Google Gemini", "Gemini API", "Vertex AI"]
        case .otherAIProvider:
            [
                "DeepSeek", "Qwen", "通义千问", "通义", "文心一言", "ERNIE Bot", "豆包", "Doubao", "Kimi", "智谱", "ChatGLM",
                "Mistral", "Midjourney", "Stable Diffusion", "Stability AI", "ElevenLabs", "Hugging Face",
            ]
        case .dating:
            [
                "dating", "dating app", "date nearby", "meet new people", "meet people", "meet singles", "local singles",
                "find your match", "find love", "soulmate", "hookup", "hook up", "swipe right", "people nearby", "nearby people",
                "交友", "约会", "附近的人", "相亲", "脱单",
            ]
        case .messaging:
            [
                "chat with friends", "chat with other", "chat with others", "chat with people", "chat with strangers",
                "chat with matches", "chat with your matches", "group chat", "group chats", "private messages", "private messaging",
                "direct messages", "direct message", "send messages", "message friends", "message your friends",
                "instant messaging", "messenger", "chat rooms", "chat room", "chatroom", "voice chat", "video chat",
                "群聊", "私信", "聊天室", "即时通讯", "发消息",
            ]
        case .community:
            [
                "community", "forum", "forums", "followers", "follow friends", "follow other", "user-generated", "user generated",
                "post photos", "post videos", "post your", "publish your", "upload and share", "share with the community",
                "comment on", "leave comments", "like and comment",
                "社区", "评论", "论坛", "发帖", "粉丝",
            ]
        case .sharing:
            [
                "share with friends", "share with others", "share it with", "share them with", "share your creations",
                "share your art", "share your videos", "share your photos", "分享",
            ]
        case .liveStream:
            ["live stream", "live streams", "livestream", "live streaming", "go live", "short video", "short videos", "直播", "短视频"]
        case .encryptedMessaging:
            ["end-to-end encrypted", "end-to-end encryption", "end to end encrypted", "end to end encryption", "E2EE", "端到端加密"]
        case .simulatedGambling:
            [
                "casino", "slot machine", "slot machines", "casino slots", "poker", "blackjack", "roulette", "jackpot",
                "texas hold'em", "老虎机", "赌场", "德州扑克",
            ]
        case .webAccess:
            [
                "web browser", "private browser", "browse the web", "browse the internet", "browse any website",
                "open any website", "visit any website", "浏览器",
            ]
        case .advertising:
            ["remove ads", "ad-supported", "ad supported", "contains ads", "去广告"]
        case .medical:
            [
                "medical", "diagnosis", "diagnose", "symptom", "symptoms", "treatment", "medication", "medications",
                "prescription", "prescriptions", "clinical", "医疗", "诊断", "症状", "药物",
            ]
        case .wellness:
            [
                "meditation", "mindfulness", "mental health", "wellness", "wellbeing", "well-being", "workout", "workouts",
                "fitness", "weight loss", "lose weight", "calorie", "calories", "nutrition", "sleep tracking",
                "冥想", "健身", "减肥", "健康",
            ]
        }
    }

    /// Words that count in App Review's notes only.
    var reviewNotesWords: [String] {
        switch self {
        case .usAIProvider: ["Claude", "Gemini", "Google AI"]
        case .otherAIProvider: ["Llama", "Replicate"]
        default: []
        }
    }

    /// Phrases a match inside of means something else.
    var exclusions: [String] {
        switch self {
        case .aiGeneration: ["AI file", "AI files", "Adobe Illustrator"]
        case .dating: ["carbon dating", "dating back", "dating from"]
        case .community: ["discord community", "reddit community", "facebook community", "our discord"]
        case .simulatedGambling: ["planning poker", "scrum poker", "poker face"]
        case .webAccess: ["browser extension", "safari extension", "in-app browser"]
        default: []
        }
    }

    /// Parts of dependency names (lowercased) that show it.
    var packages: [String] {
        switch self {
        case .aiGeneration, .aiCreation: []
        case .usAIProvider: ["openai", "anthropic", "generative-ai", "generativeai", "vertexai", "chatgpt"]
        case .otherAIProvider:
            [
                "replicate", "stability-ai", "stabilityai", "elevenlabs", "deepseek", "dashscope", "qwen", "qianfan", "zhipu",
                "volcengine", "doubao", "mlx-swift", "ml-stable-diffusion", "llama", "huggingface", "swift-transformers",
            ]
        case .messaging:
            [
                "stream-chat", "streamchat", "sendbird", "timsdk", "tencent-im", "tuikit", "agora", "zego", "livekit", "pubnub",
                "twilio-conversations", "cometchat", "quickblox",
            ]
        case .liveStream: ["agora", "zego", "livekit", "mux-player", "haishinkit"]
        case .encryptedMessaging: ["libsignal", "signal-protocol", "libolm", "olmkit", "vodozemac"]
        case .advertising:
            [
                "google-mobile-ads", "googlemobileads", "applovin", "unity-ads", "unityads", "ironsource", "audience-network",
                "audiencenetwork", "appodeal", "chartboost", "vungle", "inmobi", "mintegral", "pangle", "admob", "yandex-mobile-ads",
            ]
        default: []
        }
    }

    /// Modules imported in the Swift sources that show it.
    var imports: [String] {
        switch self {
        case .aiGeneration: ["FoundationModels"]
        case .aiCreation: ["ImagePlayground"]
        case .usAIProvider: ["OpenAI", "OpenAIKit", "SwiftOpenAI", "Anthropic", "SwiftAnthropic", "GoogleGenerativeAI", "FirebaseVertexAI", "FirebaseAI"]
        case .otherAIProvider: ["MLX", "MLXLLM", "MLXLMCommon", "MLXVLM", "StableDiffusion", "ElevenLabsSDK"]
        case .messaging:
            ["StreamChat", "StreamChatSwiftUI", "StreamChatUI", "SendbirdChatSDK", "SendBirdSDK", "ImSDK_Plus", "TUIChat", "PubNub", "CometChatSDK"]
        case .liveStream: ["AgoraRtcKit", "ZegoExpressEngine", "LiveKit", "HaishinKit"]
        case .encryptedMessaging: ["LibSignalClient", "SignalProtocol", "OLMKit"]
        case .advertising:
            [
                "GoogleMobileAds", "AppLovinSDK", "UnityAds", "IronSource", "FBAudienceNetwork", "Appodeal", "ChartboostSDK", "VungleAdsSDK",
                "InMobiSDK", "PAGAdSDK", "BUAdSDK",
            ]
        default: []
        }
    }
}

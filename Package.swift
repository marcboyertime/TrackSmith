// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "LogicAudioAssistant",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "CAtomics", targets: ["CAtomics"]),
        .library(name: "PlanSchema", targets: ["PlanSchema"]),
        .library(name: "DSPCore", targets: ["DSPCore"]),
        .library(name: "AudioAnalysis", targets: ["AudioAnalysis"]),
        .library(name: "StateStore", targets: ["StateStore"]),
        .library(name: "AgentCore", targets: ["AgentCore"]),
        .library(name: "PreviewRenderer", targets: ["PreviewRenderer"]),
        .library(name: "LogicBridge", targets: ["LogicBridge"]),
        .library(name: "SharedIPC", targets: ["SharedIPC"]),
        .executable(name: "CompanionApp", targets: ["CompanionApp"]),
        .executable(name: "OfflineRenderer", targets: ["OfflineRenderer"]),
        .executable(name: "AnalysisCLI", targets: ["AnalysisCLI"]),
        .executable(name: "LogicIntegrationProbe", targets: ["LogicIntegrationProbe"]),
        .executable(name: "PluginProbe", targets: ["PluginProbe"]),
        .executable(name: "TestRunner", targets: ["TestRunner"]),
    ],
    targets: [
        .target(name: "CAtomics", path: "packages/CAtomics", publicHeadersPath: "include"),
        .target(name: "PlanSchema", path: "packages/PlanSchema/Sources/PlanSchema"),
        .target(name: "DSPCore", dependencies: ["PlanSchema"], path: "packages/DSPCore/Sources/DSPCore"),
        .target(name: "AudioAnalysis", dependencies: ["DSPCore", "CAtomics"], path: "packages/AudioAnalysis/Sources/AudioAnalysis"),
        .target(name: "StateStore", dependencies: ["PlanSchema"], path: "packages/StateStore/Sources/StateStore"),
        .target(name: "AgentCore", dependencies: ["PlanSchema", "AudioAnalysis", "StateStore"], path: "packages/AgentCore/Sources/AgentCore"),
        .target(name: "PreviewRenderer", dependencies: ["PlanSchema", "DSPCore", "AudioAnalysis"], path: "packages/PreviewRenderer/Sources/PreviewRenderer"),
        .target(name: "LogicBridge", dependencies: ["PlanSchema"], path: "packages/LogicBridge/Sources/LogicBridge"),
        .target(name: "SharedIPC", dependencies: ["PlanSchema"], path: "packages/SharedIPC/Sources/SharedIPC"),
        .executableTarget(name: "CompanionApp", dependencies: ["AgentCore", "PreviewRenderer", "SharedIPC", "DSPCore", "AudioAnalysis", "PlanSchema"], path: "apps/CompanionApp/Sources/CompanionApp"),
        .executableTarget(name: "OfflineRenderer", dependencies: ["DSPCore", "PlanSchema", "AudioAnalysis"], path: "tools/OfflineRenderer/Sources/OfflineRenderer"),
        .executableTarget(name: "AnalysisCLI", dependencies: ["AudioAnalysis", "DSPCore"], path: "tools/AnalysisCLI/Sources/AnalysisCLI"),
        .executableTarget(name: "LogicIntegrationProbe", dependencies: ["LogicBridge"], path: "tools/LogicIntegrationProbe/Sources/LogicIntegrationProbe"),
        .executableTarget(name: "PluginProbe", dependencies: ["SharedIPC"], path: "tools/PluginProbe/Sources/PluginProbe"),
        .executableTarget(name: "TestRunner", dependencies: ["PlanSchema", "DSPCore", "AudioAnalysis", "StateStore", "AgentCore", "PreviewRenderer", "SharedIPC"], path: "tests/TestRunner"),
    ]
)

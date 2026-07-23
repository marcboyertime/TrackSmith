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
        .library(name: "ProductionIntelligence", targets: ["ProductionIntelligence"]),
        .library(name: "PreviewRenderer", targets: ["PreviewRenderer"]),
        .library(name: "PreviewWorkflow", targets: ["PreviewWorkflow"]),
        .library(name: "LogicBridge", targets: ["LogicBridge"]),
        .library(name: "SharedIPC", targets: ["SharedIPC"]),
        .library(name: "SessionCore", targets: ["SessionCore"]),
        .library(name: "PreviewAudition", targets: ["PreviewAudition"]),
        .library(name: "AudioUnitExtensionCore", targets: ["AudioUnitExtensionCore"]),
        .library(name: "ResearchIngestion", targets: ["ResearchIngestion"]),
        .executable(name: "CompanionApp", targets: ["CompanionApp"]),
        .executable(name: "OfflineRenderer", targets: ["OfflineRenderer"]),
        .executable(name: "AnalysisCLI", targets: ["AnalysisCLI"]),
        .executable(name: "LogicIntegrationProbe", targets: ["LogicIntegrationProbe"]),
        .executable(name: "PluginProbe", targets: ["PluginProbe"]),
        .executable(name: "AudioUnitHostProbe", targets: ["AudioUnitHostProbe"]),
        .executable(name: "PreviewCLI", targets: ["PreviewCLI"]),
        .executable(name: "AuditionApp", targets: ["AuditionApp"]),
        .executable(name: "VerticalSliceCLI", targets: ["VerticalSliceCLI"]),
        .executable(name: "TestSignalGenerator", targets: ["TestSignalGenerator"]),
        .executable(name: "ResearchIngestCLI", targets: ["ResearchIngestCLI"]),
        .executable(name: "ProductionIntelligenceEvaluation", targets: ["ProductionIntelligenceEvaluation"]),
        .executable(name: "TestRunner", targets: ["TestRunner"]),
    ],
    targets: [
        .target(name: "CAtomics", path: "packages/CAtomics", publicHeadersPath: "include"),
        .target(name: "PlanSchema", path: "packages/PlanSchema/Sources/PlanSchema"),
        .target(name: "DSPCore", dependencies: ["PlanSchema"], path: "packages/DSPCore/Sources/DSPCore"),
        .target(name: "AudioAnalysis", dependencies: ["DSPCore", "CAtomics"], path: "packages/AudioAnalysis/Sources/AudioAnalysis"),
        .target(name: "StateStore", dependencies: ["PlanSchema"], path: "packages/StateStore/Sources/StateStore"),
        .target(name: "AgentCore", dependencies: ["PlanSchema", "AudioAnalysis", "StateStore"], path: "packages/AgentCore/Sources/AgentCore"),
        .target(
            name: "ProductionIntelligence",
            dependencies: ["AgentCore", "AudioAnalysis", "PlanSchema", "StateStore"],
            path: "packages/ProductionIntelligence/Sources/ProductionIntelligence",
            linkerSettings: [.linkedFramework("Security")]
        ),
        .target(name: "PreviewRenderer", dependencies: ["PlanSchema", "DSPCore", "AudioAnalysis"], path: "packages/PreviewRenderer/Sources/PreviewRenderer"),
        .target(name: "PreviewWorkflow", dependencies: ["AgentCore", "PreviewRenderer", "PlanSchema", "DSPCore", "AudioAnalysis"], path: "packages/PreviewWorkflow/Sources/PreviewWorkflow"),
        .target(name: "LogicBridge", dependencies: ["PlanSchema"], path: "packages/LogicBridge/Sources/LogicBridge"),
        .target(name: "SharedIPC", dependencies: ["PlanSchema"], path: "packages/SharedIPC/Sources/SharedIPC"),
        .target(
            name: "SessionCore",
            dependencies: ["AgentCore", "AudioAnalysis", "DSPCore", "SharedIPC", "PreviewRenderer", "PreviewWorkflow", "PlanSchema"],
            path: "packages/SessionCore/Sources/SessionCore"
        ),
        .target(
            name: "PreviewAudition",
            path: "packages/PreviewAudition/Sources/PreviewAudition"
        ),
        .target(
            name: "AudioUnitExtensionCore",
            dependencies: ["AudioAnalysis", "CAtomics", "DSPCore", "PlanSchema", "SharedIPC"],
            path: "plugins/AudioUnit/AudioUnitExtension",
            exclude: [
                "AssistantAudioUnitExtension.entitlements",
                "AudioUnitViewController.swift",
                "Info.plist",
            ]
        ),
        .target(name: "ResearchIngestion", path: "packages/ResearchIngestion/Sources/ResearchIngestion"),
        .executableTarget(name: "CompanionApp", dependencies: ["AgentCore", "ProductionIntelligence", "PreviewRenderer", "SharedIPC", "DSPCore", "AudioAnalysis", "PlanSchema"], path: "apps/CompanionApp/Sources/CompanionApp"),
        .executableTarget(name: "OfflineRenderer", dependencies: ["DSPCore", "PlanSchema", "AudioAnalysis"], path: "tools/OfflineRenderer/Sources/OfflineRenderer"),
        .executableTarget(name: "AnalysisCLI", dependencies: ["AudioAnalysis", "DSPCore"], path: "tools/AnalysisCLI/Sources/AnalysisCLI"),
        .executableTarget(name: "LogicIntegrationProbe", dependencies: ["LogicBridge"], path: "tools/LogicIntegrationProbe/Sources/LogicIntegrationProbe"),
        .executableTarget(name: "PluginProbe", dependencies: ["SharedIPC"], path: "tools/PluginProbe/Sources/PluginProbe"),
        .executableTarget(
            name: "AudioUnitHostProbe",
            dependencies: ["AudioUnitExtensionCore", "PlanSchema", "DSPCore", "SessionCore", "SharedIPC", "PreviewWorkflow"],
            path: "tools/AudioUnitHostProbe/Sources/AudioUnitHostProbe"
        ),
        .executableTarget(name: "PreviewCLI", dependencies: ["PreviewWorkflow", "PlanSchema"], path: "tools/PreviewCLI/Sources/PreviewCLI"),
        .executableTarget(name: "AuditionApp", dependencies: ["PreviewWorkflow", "DSPCore", "PlanSchema"], path: "tools/AuditionApp/Sources/AuditionApp"),
        .executableTarget(
            name: "VerticalSliceCLI",
            dependencies: ["PlanSchema", "DSPCore", "AudioAnalysis", "StateStore", "AgentCore", "PreviewRenderer"],
            path: "tools/VerticalSliceCLI/Sources/VerticalSliceCLI"
        ),
        .executableTarget(name: "TestSignalGenerator", dependencies: ["DSPCore"], path: "tools/TestSignalGenerator/Sources/TestSignalGenerator"),
        .executableTarget(name: "ResearchIngestCLI", dependencies: ["ResearchIngestion"], path: "tools/ResearchIngestCLI/Sources/ResearchIngestCLI"),
        .executableTarget(
            name: "ProductionIntelligenceEvaluation",
            dependencies: ["AgentCore", "AudioAnalysis", "DSPCore", "PlanSchema", "ProductionIntelligence", "PreviewWorkflow"],
            path: "tools/ProductionIntelligenceEvaluation/Sources/ProductionIntelligenceEvaluation"
        ),
        .executableTarget(name: "TestRunner", dependencies: ["PlanSchema", "DSPCore", "AudioAnalysis", "StateStore", "AgentCore", "ProductionIntelligence", "PreviewRenderer", "PreviewWorkflow", "SharedIPC", "SessionCore", "ResearchIngestion"], path: "tests/TestRunner"),
    ]
)

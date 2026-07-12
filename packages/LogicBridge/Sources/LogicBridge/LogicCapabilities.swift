import Foundation
import PlanSchema

public enum CapabilitySupport: String, Codable, Sendable { case supported, experimental, unsupported, unverified }
public enum LogicCapability: String, Codable, CaseIterable, Sendable {
    case transport, selectedTrack, selectedRegion, pluginInputAudio, sourceAudioFile, ownParameters
    case nativePluginControl, pluginInsertion, channelStripInspection, trackAutomation, trackCreation, bounceInPlace
}

public struct CapabilityResult: Codable, Equatable, Sendable {
    public var capability: LogicCapability
    public var support: CapabilitySupport
    public var evidence: String
}

public protocol LogicControlAdapter: Sendable {
    func capabilities() async -> [CapabilityResult]
    func verifyConnection() async throws -> Bool
}

public struct MockLogicAdapter: LogicControlAdapter {
    public init() {}
    public func verifyConnection() async throws -> Bool { true }
    public func capabilities() async -> [CapabilityResult] {
        LogicCapability.allCases.map { capability in
            switch capability {
            case .pluginInputAudio, .ownParameters:
                CapabilityResult(capability: capability, support: .supported, evidence: "Provided by the AUv3 render and parameter APIs; Logic-host validation remains pending.")
            case .transport:
                CapabilityResult(capability: capability, support: .unverified, evidence: "AUHostTransportStateBlock exists; host behavior must be tested in Logic.")
            case .selectedTrack, .nativePluginControl, .trackAutomation:
                CapabilityResult(capability: capability, support: .experimental, evidence: "Potential MIDI control-surface or Accessibility path; not part of the stable core.")
            default:
                CapabilityResult(capability: capability, support: .unsupported, evidence: "No public AU API discovered for this project operation.")
            }
        }
    }
}

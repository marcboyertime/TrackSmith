import AgentCore
import Foundation

/// Companion-process replay protection for provider response identities.
///
/// Providers still bind every result to a locally generated request and AU
/// authority. This guard adds a second boundary: a cloud response identity may
/// influence TrackSmith at most once in the current companion process. The
/// bounded FIFO deliberately stores identifiers only, never prompt or provider
/// output content.
public actor ProviderResponseReplayGuard {
    public static let shared = ProviderResponseReplayGuard()
    public static let maximumRememberedResponses = 4_096

    private var seen = Set<String>()
    private var order: [String] = []

    public init() {}

    public func register(
        providerIdentifier: String,
        responseIdentifier: String
    ) throws {
        let bounded = responseIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !bounded.isEmpty, bounded.utf8.count <= 512 else {
            throw ModelProviderFailure.malformedResponse("The provider response identity was missing or oversized.")
        }
        let key = "\(providerIdentifier)|\(bounded)"
        guard seen.insert(key).inserted else {
            throw ModelProviderFailure.duplicateResponse
        }
        order.append(key)
        if order.count > Self.maximumRememberedResponses {
            let removalCount = order.count - Self.maximumRememberedResponses
            let removed = Array(order.prefix(removalCount))
            order.removeFirst(removalCount)
            for key in removed { seen.remove(key) }
        }
    }
}

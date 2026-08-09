import Darwin
import Foundation
import VocalEvaluation

private let maximumJSONBytes = VocalEvaluationValidator.maximumExportBytes

private enum ListeningStudyCLIError: Error, CustomStringConvertible {
    case usage(String)
    case input(String)
    case output(String)
    case selfCheck(String)

    var description: String {
        switch self {
        case let .usage(message), let .input(message), let .output(message), let .selfCheck(message):
            return message
        }
    }
}

/// The only user-supplied material needed to finalize a blind response. It deliberately
/// contains neither candidate identities nor any answer-key field.
private struct OwnerFinalizationInput: Codable, Equatable {
    let conditions: VocalListeningConditions
    let judgments: [VocalCandidateJudgment]
    let preference: VocalPreference
    let confidence: Int
}

private enum StrictJSON {
    private static let planRoot: Set<String> = [
        "schemaVersion", "studyID", "targetDescription", "source", "candidates", "deterministicSeed",
        "levelMatchingRequired", "maximumLevelMismatchDB", "evidenceClass",
    ]
    private static let source: Set<String> = ["sourceID", "captureID", "sourceAudioSHA256"]
    private static let planCandidate: Set<String> = [
        "candidateID", "candidateSHA256", "processingPlanID", "processingPlanSHA256",
        "previewID", "assetID", "assetManifestSHA256", "renderedAudioSHA256", "sourceAudioSHA256",
        "originalSourceUnmodified", "renderIsReproducibleDerivative",
    ]
    private static let packageRoot: Set<String> = [
        "schemaVersion", "studyID", "targetDescription", "source", "candidates", "deterministicSeed",
        "levelMatchingRequired", "maximumLevelMismatchDB", "evidenceClass", "packageFingerprint",
    ]
    private static let blindCandidate: Set<String> = ["blindCode", "renderedAudioSHA256", "sourceAudioSHA256"]
    private static let answerKeyRoot: Set<String> = [
        "schemaVersion", "studyID", "packageFingerprint", "mappings", "keepSealedUntilJudgment",
        "answerKeyChecksum",
    ]
    private static let identityMapping: Set<String> = [
        "blindCode", "candidateID", "candidateSHA256", "processingPlanID", "processingPlanSHA256",
        "previewID", "assetID", "assetManifestSHA256", "renderedAudioSHA256",
    ]
    private static let finalizationRoot: Set<String> = ["conditions", "judgments", "preference", "confidence"]
    private static let conditions: Set<String> = [
        "transducer", "environment", "outputDeviceDescription", "levelMatched",
        "measuredMaximumLevelMismatchDB", "listeningMinutes", "fatigueBefore", "fatigueAfter",
    ]
    private static let judgment: Set<String> = ["blindCode", "scores", "note"]
    private static let scores: Set<String> = [
        "targetRelevance", "sourcePreservation", "naturalness", "intelligibility", "temporalCoherence",
        "usefulness",
    ]
    private static let preference: Set<String> = ["kind", "blindCode"]
    private static let responseRoot: Set<String> = [
        "schemaVersion", "studyID", "packageFingerprint", "evidenceClass", "listenerCount",
        "identitiesRemainedBlindDuringJudgment", "conditions", "judgments", "preference", "confidence",
        "finalized", "responseChecksum",
    ]
    private static let evidenceRoot: Set<String> = [
        "studyID", "packageFingerprint", "evidenceClass", "claimBoundary", "conditions", "results",
        "preferredCandidateID", "preferenceKind", "confidence",
    ]
    private static let evidenceResult: Set<String> = [
        "blindCode", "candidateID", "candidateSHA256", "processingPlanID", "processingPlanSHA256",
        "previewID", "assetID", "assetManifestSHA256", "renderedAudioSHA256", "scores", "note",
    ]

    static func validatePlan(_ data: Data) throws {
        let root = try rootObject(data, label: "study plan")
        try exactKeys(root, allowed: planRoot, path: "$plan")
        try validateSource(root["source"], path: "$plan.source")
        for (index, candidate) in try array(root["candidates"], path: "$plan.candidates").enumerated() {
            try exactKeys(
                try object(candidate, path: "$plan.candidates[\(index)]"),
                allowed: planCandidate,
                required: planCandidate.subtracting(["assetID", "assetManifestSHA256"]),
                path: "$plan.candidates[\(index)]"
            )
        }
    }

    static func validatePackage(_ data: Data) throws {
        let root = try rootObject(data, label: "participant package")
        try exactKeys(root, allowed: packageRoot, path: "$package")
        try validateSource(root["source"], path: "$package.source")
        for (index, candidate) in try array(root["candidates"], path: "$package.candidates").enumerated() {
            try exactKeys(
                try object(candidate, path: "$package.candidates[\(index)]"),
                allowed: blindCandidate,
                path: "$package.candidates[\(index)]"
            )
        }
    }

    static func validateAnswerKey(_ data: Data) throws {
        let root = try rootObject(data, label: "sealed answer key")
        try exactKeys(root, allowed: answerKeyRoot, path: "$answerKey")
        for (index, mapping) in try array(root["mappings"], path: "$answerKey.mappings").enumerated() {
            try exactKeys(
                try object(mapping, path: "$answerKey.mappings[\(index)]"),
                allowed: identityMapping,
                required: identityMapping.subtracting(["assetID", "assetManifestSHA256"]),
                path: "$answerKey.mappings[\(index)]"
            )
        }
    }

    static func validateFinalizationInput(_ data: Data) throws {
        let root = try rootObject(data, label: "owner finalization input")
        try exactKeys(root, allowed: finalizationRoot, path: "$ownerInput")
        try validateConditions(root["conditions"], path: "$ownerInput.conditions")
        try validatePreference(root["preference"], path: "$ownerInput.preference")
        try validateJudgments(root["judgments"], path: "$ownerInput.judgments")
    }

    static func validateResponse(_ data: Data) throws {
        let root = try rootObject(data, label: "formative response")
        try exactKeys(root, allowed: responseRoot, path: "$response")
        try validateConditions(root["conditions"], path: "$response.conditions")
        try validatePreference(root["preference"], path: "$response.preference")
        try validateJudgments(root["judgments"], path: "$response.judgments")
    }

    static func validateEvidence(_ data: Data) throws {
        let root = try rootObject(data, label: "unblinded evidence")
        try exactKeys(
            root,
            allowed: evidenceRoot,
            required: evidenceRoot.subtracting(["preferredCandidateID"]),
            path: "$evidence"
        )
        try validateConditions(root["conditions"], path: "$evidence.conditions")
        for (index, result) in try array(root["results"], path: "$evidence.results").enumerated() {
            let resultObject = try object(result, path: "$evidence.results[\(index)]")
            try exactKeys(
                resultObject,
                allowed: evidenceResult,
                required: evidenceResult.subtracting(["note", "assetID", "assetManifestSHA256"]),
                path: "$evidence.results[\(index)]"
            )
            try exactKeys(
                try object(resultObject["scores"], path: "$evidence.results[\(index)].scores"),
                allowed: scores,
                path: "$evidence.results[\(index)].scores"
            )
        }
    }

    private static func validateSource(_ value: Any?, path: String) throws {
        try exactKeys(try object(value, path: path), allowed: source, path: path)
    }

    private static func validateConditions(_ value: Any?, path: String) throws {
        try exactKeys(try object(value, path: path), allowed: conditions, path: path)
    }

    private static func validatePreference(_ value: Any?, path: String) throws {
        try exactKeys(
            try object(value, path: path),
            allowed: preference,
            required: ["kind"],
            path: path
        )
    }

    private static func validateJudgments(_ value: Any?, path: String) throws {
        for (index, judgmentValue) in try array(value, path: path).enumerated() {
            let judgmentObject = try object(judgmentValue, path: "\(path)[\(index)]")
            try exactKeys(
                judgmentObject,
                allowed: judgment,
                required: judgment.subtracting(["note"]),
                path: "\(path)[\(index)]"
            )
            try exactKeys(
                try object(judgmentObject["scores"], path: "\(path)[\(index)].scores"),
                allowed: scores,
                path: "\(path)[\(index)].scores"
            )
        }
    }

    private static func rootObject(_ data: Data, label: String) throws -> [String: Any] {
        guard !data.isEmpty, data.count <= maximumJSONBytes else {
            throw ListeningStudyCLIError.input("\(label) must be a non-empty JSON file no larger than \(maximumJSONBytes) bytes.")
        }
        do {
            return try object(JSONSerialization.jsonObject(with: data), path: "$\(label)")
        } catch let error as ListeningStudyCLIError {
            throw error
        } catch {
            throw ListeningStudyCLIError.input("\(label) is not valid JSON.")
        }
    }

    private static func object(_ value: Any?, path: String) throws -> [String: Any] {
        guard let object = value as? [String: Any] else {
            throw ListeningStudyCLIError.input("\(path) must be a JSON object.")
        }
        return object
    }

    private static func array(_ value: Any?, path: String) throws -> [Any] {
        guard let array = value as? [Any] else {
            throw ListeningStudyCLIError.input("\(path) must be a JSON array.")
        }
        return array
    }

    private static func exactKeys(
        _ object: [String: Any],
        allowed: Set<String>,
        required: Set<String>? = nil,
        path: String
    ) throws {
        let keys = Set(object.keys)
        let unexpected = keys.subtracting(allowed).sorted()
        guard unexpected.isEmpty else {
            throw ListeningStudyCLIError.input("\(path) has unknown key(s): \(unexpected.joined(separator: ", ")).")
        }
        let mandatory = required ?? allowed
        let missing = mandatory.subtracting(keys).sorted()
        guard missing.isEmpty else {
            throw ListeningStudyCLIError.input("\(path) is missing key(s): \(missing.joined(separator: ", ")).")
        }
    }
}

private enum AtomicOutputWriter {
    static func writeNew(_ data: Data, to destination: URL) throws {
        guard !data.isEmpty, data.count <= maximumJSONBytes else {
            throw ListeningStudyCLIError.output("Refusing to write an empty or oversized JSON export.")
        }

        let destination = destination.standardizedFileURL
        let parent = destination.deletingLastPathComponent()
        let values = try parent.resourceValues(forKeys: [.isDirectoryKey])
        guard values.isDirectory == true else {
            throw ListeningStudyCLIError.output("Output parent is not an existing directory: \(parent.path)")
        }
        guard !FileManager.default.fileExists(atPath: destination.path) else {
            throw ListeningStudyCLIError.output("Refusing to overwrite existing output: \(destination.path)")
        }

        let temporary = parent.appendingPathComponent(
            ".\(destination.lastPathComponent).\(UUID().uuidString).tmp",
            isDirectory: false
        )
        var shouldRemoveTemporary = false
        defer {
            if shouldRemoveTemporary {
                _ = temporary.path.withCString { Darwin.unlink($0) }
            }
        }

        let descriptor = temporary.path.withCString {
            Darwin.open($0, O_WRONLY | O_CREAT | O_EXCL, mode_t(0o600))
        }
        guard descriptor >= 0 else {
            throw ListeningStudyCLIError.output("Could not create atomic temporary output: \(posixMessage(errno))")
        }
        shouldRemoveTemporary = true
        var descriptorIsOpen = true
        defer {
            if descriptorIsOpen {
                _ = Darwin.close(descriptor)
            }
        }

        try writeFully(data, to: descriptor)
        guard Darwin.fsync(descriptor) == 0 else {
            throw ListeningStudyCLIError.output("Could not synchronize temporary output: \(posixMessage(errno))")
        }
        guard Darwin.fchmod(descriptor, mode_t(0o600)) == 0 else {
            throw ListeningStudyCLIError.output("Could not protect output permissions: \(posixMessage(errno))")
        }
        let closeResult = Darwin.close(descriptor)
        descriptorIsOpen = false
        guard closeResult == 0 else {
            throw ListeningStudyCLIError.output("Could not close temporary output: \(posixMessage(errno))")
        }

        let linked = temporary.path.withCString { temporaryPath in
            destination.path.withCString { destinationPath in
                Darwin.link(temporaryPath, destinationPath)
            }
        }
        guard linked == 0 else {
            throw ListeningStudyCLIError.output(
                "Refusing to overwrite or replace output \(destination.path): \(posixMessage(errno))"
            )
        }

        _ = temporary.path.withCString { Darwin.unlink($0) }
        shouldRemoveTemporary = false
    }

    private static func writeFully(_ data: Data, to descriptor: Int32) throws {
        var offset = 0
        while offset < data.count {
            let written = data.withUnsafeBytes { bytes -> Int in
                guard let baseAddress = bytes.baseAddress else { return -1 }
                return Darwin.write(descriptor, baseAddress.advanced(by: offset), data.count - offset)
            }
            if written > 0 {
                offset += written
            } else if written == -1, errno == EINTR {
                continue
            } else {
                throw ListeningStudyCLIError.output("Could not write temporary output: \(posixMessage(errno))")
            }
        }
    }

    private static func posixMessage(_ code: Int32) -> String {
        String(cString: strerror(code))
    }
}

private func run() throws {
    let arguments = Array(CommandLine.arguments.dropFirst())
    guard let command = arguments.first else {
        throw ListeningStudyCLIError.usage(usage)
    }

    switch command {
    case "--help", "help":
        guard arguments.count == 1 else { throw ListeningStudyCLIError.usage(usage) }
        print(usage)
    case "prepare":
        let options = try parseOptions(
            Array(arguments.dropFirst()),
            required: ["--plan", "--participant-package", "--sealed-key"]
        )
        try prepareStudy(
            planURL: localURL(options["--plan"]!),
            participantPackageURL: localURL(options["--participant-package"]!),
            sealedKeyURL: localURL(options["--sealed-key"]!)
        )
        print("Prepared blinded participant package and sealed key. Evidence class: SINGLE_LISTENER_FORMATIVE_EVIDENCE")
    case "finalize":
        let options = try parseOptions(
            Array(arguments.dropFirst()),
            required: ["--participant-package", "--owner-input", "--response"]
        )
        try finalizeStudy(
            participantPackageURL: localURL(options["--participant-package"]!),
            ownerInputURL: localURL(options["--owner-input"]!),
            responseURL: localURL(options["--response"]!)
        )
        print("Finalized blinded owner response. Evidence class: SINGLE_LISTENER_FORMATIVE_EVIDENCE")
    case "unblind":
        let options = try parseOptions(
            Array(arguments.dropFirst()),
            required: ["--participant-package", "--sealed-key", "--response", "--evidence"]
        )
        try unblindStudy(
            participantPackageURL: localURL(options["--participant-package"]!),
            sealedKeyURL: localURL(options["--sealed-key"]!),
            responseURL: localURL(options["--response"]!),
            evidenceURL: localURL(options["--evidence"]!)
        )
        print("Unblinded finalized formative evidence. Evidence class: SINGLE_LISTENER_FORMATIVE_EVIDENCE")
    case "selfcheck":
        guard arguments.count == 1 else { throw ListeningStudyCLIError.usage(usage) }
        try runSelfCheck()
        print("VocalListeningStudyCLI selfcheck: PASS (local deterministic fixture; no audio rendered and no listening claim made)")
    default:
        throw ListeningStudyCLIError.usage(usage)
    }
}

private func parseOptions(_ arguments: [String], required: Set<String>) throws -> [String: String] {
    guard arguments.count == required.count * 2 else {
        throw ListeningStudyCLIError.usage(usage)
    }
    var result: [String: String] = [:]
    var index = 0
    while index < arguments.count {
        let key = arguments[index]
        let value = arguments[index + 1]
        guard required.contains(key), !value.hasPrefix("--"), result[key] == nil else {
            throw ListeningStudyCLIError.usage(usage)
        }
        result[key] = value
        index += 2
    }
    guard Set(result.keys) == required else {
        throw ListeningStudyCLIError.usage(usage)
    }
    return result
}

private func localURL(_ path: String) -> URL {
    URL(fileURLWithPath: path).standardizedFileURL
}

private func prepareStudy(
    planURL: URL,
    participantPackageURL: URL,
    sealedKeyURL: URL
) throws {
    try verifyDistinctOutputs([participantPackageURL, sealedKeyURL])
    let plan = try decodePlan(at: planURL)
    let prepared = try VocalBlindedEvaluationRunner().prepare(plan)
    let exporter = VocalEvaluationExporter()
    let participantData = try exporter.encodeParticipantPackage(prepared.participantPackage)
    let keyData = try exporter.encodePrivateAnswerKey(
        prepared.privateAnswerKey,
        for: prepared.participantPackage
    )
    try AtomicOutputWriter.writeNew(participantData, to: participantPackageURL)
    try AtomicOutputWriter.writeNew(keyData, to: sealedKeyURL)
}

private func finalizeStudy(
    participantPackageURL: URL,
    ownerInputURL: URL,
    responseURL: URL
) throws {
    let package = try decodePackage(at: participantPackageURL)
    let ownerInput = try decodeOwnerInput(at: ownerInputURL)
    let response = try VocalBlindedEvaluationRunner().finalizeResponse(
        for: package,
        conditions: ownerInput.conditions,
        judgments: ownerInput.judgments,
        preference: ownerInput.preference,
        confidence: ownerInput.confidence
    )
    let responseData = try VocalEvaluationExporter().encodeResponse(response, for: package)
    try AtomicOutputWriter.writeNew(responseData, to: responseURL)
}

private func unblindStudy(
    participantPackageURL: URL,
    sealedKeyURL: URL,
    responseURL: URL,
    evidenceURL: URL
) throws {
    let package = try decodePackage(at: participantPackageURL)
    let response = try decodeResponse(at: responseURL, for: package)
    let answerKey = try decodeAnswerKey(at: sealedKeyURL, for: package)
    let evidence = try VocalBlindedEvaluationRunner().unblind(
        response: response,
        participantPackage: package,
        privateAnswerKey: answerKey
    )
    try AtomicOutputWriter.writeNew(try encodeBounded(evidence), to: evidenceURL)
}

private func verifyDistinctOutputs(_ urls: [URL]) throws {
    let paths = urls.map(\.standardizedFileURL.path)
    guard Set(paths).count == paths.count else {
        throw ListeningStudyCLIError.output("Each output path must be distinct.")
    }
    for path in paths where FileManager.default.fileExists(atPath: path) {
        throw ListeningStudyCLIError.output("Refusing to overwrite existing output: \(path)")
    }
}

private func decodePlan(at url: URL) throws -> VocalBlindedStudyPlan {
    let data = try loadBoundedJSON(at: url)
    try StrictJSON.validatePlan(data)
    let plan: VocalBlindedStudyPlan = try decode(data, label: "study plan")
    try VocalEvaluationValidator.validate(plan: plan)
    return plan
}

private func decodePackage(at url: URL) throws -> VocalBlindedStudyPackage {
    let data = try loadBoundedJSON(at: url)
    try StrictJSON.validatePackage(data)
    let package: VocalBlindedStudyPackage = try decode(data, label: "participant package")
    try VocalEvaluationValidator.validate(package: package)
    return package
}

private func decodeAnswerKey(
    at url: URL,
    for package: VocalBlindedStudyPackage
) throws -> VocalPrivateAnswerKey {
    let data = try loadBoundedJSON(at: url)
    try StrictJSON.validateAnswerKey(data)
    let answerKey: VocalPrivateAnswerKey = try decode(data, label: "sealed answer key")
    try VocalEvaluationValidator.validate(answerKey: answerKey, for: package)
    return answerKey
}

private func decodeOwnerInput(at url: URL) throws -> OwnerFinalizationInput {
    let data = try loadBoundedJSON(at: url)
    try StrictJSON.validateFinalizationInput(data)
    return try decode(data, label: "owner finalization input")
}

private func decodeResponse(
    at url: URL,
    for package: VocalBlindedStudyPackage
) throws -> VocalFormativeResponse {
    let data = try loadBoundedJSON(at: url)
    try StrictJSON.validateResponse(data)
    return try VocalEvaluationExporter().decodeResponse(data, for: package)
}

private func decodeEvidence(_ data: Data) throws -> VocalSingleListenerFormativeEvidence {
    try StrictJSON.validateEvidence(data)
    return try decode(data, label: "unblinded evidence")
}

private func loadBoundedJSON(at url: URL) throws -> Data {
    let values = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
    guard values.isRegularFile == true,
          let size = values.fileSize,
          (1...maximumJSONBytes).contains(size) else {
        throw ListeningStudyCLIError.input(
            "Input must be a regular JSON file within 1...\(maximumJSONBytes) bytes: \(url.path)"
        )
    }
    let data = try Data(contentsOf: url, options: [.mappedIfSafe])
    guard data.count == size else {
        throw ListeningStudyCLIError.input("Input changed while it was read: \(url.path)")
    }
    return data
}

private func decode<T: Decodable>(_ data: Data, label: String) throws -> T {
    do {
        return try JSONDecoder().decode(T.self, from: data)
    } catch {
        throw ListeningStudyCLIError.input("\(label) does not match the required JSON contract.")
    }
}

private func encodeBounded<T: Encodable>(_ value: T) throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    let data = try encoder.encode(value)
    guard !data.isEmpty, data.count <= maximumJSONBytes else {
        throw ListeningStudyCLIError.output("JSON export exceeds its fixed \(maximumJSONBytes)-byte bound.")
    }
    return data
}

private func runSelfCheck() throws {
    let manager = FileManager.default
    let directory = manager.temporaryDirectory.appendingPathComponent(
        "tracksmith-vocal-listening-selfcheck-\(UUID().uuidString)",
        isDirectory: true
    )
    try manager.createDirectory(at: directory, withIntermediateDirectories: false)
    defer { try? manager.removeItem(at: directory) }

    let plan = VocalEvaluationDeterministicFixtures.plan()
    let planURL = directory.appendingPathComponent("plan.json")
    let packageURL = directory.appendingPathComponent("participant-package.json")
    let answerKeyURL = directory.appendingPathComponent("sealed-answer-key.json")
    try AtomicOutputWriter.writeNew(try encodeBounded(plan), to: planURL)

    try prepareStudy(
        planURL: planURL,
        participantPackageURL: packageURL,
        sealedKeyURL: answerKeyURL
    )
    let package = try decodePackage(at: packageURL)
    let answerKey = try decodeAnswerKey(at: answerKeyURL, for: package)
    let expectedPrepared = try VocalBlindedEvaluationRunner().prepare(plan)
    try selfCheck(package == expectedPrepared.participantPackage, "prepared participant package did not replay deterministically")
    try selfCheck(answerKey == expectedPrepared.privateAnswerKey, "prepared answer key did not replay deterministically")

    let exporter = VocalEvaluationExporter()
    let packageData = try loadBoundedJSON(at: packageURL)
    let exactPackageData = try exporter.encodeParticipantPackage(package)
    try selfCheck(
        packageData == exactPackageData,
        "participant package did not reload with an exact export"
    )
    let answerKeyData = try loadBoundedJSON(at: answerKeyURL)
    let exactAnswerKeyData = try exporter.encodePrivateAnswerKey(answerKey, for: package)
    try selfCheck(
        answerKeyData == exactAnswerKeyData,
        "sealed answer key did not reload with an exact export"
    )
    let participantText = String(decoding: packageData, as: UTF8.self)
    try selfCheck(
        !plan.candidates.contains(where: {
            participantText.contains($0.candidateID)
                || participantText.contains($0.candidateSHA256)
                || participantText.contains($0.processingPlanID)
                || participantText.contains($0.processingPlanSHA256)
                || participantText.contains($0.previewID)
                || $0.assetID.map(participantText.contains) == true
                || $0.assetManifestSHA256.map(participantText.contains) == true
        }),
        "participant package disclosed a private candidate, plan, preview, or asset identity"
    )

    let replayPackageURL = directory.appendingPathComponent("participant-package-replay.json")
    let replayKeyURL = directory.appendingPathComponent("sealed-answer-key-replay.json")
    try prepareStudy(
        planURL: planURL,
        participantPackageURL: replayPackageURL,
        sealedKeyURL: replayKeyURL
    )
    let replayPackageData = try loadBoundedJSON(at: replayPackageURL)
    try selfCheck(
        replayPackageData == packageData,
        "repeat prepare produced a different blind order"
    )
    try expectFailure("prepare overwrite refusal") {
        try prepareStudy(
            planURL: planURL,
            participantPackageURL: packageURL,
            sealedKeyURL: answerKeyURL
        )
    }

    let judgments = package.candidates.map {
        VocalCandidateJudgment(
            blindCode: $0.blindCode,
            scores: VocalCandidateScores(
                targetRelevance: 5,
                sourcePreservation: 6,
                naturalness: 5,
                intelligibility: 6,
                temporalCoherence: 6,
                usefulness: 5
            ),
            note: "mechanical selfcheck fixture only"
        )
    }
    let conditions = VocalListeningConditions(
        transducer: .headphones,
        environment: .quietUntreated,
        outputDeviceDescription: "deterministic-selfcheck-device",
        levelMatched: true,
        measuredMaximumLevelMismatchDB: 0.1,
        listeningMinutes: 8,
        fatigueBefore: 1,
        fatigueAfter: 2
    )

    let noPreferenceInput = OwnerFinalizationInput(
        conditions: conditions,
        judgments: judgments,
        preference: .noPreference,
        confidence: 4
    )
    let noPreferenceInputURL = directory.appendingPathComponent("owner-input-no-preference.json")
    let noPreferenceResponseURL = directory.appendingPathComponent("response-no-preference.json")
    try AtomicOutputWriter.writeNew(try encodeBounded(noPreferenceInput), to: noPreferenceInputURL)
    try finalizeStudy(
        participantPackageURL: packageURL,
        ownerInputURL: noPreferenceInputURL,
        responseURL: noPreferenceResponseURL
    )
    let noPreferenceResponse = try decodeResponse(at: noPreferenceResponseURL, for: package)
    try selfCheck(
        noPreferenceResponse.preference == .noPreference,
        "no-preference response was not preserved"
    )
    let noPreferenceResponseData = try loadBoundedJSON(at: noPreferenceResponseURL)
    let exactNoPreferenceResponseData = try exporter.encodeResponse(noPreferenceResponse, for: package)
    try selfCheck(
        noPreferenceResponseData == exactNoPreferenceResponseData,
        "response did not reload with an exact export"
    )

    let noneInput = OwnerFinalizationInput(
        conditions: conditions,
        judgments: judgments,
        preference: .none,
        confidence: 3
    )
    let noneInputURL = directory.appendingPathComponent("owner-input-none-acceptable.json")
    let noneResponseURL = directory.appendingPathComponent("response-none-acceptable.json")
    try AtomicOutputWriter.writeNew(try encodeBounded(noneInput), to: noneInputURL)
    try finalizeStudy(
        participantPackageURL: packageURL,
        ownerInputURL: noneInputURL,
        responseURL: noneResponseURL
    )
    let noneResponse = try decodeResponse(at: noneResponseURL, for: package)
    try selfCheck(noneResponse.preference == .none, "none-acceptable response was not preserved")

    let evidenceURL = directory.appendingPathComponent("unblinded-evidence.json")
    try unblindStudy(
        participantPackageURL: packageURL,
        sealedKeyURL: answerKeyURL,
        responseURL: noPreferenceResponseURL,
        evidenceURL: evidenceURL
    )
    let evidenceData = try loadBoundedJSON(at: evidenceURL)
    let evidence = try decodeEvidence(evidenceData)
    let expectedEvidence = try VocalBlindedEvaluationRunner().unblind(
        response: noPreferenceResponse,
        participantPackage: package,
        privateAnswerKey: answerKey
    )
    try selfCheck(evidence == expectedEvidence, "unblinded evidence did not reload exactly")
    let exactEvidenceData = try encodeBounded(evidence)
    try selfCheck(evidenceData == exactEvidenceData, "evidence did not retain its exact export")
    try selfCheck(evidence.preferredCandidateID == nil, "no-preference response unexpectedly selected a candidate")

    let noneEvidenceURL = directory.appendingPathComponent("unblinded-none-acceptable-evidence.json")
    try unblindStudy(
        participantPackageURL: packageURL,
        sealedKeyURL: answerKeyURL,
        responseURL: noneResponseURL,
        evidenceURL: noneEvidenceURL
    )
    let noneEvidence = try decodeEvidence(try loadBoundedJSON(at: noneEvidenceURL))
    try selfCheck(
        noneEvidence.preferenceKind == .none && noneEvidence.preferredCandidateID == nil,
        "none-acceptable path unexpectedly selected a candidate"
    )

    var tamperedResponse = noPreferenceResponse
    tamperedResponse.responseChecksum = "fnv1a64:0000000000000000"
    let tamperedResponseURL = directory.appendingPathComponent("tampered-response.json")
    let rejectedResponseEvidenceURL = directory.appendingPathComponent("rejected-response-evidence.json")
    try AtomicOutputWriter.writeNew(try encodeBounded(tamperedResponse), to: tamperedResponseURL)
    try expectFailure("tampered response rejection") {
        try unblindStudy(
            participantPackageURL: packageURL,
            sealedKeyURL: answerKeyURL,
            responseURL: tamperedResponseURL,
            evidenceURL: rejectedResponseEvidenceURL
        )
    }
    try selfCheck(
        !manager.fileExists(atPath: rejectedResponseEvidenceURL.path),
        "tampered response created an evidence export"
    )

    var unfinalizedResponse = noPreferenceResponse
    unfinalizedResponse.finalized = false
    let unfinalizedResponseURL = directory.appendingPathComponent("unfinalized-response.json")
    let rejectedUnfinalizedEvidenceURL = directory.appendingPathComponent("rejected-unfinalized-evidence.json")
    try AtomicOutputWriter.writeNew(try encodeBounded(unfinalizedResponse), to: unfinalizedResponseURL)
    try expectFailure("unfinalized response rejection") {
        try unblindStudy(
            participantPackageURL: packageURL,
            sealedKeyURL: answerKeyURL,
            responseURL: unfinalizedResponseURL,
            evidenceURL: rejectedUnfinalizedEvidenceURL
        )
    }
    try selfCheck(
        !manager.fileExists(atPath: rejectedUnfinalizedEvidenceURL.path),
        "unfinalized response created an evidence export"
    )

    var tamperedKey = answerKey
    tamperedKey.mappings[0].candidateID = "tampered-candidate"
    let tamperedKeyURL = directory.appendingPathComponent("tampered-answer-key.json")
    let rejectedKeyEvidenceURL = directory.appendingPathComponent("rejected-key-evidence.json")
    try AtomicOutputWriter.writeNew(try encodeBounded(tamperedKey), to: tamperedKeyURL)
    try expectFailure("tampered sealed key rejection") {
        try unblindStudy(
            participantPackageURL: packageURL,
            sealedKeyURL: tamperedKeyURL,
            responseURL: noPreferenceResponseURL,
            evidenceURL: rejectedKeyEvidenceURL
        )
    }
    try selfCheck(
        !manager.fileExists(atPath: rejectedKeyEvidenceURL.path),
        "tampered sealed key created an evidence export"
    )

    var tamperedPackage = package
    tamperedPackage.packageFingerprint = "fnv1a64:0000000000000000"
    let tamperedPackageURL = directory.appendingPathComponent("tampered-participant-package.json")
    let rejectedPackageEvidenceURL = directory.appendingPathComponent("rejected-package-evidence.json")
    try AtomicOutputWriter.writeNew(try encodeBounded(tamperedPackage), to: tamperedPackageURL)
    try expectFailure("tampered participant package rejection") {
        try unblindStudy(
            participantPackageURL: tamperedPackageURL,
            sealedKeyURL: answerKeyURL,
            responseURL: noPreferenceResponseURL,
            evidenceURL: rejectedPackageEvidenceURL
        )
    }
    try selfCheck(
        !manager.fileExists(atPath: rejectedPackageEvidenceURL.path),
        "tampered participant package created an evidence export"
    )
}

private func selfCheck(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    guard condition() else { throw ListeningStudyCLIError.selfCheck(message) }
}

private func expectFailure(_ label: String, _ body: () throws -> Void) throws {
    do {
        try body()
    } catch {
        return
    }
    throw ListeningStudyCLIError.selfCheck("\(label) unexpectedly succeeded")
}

private let usage = """
Usage:
  VocalListeningStudyCLI prepare --plan PLAN.json --participant-package PACKAGE.json --sealed-key KEY.json
  VocalListeningStudyCLI finalize --participant-package PACKAGE.json --owner-input OWNER_INPUT.json --response RESPONSE.json
  VocalListeningStudyCLI unblind --participant-package PACKAGE.json --sealed-key KEY.json --response RESPONSE.json --evidence EVIDENCE.json
  VocalListeningStudyCLI selfcheck

All inputs and outputs are local bounded JSON (maximum \(maximumJSONBytes) bytes). Outputs are atomic, private, and never overwritten.
"""

do {
    try run()
} catch {
    FileHandle.standardError.write(Data("error: \(error)\n".utf8))
    exit(2)
}

import Foundation

public struct VocalBlindedEvaluationRunner: Sendable {
    public static let maximumCandidates = 8

    public init() {}

    public func prepare(_ plan: VocalBlindedStudyPlan) throws -> PreparedVocalBlindedStudy {
        try VocalEvaluationValidator.validate(plan: plan)
        var generator = VocalFixedLCG(
            state: plan.deterministicSeed ^ VocalStableFNV1a.value(plan.studyID)
        )
        var shuffled = Array(plan.candidates.indices)
        if shuffled.count > 1 {
            for index in stride(from: shuffled.count - 1, through: 1, by: -1) {
                let replacement = Int(generator.next() % UInt64(index + 1))
                shuffled.swapAt(index, replacement)
            }
        }

        var blindCandidates: [VocalBlindCandidate] = []
        var mappings: [VocalBlindIdentityMapping] = []
        for (position, candidateIndex) in shuffled.enumerated() {
            let code = Self.blindCode(for: position)
            let candidate = plan.candidates[candidateIndex]
            blindCandidates.append(
                VocalBlindCandidate(
                    blindCode: code,
                    renderedAudioSHA256: candidate.renderedAudioSHA256,
                    sourceAudioSHA256: candidate.sourceAudioSHA256
                )
            )
            mappings.append(
                VocalBlindIdentityMapping(
                    blindCode: code,
                    candidateID: candidate.candidateID,
                    candidateSHA256: candidate.candidateSHA256,
                    processingPlanID: candidate.processingPlanID,
                    processingPlanSHA256: candidate.processingPlanSHA256,
                    previewID: candidate.previewID,
                    assetID: candidate.assetID,
                    assetManifestSHA256: candidate.assetManifestSHA256,
                    renderedAudioSHA256: candidate.renderedAudioSHA256
                )
            )
        }

        let fingerprint = VocalEvaluationValidator.packageFingerprint(
            studyID: plan.studyID,
            targetDescription: plan.targetDescription,
            source: plan.source,
            candidates: blindCandidates,
            deterministicSeed: plan.deterministicSeed,
            levelMatchingRequired: plan.levelMatchingRequired,
            maximumLevelMismatchDB: plan.maximumLevelMismatchDB
        )
        let participant = VocalBlindedStudyPackage(
            studyID: plan.studyID,
            targetDescription: plan.targetDescription,
            source: plan.source,
            candidates: blindCandidates,
            deterministicSeed: plan.deterministicSeed,
            levelMatchingRequired: plan.levelMatchingRequired,
            maximumLevelMismatchDB: plan.maximumLevelMismatchDB,
            evidenceClass: .singleListenerFormativeEvidence,
            packageFingerprint: fingerprint
        )
        let answerKey = VocalPrivateAnswerKey(
            studyID: plan.studyID,
            packageFingerprint: fingerprint,
            mappings: mappings,
            answerKeyChecksum: VocalEvaluationValidator.answerKeyChecksum(
                packageFingerprint: fingerprint,
                mappings: mappings
            )
        )
        let prepared = PreparedVocalBlindedStudy(
            participantPackage: participant,
            privateAnswerKey: answerKey
        )
        try VocalEvaluationValidator.validate(prepared: prepared)
        return prepared
    }

    public func finalizeResponse(
        for package: VocalBlindedStudyPackage,
        conditions: VocalListeningConditions,
        judgments: [VocalCandidateJudgment],
        preference: VocalPreference,
        confidence: Int
    ) throws -> VocalFormativeResponse {
        let checksum = VocalEvaluationValidator.responseChecksum(
            studyID: package.studyID,
            packageFingerprint: package.packageFingerprint,
            conditions: conditions,
            judgments: judgments,
            preference: preference,
            confidence: confidence
        )
        let response = VocalFormativeResponse(
            studyID: package.studyID,
            packageFingerprint: package.packageFingerprint,
            conditions: conditions,
            judgments: judgments,
            preference: preference,
            confidence: confidence,
            responseChecksum: checksum
        )
        try VocalEvaluationValidator.validate(response: response, for: package)
        return response
    }

    /// Candidate identities are disclosed only after a finalized blind response validates.
    public func unblind(
        response: VocalFormativeResponse,
        participantPackage: VocalBlindedStudyPackage,
        privateAnswerKey: VocalPrivateAnswerKey
    ) throws -> VocalSingleListenerFormativeEvidence {
        try VocalEvaluationValidator.validate(response: response, for: participantPackage)
        try VocalEvaluationValidator.validate(
            answerKey: privateAnswerKey,
            for: participantPackage
        )
        guard response.finalized, response.identitiesRemainedBlindDuringJudgment else {
            throw VocalEvaluationError.invalid("Candidate identities cannot be disclosed before blind judgment.")
        }

        let mappingByCode = Dictionary(
            uniqueKeysWithValues: privateAnswerKey.mappings.map { ($0.blindCode, $0) }
        )
        let results = try response.judgments.map { judgment in
            guard let mapping = mappingByCode[judgment.blindCode] else {
                throw VocalEvaluationError.invalid("A blind code has no private identity mapping.")
            }
            return VocalUnblindedCandidateResult(
                blindCode: judgment.blindCode,
                candidateID: mapping.candidateID,
                candidateSHA256: mapping.candidateSHA256,
                processingPlanID: mapping.processingPlanID,
                processingPlanSHA256: mapping.processingPlanSHA256,
                previewID: mapping.previewID,
                assetID: mapping.assetID,
                assetManifestSHA256: mapping.assetManifestSHA256,
                renderedAudioSHA256: mapping.renderedAudioSHA256,
                scores: judgment.scores,
                note: judgment.note
            )
        }
        let preferredCandidateID: String?
        if response.preference.kind == .candidate,
           let code = response.preference.blindCode {
            preferredCandidateID = mappingByCode[code]?.candidateID
        } else {
            preferredCandidateID = nil
        }
        return VocalSingleListenerFormativeEvidence(
            studyID: response.studyID,
            packageFingerprint: response.packageFingerprint,
            evidenceClass: .singleListenerFormativeEvidence,
            claimBoundary: "One product-owner listening judgment; formative only; not expert or population evidence.",
            conditions: response.conditions,
            results: results,
            preferredCandidateID: preferredCandidateID,
            preferenceKind: response.preference.kind,
            confidence: response.confidence
        )
    }

    public func validateDeterministicReplay(
        plan: VocalBlindedStudyPlan,
        prepared: PreparedVocalBlindedStudy
    ) throws {
        let replayed = try prepare(plan)
        guard replayed == prepared else {
            throw VocalEvaluationError.invalid("The blinded assignment does not replay deterministically.")
        }
    }

    private static func blindCode(for index: Int) -> String {
        String(UnicodeScalar(65 + index)!)
    }
}

public struct VocalEvaluationValidator: Sendable {
    public static let maximumExportBytes = 1_048_576

    public init() {}

    public static func validate(plan: VocalBlindedStudyPlan) throws {
        guard plan.schemaVersion == VocalBlindedStudyPlan.schemaVersion,
              plan.evidenceClass == .singleListenerFormativeEvidence else {
            throw VocalEvaluationError.invalid("The study plan schema or evidence class is invalid.")
        }
        try requireIdentifier(plan.studyID, field: "studyID")
        try requireBoundedText(plan.targetDescription, field: "targetDescription", maximumBytes: 1_024)
        try validate(source: plan.source)
        guard (2...VocalBlindedEvaluationRunner.maximumCandidates).contains(plan.candidates.count) else {
            throw VocalEvaluationError.invalid("A blind study requires two through eight candidates.")
        }
        guard plan.levelMatchingRequired,
              plan.maximumLevelMismatchDB.isFinite,
              (0...1).contains(plan.maximumLevelMismatchDB) else {
            throw VocalEvaluationError.invalid("A bounded level-matching requirement is mandatory.")
        }
        var candidateIDs = Set<String>()
        var candidateHashes = Set<String>()
        var processingPlanIDs = Set<String>()
        var processingPlanHashes = Set<String>()
        var previewIDs = Set<String>()
        var assetIDs = Set<String>()
        var renderHashes = Set<String>()
        for candidate in plan.candidates {
            try requireIdentifier(candidate.candidateID, field: "candidateID")
            try requireSHA256(candidate.candidateSHA256, field: "candidateSHA256")
            try requireIdentifier(candidate.processingPlanID, field: "processingPlanID")
            try requireSHA256(candidate.processingPlanSHA256, field: "processingPlanSHA256")
            try requireIdentifier(candidate.previewID, field: "previewID")
            guard (candidate.assetID == nil) == (candidate.assetManifestSHA256 == nil) else {
                throw VocalEvaluationError.invalid(
                    "An asset identity and asset-manifest hash must either both be present or both be absent."
                )
            }
            if let assetID = candidate.assetID,
               let assetManifestSHA256 = candidate.assetManifestSHA256 {
                try requireIdentifier(assetID, field: "assetID")
                try requireSHA256(assetManifestSHA256, field: "assetManifestSHA256")
                guard assetIDs.insert(assetID).inserted else {
                    throw VocalEvaluationError.invalid("Asset identities must be unique.")
                }
            }
            try requireSHA256(candidate.renderedAudioSHA256, field: "renderedAudioSHA256")
            try requireSHA256(candidate.sourceAudioSHA256, field: "sourceAudioSHA256")
            guard candidate.sourceAudioSHA256 == plan.source.sourceAudioSHA256,
                  candidate.originalSourceUnmodified,
                  candidate.renderIsReproducibleDerivative else {
                throw VocalEvaluationError.invalid("A candidate does not preserve the exact source identity.")
            }
            guard candidateIDs.insert(candidate.candidateID).inserted,
                  candidateHashes.insert(candidate.candidateSHA256).inserted,
                  processingPlanIDs.insert(candidate.processingPlanID).inserted,
                  processingPlanHashes.insert(candidate.processingPlanSHA256).inserted,
                  previewIDs.insert(candidate.previewID).inserted,
                  renderHashes.insert(candidate.renderedAudioSHA256).inserted else {
                throw VocalEvaluationError.invalid(
                    "Candidate, processing-plan, preview, and render identities and hashes must be unique."
                )
            }
        }
    }

    public static func validate(prepared: PreparedVocalBlindedStudy) throws {
        try validate(package: prepared.participantPackage)
        try validate(answerKey: prepared.privateAnswerKey, for: prepared.participantPackage)
    }

    public static func validate(package: VocalBlindedStudyPackage) throws {
        guard package.schemaVersion == VocalBlindedStudyPackage.schemaVersion,
              package.evidenceClass == .singleListenerFormativeEvidence else {
            throw VocalEvaluationError.invalid("The participant package schema or evidence class is invalid.")
        }
        try requireIdentifier(package.studyID, field: "studyID")
        try requireBoundedText(package.targetDescription, field: "targetDescription", maximumBytes: 1_024)
        try validate(source: package.source)
        guard (2...VocalBlindedEvaluationRunner.maximumCandidates).contains(package.candidates.count),
              package.levelMatchingRequired,
              package.maximumLevelMismatchDB.isFinite,
              (0...1).contains(package.maximumLevelMismatchDB) else {
            throw VocalEvaluationError.invalid("The participant package bounds are invalid.")
        }
        var blindCodes = Set<String>()
        var renderHashes = Set<String>()
        for (index, candidate) in package.candidates.enumerated() {
            let expectedCode = String(UnicodeScalar(65 + index)!)
            guard candidate.blindCode == expectedCode,
                  blindCodes.insert(candidate.blindCode).inserted else {
                throw VocalEvaluationError.invalid("Blind codes must be unique and deterministically ordered.")
            }
            try requireSHA256(candidate.renderedAudioSHA256, field: "renderedAudioSHA256")
            try requireSHA256(candidate.sourceAudioSHA256, field: "sourceAudioSHA256")
            guard candidate.sourceAudioSHA256 == package.source.sourceAudioSHA256,
                  renderHashes.insert(candidate.renderedAudioSHA256).inserted else {
                throw VocalEvaluationError.invalid("Participant candidate hashes are mismatched or repeated.")
            }
        }
        let expected = packageFingerprint(
            studyID: package.studyID,
            targetDescription: package.targetDescription,
            source: package.source,
            candidates: package.candidates,
            deterministicSeed: package.deterministicSeed,
            levelMatchingRequired: package.levelMatchingRequired,
            maximumLevelMismatchDB: package.maximumLevelMismatchDB
        )
        guard package.packageFingerprint == expected else {
            throw VocalEvaluationError.invalid("The participant package fingerprint does not match.")
        }
    }

    public static func validate(
        answerKey: VocalPrivateAnswerKey,
        for package: VocalBlindedStudyPackage
    ) throws {
        guard answerKey.schemaVersion == VocalPrivateAnswerKey.schemaVersion,
              answerKey.studyID == package.studyID,
              answerKey.packageFingerprint == package.packageFingerprint,
              answerKey.keepSealedUntilJudgment,
              answerKey.mappings.count == package.candidates.count else {
            throw VocalEvaluationError.invalid("The private answer key does not match the participant package.")
        }
        var codes = Set<String>()
        var candidateIDs = Set<String>()
        var processingPlanIDs = Set<String>()
        var previewIDs = Set<String>()
        var assetIDs = Set<String>()
        for mapping in answerKey.mappings {
            try requireIdentifier(mapping.candidateID, field: "candidateID")
            try requireSHA256(mapping.candidateSHA256, field: "candidateSHA256")
            try requireIdentifier(mapping.processingPlanID, field: "processingPlanID")
            try requireSHA256(mapping.processingPlanSHA256, field: "processingPlanSHA256")
            try requireIdentifier(mapping.previewID, field: "previewID")
            guard (mapping.assetID == nil) == (mapping.assetManifestSHA256 == nil) else {
                throw VocalEvaluationError.invalid(
                    "An answer-key asset identity and manifest hash must be paired."
                )
            }
            if let assetID = mapping.assetID,
               let assetManifestSHA256 = mapping.assetManifestSHA256 {
                try requireIdentifier(assetID, field: "assetID")
                try requireSHA256(assetManifestSHA256, field: "assetManifestSHA256")
                guard assetIDs.insert(assetID).inserted else {
                    throw VocalEvaluationError.invalid("Answer-key asset identities must be unique.")
                }
            }
            try requireSHA256(mapping.renderedAudioSHA256, field: "renderedAudioSHA256")
            guard codes.insert(mapping.blindCode).inserted,
                  candidateIDs.insert(mapping.candidateID).inserted,
                  processingPlanIDs.insert(mapping.processingPlanID).inserted,
                  previewIDs.insert(mapping.previewID).inserted,
                  package.candidates.contains(where: {
                      $0.blindCode == mapping.blindCode
                          && $0.renderedAudioSHA256 == mapping.renderedAudioSHA256
                  }) else {
                throw VocalEvaluationError.invalid("The private answer key contains a mismatched mapping.")
            }
        }
        guard answerKey.answerKeyChecksum == answerKeyChecksum(
            packageFingerprint: package.packageFingerprint,
            mappings: answerKey.mappings
        ) else {
            throw VocalEvaluationError.invalid("The private answer-key checksum does not match.")
        }
    }

    public static func validate(
        response: VocalFormativeResponse,
        for package: VocalBlindedStudyPackage
    ) throws {
        try validate(package: package)
        guard response.schemaVersion == VocalFormativeResponse.schemaVersion,
              response.studyID == package.studyID,
              response.packageFingerprint == package.packageFingerprint,
              response.evidenceClass == .singleListenerFormativeEvidence,
              response.listenerCount == 1,
              response.identitiesRemainedBlindDuringJudgment,
              response.finalized,
              (1...5).contains(response.confidence) else {
            throw VocalEvaluationError.invalid("The formative response identity or claim boundary is invalid.")
        }
        try validate(conditions: response.conditions, for: package)
        guard response.judgments.count == package.candidates.count else {
            throw VocalEvaluationError.invalid("Every blind candidate must receive one judgment.")
        }
        var judgedCodes = Set<String>()
        for (index, judgment) in response.judgments.enumerated() {
            guard index < package.candidates.count,
                  judgment.blindCode == package.candidates[index].blindCode,
                  judgedCodes.insert(judgment.blindCode).inserted else {
                throw VocalEvaluationError.invalid("Judgments must follow the deterministic blind order.")
            }
            try validate(scores: judgment.scores)
            if let note = judgment.note {
                try requireBoundedText(note, field: "note", maximumBytes: 2_048, allowEmpty: true)
            }
        }
        switch response.preference.kind {
        case .candidate:
            guard let code = response.preference.blindCode, judgedCodes.contains(code) else {
                throw VocalEvaluationError.invalid("A candidate preference must name a valid blind code.")
            }
        case .none, .noPreference:
            guard response.preference.blindCode == nil else {
                throw VocalEvaluationError.invalid("None/no-preference cannot carry a blind code.")
            }
        }
        let checksum = responseChecksum(
            studyID: response.studyID,
            packageFingerprint: response.packageFingerprint,
            conditions: response.conditions,
            judgments: response.judgments,
            preference: response.preference,
            confidence: response.confidence
        )
        guard checksum == response.responseChecksum else {
            throw VocalEvaluationError.invalid("The response replay checksum does not match.")
        }
    }

    public static func packageFingerprint(
        studyID: String,
        targetDescription: String,
        source: VocalEvaluationSource,
        candidates: [VocalBlindCandidate],
        deterministicSeed: UInt64,
        levelMatchingRequired: Bool,
        maximumLevelMismatchDB: Double
    ) -> String {
        let candidateText = candidates.map {
            [$0.blindCode, $0.renderedAudioSHA256, $0.sourceAudioSHA256].joined(separator: "|")
        }.joined(separator: ";")
        let text = [
            studyID,
            targetDescription,
            source.sourceID,
            source.captureID,
            source.sourceAudioSHA256,
            String(deterministicSeed),
            String(levelMatchingRequired),
            canonicalDouble(maximumLevelMismatchDB),
            candidateText
        ].joined(separator: "\u{1f}")
        return "fnv1a64:" + VocalStableFNV1a.hex(text)
    }

    public static func responseChecksum(
        studyID: String,
        packageFingerprint: String,
        conditions: VocalListeningConditions,
        judgments: [VocalCandidateJudgment],
        preference: VocalPreference,
        confidence: Int
    ) -> String {
        let scoreText = judgments.map { judgment in
            [
                judgment.blindCode,
                String(judgment.scores.targetRelevance),
                String(judgment.scores.sourcePreservation),
                String(judgment.scores.naturalness),
                String(judgment.scores.intelligibility),
                String(judgment.scores.temporalCoherence),
                String(judgment.scores.usefulness),
                judgment.note ?? "-"
            ].joined(separator: "|")
        }.joined(separator: ";")
        let text = [
            studyID,
            packageFingerprint,
            conditions.transducer.rawValue,
            conditions.environment.rawValue,
            conditions.outputDeviceDescription,
            String(conditions.levelMatched),
            canonicalDouble(conditions.measuredMaximumLevelMismatchDB),
            String(conditions.listeningMinutes),
            String(conditions.fatigueBefore),
            String(conditions.fatigueAfter),
            scoreText,
            preference.kind.rawValue,
            preference.blindCode ?? "-",
            String(confidence)
        ].joined(separator: "\u{1f}")
        return "fnv1a64:" + VocalStableFNV1a.hex(text)
    }

    public static func answerKeyChecksum(
        packageFingerprint: String,
        mappings: [VocalBlindIdentityMapping]
    ) -> String {
        let mappingText = mappings.map {
            [
                $0.blindCode,
                $0.candidateID,
                $0.candidateSHA256,
                $0.processingPlanID,
                $0.processingPlanSHA256,
                $0.previewID,
                $0.assetID ?? "-",
                $0.assetManifestSHA256 ?? "-",
                $0.renderedAudioSHA256,
            ]
                .joined(separator: "|")
        }.joined(separator: ";")
        return "fnv1a64:" + VocalStableFNV1a.hex(
            [packageFingerprint, mappingText].joined(separator: "\u{1f}")
        )
    }

    private static func validate(source: VocalEvaluationSource) throws {
        try requireIdentifier(source.sourceID, field: "sourceID")
        try requireIdentifier(source.captureID, field: "captureID")
        try requireSHA256(source.sourceAudioSHA256, field: "sourceAudioSHA256")
    }

    private static func validate(
        conditions: VocalListeningConditions,
        for package: VocalBlindedStudyPackage
    ) throws {
        try requireBoundedText(
            conditions.outputDeviceDescription,
            field: "outputDeviceDescription",
            maximumBytes: 256
        )
        guard conditions.levelMatched == package.levelMatchingRequired,
              conditions.measuredMaximumLevelMismatchDB.isFinite,
              conditions.measuredMaximumLevelMismatchDB >= 0,
              conditions.measuredMaximumLevelMismatchDB <= package.maximumLevelMismatchDB,
              (0...240).contains(conditions.listeningMinutes),
              (1...5).contains(conditions.fatigueBefore),
              (1...5).contains(conditions.fatigueAfter) else {
            throw VocalEvaluationError.invalid("Listening conditions or fatigue are outside bounded limits.")
        }
    }

    private static func validate(scores: VocalCandidateScores) throws {
        let values = [
            scores.targetRelevance,
            scores.sourcePreservation,
            scores.naturalness,
            scores.intelligibility,
            scores.temporalCoherence,
            scores.usefulness
        ]
        guard values.allSatisfy({ (1...7).contains($0) }) else {
            throw VocalEvaluationError.invalid("Candidate scores must use the 1...7 scale.")
        }
    }

    private static func requireIdentifier(_ value: String, field: String) throws {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value == trimmed,
              !value.isEmpty,
              value.utf8.count <= 128,
              value.unicodeScalars.allSatisfy({ $0.value >= 0x21 && $0.value <= 0x7e }) else {
            throw VocalEvaluationError.invalid("\(field) is empty, oversized, or contains unsafe characters.")
        }
    }

    private static func requireBoundedText(
        _ value: String,
        field: String,
        maximumBytes: Int,
        allowEmpty: Bool = false
    ) throws {
        guard value.utf8.count <= maximumBytes,
              allowEmpty || !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw VocalEvaluationError.invalid("\(field) is empty or oversized.")
        }
    }

    private static func requireSHA256(_ value: String, field: String) throws {
        guard value.utf8.count == 64,
              value.unicodeScalars.allSatisfy({ scalar in
                  (0x30...0x39).contains(scalar.value) || (0x61...0x66).contains(scalar.value)
              }) else {
            throw VocalEvaluationError.invalid("\(field) must be a lowercase SHA-256 digest.")
        }
    }

    private static func canonicalDouble(_ value: Double) -> String {
        String(format: "%.9f", locale: Locale(identifier: "en_US_POSIX"), value)
    }
}

public struct VocalEvaluationExporter: Sendable {
    public init() {}

    public func encodeParticipantPackage(_ package: VocalBlindedStudyPackage) throws -> Data {
        try VocalEvaluationValidator.validate(package: package)
        return try encodeBounded(package)
    }

    public func encodePrivateAnswerKey(
        _ answerKey: VocalPrivateAnswerKey,
        for package: VocalBlindedStudyPackage
    ) throws -> Data {
        try VocalEvaluationValidator.validate(answerKey: answerKey, for: package)
        return try encodeBounded(answerKey)
    }

    public func encodeResponse(
        _ response: VocalFormativeResponse,
        for package: VocalBlindedStudyPackage
    ) throws -> Data {
        try VocalEvaluationValidator.validate(response: response, for: package)
        return try encodeBounded(response)
    }

    public func decodeResponse(
        _ data: Data,
        for package: VocalBlindedStudyPackage
    ) throws -> VocalFormativeResponse {
        guard data.count <= VocalEvaluationValidator.maximumExportBytes else {
            throw VocalEvaluationError.invalid("The response export exceeds its fixed size bound.")
        }
        let response: VocalFormativeResponse
        do {
            response = try JSONDecoder().decode(VocalFormativeResponse.self, from: data)
        } catch {
            throw VocalEvaluationError.invalid("The response export could not be decoded.")
        }
        try VocalEvaluationValidator.validate(response: response, for: package)
        return response
    }

    private func encodeBounded<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(value)
        guard data.count <= VocalEvaluationValidator.maximumExportBytes else {
            throw VocalEvaluationError.invalid("The evaluation export exceeds its fixed size bound.")
        }
        return data
    }
}

public enum VocalEvaluationDeterministicFixtures {
    public static func plan() -> VocalBlindedStudyPlan {
        let sourceHash = String(repeating: "a", count: 64)
        return VocalBlindedStudyPlan(
            studyID: "vocal-v1-fixture-study",
            targetDescription: "Choose the most useful vocal treatment while preserving the performance.",
            source: VocalEvaluationSource(
                sourceID: "fixture-source",
                captureID: "fixture-capture",
                sourceAudioSHA256: sourceHash
            ),
            candidates: [
                VocalEvaluationCandidate(
                    candidateID: "candidate-conservative",
                    candidateSHA256: String(repeating: "b", count: 64),
                    processingPlanID: "plan-conservative",
                    processingPlanSHA256: String(repeating: "2", count: 64),
                    previewID: "preview-conservative",
                    renderedAudioSHA256: String(repeating: "c", count: 64),
                    sourceAudioSHA256: sourceHash
                ),
                VocalEvaluationCandidate(
                    candidateID: "candidate-balanced",
                    candidateSHA256: String(repeating: "d", count: 64),
                    processingPlanID: "plan-balanced",
                    processingPlanSHA256: String(repeating: "3", count: 64),
                    previewID: "preview-balanced",
                    renderedAudioSHA256: String(repeating: "e", count: 64),
                    sourceAudioSHA256: sourceHash
                ),
                VocalEvaluationCandidate(
                    candidateID: "candidate-bold",
                    candidateSHA256: String(repeating: "f", count: 64),
                    processingPlanID: "plan-bold",
                    processingPlanSHA256: String(repeating: "4", count: 64),
                    previewID: "preview-bold",
                    assetID: "asset-bold",
                    assetManifestSHA256: String(repeating: "5", count: 64),
                    renderedAudioSHA256: String(repeating: "1", count: 64),
                    sourceAudioSHA256: sourceHash
                )
            ],
            deterministicSeed: 0x564F_4341_4C56_3101
        )
    }

    public static func selfCheck() throws -> Bool {
        let runner = VocalBlindedEvaluationRunner()
        let plan = plan()
        let first = try runner.prepare(plan)
        let second = try runner.prepare(plan)
        guard first == second else { return false }
        try runner.validateDeterministicReplay(plan: plan, prepared: first)
        let scores = VocalCandidateScores(
            targetRelevance: 5,
            sourcePreservation: 6,
            naturalness: 5,
            intelligibility: 6,
            temporalCoherence: 6,
            usefulness: 5
        )
        let judgments = first.participantPackage.candidates.map {
            VocalCandidateJudgment(blindCode: $0.blindCode, scores: scores)
        }
        let conditions = VocalListeningConditions(
            transducer: .headphones,
            environment: .quietUntreated,
            outputDeviceDescription: "deterministic-fixture-device",
            levelMatched: true,
            measuredMaximumLevelMismatchDB: 0.1,
            listeningMinutes: 8,
            fatigueBefore: 1,
            fatigueAfter: 2
        )
        let response = try runner.finalizeResponse(
            for: first.participantPackage,
            conditions: conditions,
            judgments: judgments,
            preference: .noPreference,
            confidence: 4
        )
        let exporter = VocalEvaluationExporter()
        let participantData = try exporter.encodeParticipantPackage(first.participantPackage)
        let participantText = String(decoding: participantData, as: UTF8.self)
        guard !plan.candidates.contains(where: { participantText.contains($0.candidateID) }) else {
            return false
        }
        let encoded = try exporter.encodeResponse(response, for: first.participantPackage)
        let decoded = try exporter.decodeResponse(encoded, for: first.participantPackage)
        guard decoded == response else { return false }
        let evidence = try runner.unblind(
            response: decoded,
            participantPackage: first.participantPackage,
            privateAnswerKey: first.privateAnswerKey
        )
        let candidatesByID = Dictionary(uniqueKeysWithValues: plan.candidates.map { ($0.candidateID, $0) })
        guard evidence.results.count == plan.candidates.count
            && evidence.evidenceClass == .singleListenerFormativeEvidence
            && evidence.preferredCandidateID == nil
            && evidence.results.allSatisfy({ result in
                guard let candidate = candidatesByID[result.candidateID] else { return false }
                return result.candidateSHA256 == candidate.candidateSHA256
                    && result.processingPlanID == candidate.processingPlanID
                    && result.processingPlanSHA256 == candidate.processingPlanSHA256
                    && result.previewID == candidate.previewID
                    && result.assetID == candidate.assetID
                    && result.assetManifestSHA256 == candidate.assetManifestSHA256
                    && result.renderedAudioSHA256 == candidate.renderedAudioSHA256
            }) else {
            return false
        }

        var tamperedKey = first.privateAnswerKey
        tamperedKey.mappings[0].candidateID = "tampered-candidate"
        do {
            try VocalEvaluationValidator.validate(
                answerKey: tamperedKey,
                for: first.participantPackage
            )
            return false
        } catch is VocalEvaluationError {
            return true
        }
    }
}

private struct VocalFixedLCG {
    private var state: UInt64

    init(state: UInt64) {
        self.state = state == 0 ? 0x9E37_79B9_7F4A_7C15 : state
    }

    mutating func next() -> UInt64 {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return state
    }
}

enum VocalStableFNV1a {
    static func value(_ string: String) -> UInt64 {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return hash
    }

    static func hex(_ string: String) -> String {
        String(format: "%016llx", value(string))
    }
}

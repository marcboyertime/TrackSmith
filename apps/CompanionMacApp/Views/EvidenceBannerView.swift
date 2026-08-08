import SwiftUI

struct EvidenceBannerView: View {
    @ObservedObject var session: CompanionSessionModel
    @ObservedObject var tutor: TutorSessionModel

    var body: some View {
        GroupBox {
            HStack(spacing: Theme.Spacing.legacy10) {
                Image(systemName: evidenceSymbol)
                    .foregroundStyle(evidenceColor)
                VStack(alignment: .leading, spacing: Theme.Spacing.legacy2) {
                    Text(evidenceTitle).font(Theme.Font.section)
                    Text(evidenceDetail).font(Theme.Font.meta).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(Theme.Spacing.legacy6)
        }
    }

    private var evidenceSymbol: String {
        if let lesson = tutor.lesson, lesson.evidenceMode == .audioGrounded {
            return lesson.audioEvidenceIsHistorical ? "clock.arrow.circlepath" : "waveform.badge.magnifyingglass"
        }
        return session.captureArtifact != nil ? "waveform.badge.magnifyingglass" : "waveform.slash"
    }

    private var evidenceColor: Color {
        if let lesson = tutor.lesson, lesson.evidenceMode == .audioGrounded {
            return lesson.audioEvidenceIsHistorical
                ? Theme.Colors.evidenceAudioHistorical
                : Theme.Colors.evidenceAudioCurrent
        }
        return session.captureArtifact != nil
            ? Theme.Colors.evidenceAvailable
            : Theme.Colors.evidenceUnavailable
    }

    private var evidenceTitle: String {
        if let lesson = tutor.lesson {
            switch (lesson.evidenceMode, lesson.audioEvidenceIsHistorical) {
            case (.audioGrounded, false): return "Grounded in your current capture"
            case (.audioGrounded, true): return "Capture evidence is historical"
            case (.userReportedOnly, _): return "General guidance — no audio evidence"
            }
        }
        return session.captureArtifact != nil
            ? "Current audio evidence is available"
            : "No recent capture"
    }

    private var evidenceDetail: String {
        if let lesson = tutor.lesson {
            switch (lesson.evidenceMode, lesson.audioEvidenceIsHistorical) {
            case (.audioGrounded, false):
                return "Local measurements from your recent capture inform the hypotheses. They are descriptive and cannot prove a cause."
            case (.audioGrounded, true):
                return "The Audio Unit or capture changed since this lesson started. Its measured statements describe the earlier capture, not the live session."
            case (.userReportedOnly, _):
                return "This advice is based only on your description. Analyze recent playback for audio-grounded hypotheses."
            }
        }
        return session.captureArtifact != nil
            ? "Starting a lesson will use the analyzed recent capture as supporting evidence."
            : "Insert TrackSmith on the vocal track, play the section, and use Analyze Recent Playback above for grounded guidance. You can still start a general lesson now."
    }
}

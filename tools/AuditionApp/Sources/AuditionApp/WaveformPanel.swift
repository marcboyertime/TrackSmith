import SwiftUI

struct WaveformPanel: View {
    let bins: [WaveformBin]
    let progress: Double
    let duration: Double

    var body: some View {
        VStack(spacing: 6) {
            Canvas { context, size in
                let middle = size.height / 2
                var waveform = Path()
                guard !bins.isEmpty else { return }
                for (index, bin) in bins.enumerated() {
                    let x = size.width * Double(index) / Double(max(bins.count - 1, 1))
                    let top = middle - CGFloat(bin.maximum) * middle * 0.92
                    let bottom = middle - CGFloat(bin.minimum) * middle * 0.92
                    waveform.move(to: CGPoint(x: x, y: top))
                    waveform.addLine(to: CGPoint(x: x, y: bottom))
                }
                context.stroke(waveform, with: .color(.accentColor.opacity(0.8)), lineWidth: 1)
                let playheadX = size.width * min(max(progress, 0), 1)
                var playhead = Path()
                playhead.move(to: CGPoint(x: playheadX, y: 0))
                playhead.addLine(to: CGPoint(x: playheadX, y: size.height))
                context.stroke(playhead, with: .color(.white.opacity(0.9)), lineWidth: 1.5)
            }
            .frame(height: 170)
            .background(Color.black.opacity(0.78), in: RoundedRectangle(cornerRadius: 10))
            HStack {
                Text(time(progress * duration))
                Spacer()
                Text(time(duration))
            }.font(.caption.monospacedDigit()).foregroundStyle(.secondary)
        }
    }

    private func time(_ seconds: Double) -> String {
        let safe = max(0, seconds)
        return String(format: "%d:%05.2f", Int(safe) / 60, safe.truncatingRemainder(dividingBy: 60))
    }
}

import SwiftUI

struct WaveformView: View {
    var samples: [Float]

    var body: some View {
        Canvas { context, size in
            let middle = size.height / 2
            var center = Path()
            center.move(to: CGPoint(x: 0, y: middle))
            center.addLine(to: CGPoint(x: size.width, y: middle))
            context.stroke(center, with: .color(Theme.Colors.hairline), lineWidth: 1)
            guard samples.count > 1 else { return }
            var path = Path()
            for index in samples.indices {
                let x = CGFloat(index) / CGFloat(samples.count - 1) * size.width
                let amplitude = CGFloat(min(max(samples[index], -1), 1))
                let y = middle - amplitude * middle * 0.88
                if index == 0 { path.move(to: CGPoint(x: x, y: y)) }
                else { path.addLine(to: CGPoint(x: x, y: y)) }
            }
            context.stroke(path, with: .color(Theme.Colors.accent), lineWidth: 1.2)
        }
        .background(Theme.Colors.card, in: RoundedRectangle(cornerRadius: Theme.Radius.small))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.small).stroke(Theme.Colors.hairline, lineWidth: 1))
        .overlay {
            if samples.isEmpty {
                Text("Waveform appears after captured playback").foregroundStyle(Theme.Colors.secondaryText)
            }
        }
    }
}

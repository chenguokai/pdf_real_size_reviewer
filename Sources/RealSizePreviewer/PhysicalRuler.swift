import SwiftUI

struct PhysicalRuler: View {
    let pointsPerMillimeter: CGFloat

    private let rulerLengthMM = 100

    var body: some View {
        let rulerWidth = pointsPerMillimeter * CGFloat(rulerLengthMM)

        Canvas { context, size in
            var baseline = Path()
            baseline.move(to: CGPoint(x: 0, y: size.height - 1))
            baseline.addLine(to: CGPoint(x: size.width, y: size.height - 1))
            context.stroke(baseline, with: .color(.primary.opacity(0.8)), lineWidth: 1)

            for millimeter in 0...rulerLengthMM {
                let x = CGFloat(millimeter) * pointsPerMillimeter
                let tickHeight: CGFloat
                if millimeter.isMultiple(of: 10) {
                    tickHeight = 14
                } else if millimeter.isMultiple(of: 5) {
                    tickHeight = 9
                } else {
                    tickHeight = 5
                }

                var tick = Path()
                tick.move(to: CGPoint(x: x, y: size.height - 1))
                tick.addLine(to: CGPoint(x: x, y: size.height - tickHeight))
                context.stroke(tick, with: .color(.primary.opacity(0.8)), lineWidth: 1)

                if millimeter.isMultiple(of: 10), millimeter < rulerLengthMM {
                    let label = Text("\(millimeter / 10)")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundColor(.primary.opacity(0.75))
                    context.draw(label, at: CGPoint(x: x + 4, y: 8), anchor: .leading)
                }
            }
        }
        .frame(width: rulerWidth, height: 28)
        .accessibilityLabel("A physically calibrated ten centimetre ruler")
    }
}

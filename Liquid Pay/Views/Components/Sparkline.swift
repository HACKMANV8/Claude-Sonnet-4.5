import SwiftUI

struct SparklineView: View {
    let values: [Double] // oldest -> newest
    let lineColor: Color
    let lineWidth: CGFloat

    init(values: [Double], lineColor: Color = .accentColor, lineWidth: CGFloat = 2) {
        self.values = values
        self.lineColor = lineColor
        self.lineWidth = lineWidth
    }

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let normalized = normalize(values: values)
            let path = createPath(values: normalized, in: size)

            path
                .stroke(lineColor, style: StrokeStyle(lineWidth: lineWidth, lineJoin: .round))

            if let last = normalized.last {
                let x = pointX(index: normalized.count - 1, count: normalized.count, width: size.width)
                let y = pointY(value: last, height: size.height)
                Circle()
                    .fill(lineColor)
                    .frame(width: 6, height: 6)
                    .position(x: x, y: y)
            }
        }
        .frame(height: 44)
    }

    private func normalize(values: [Double]) -> [Double] {
        guard let min = values.min(), let max = values.max(), max > min else {
            // Flat line if no variance
            return values.map { _ in 0.5 }
        }
        return values.map { ($0 - min) / (max - min) }
    }

    private func createPath(values: [Double], in size: CGSize) -> Path {
        var path = Path()
        guard !values.isEmpty else { return path }

        for (idx, v) in values.enumerated() {
            let x = pointX(index: idx, count: values.count, width: size.width)
            let y = pointY(value: v, height: size.height)
            if idx == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        return path
    }

    private func pointX(index: Int, count: Int, width: CGFloat) -> CGFloat {
        guard count > 1 else { return width / 2 }
        return CGFloat(index) / CGFloat(count - 1) * width
    }

    private func pointY(value: Double, height: CGFloat) -> CGFloat {
        let padding: CGFloat = 4
        let usable = height - padding * 2
        return (1 - CGFloat(value)) * usable + padding
    }
}



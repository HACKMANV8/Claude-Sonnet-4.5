import SwiftUI

struct PCIView: View {
    @StateObject private var vm = UserPCIViewModel()
    
    var body: some View {
        VStack(spacing: 16) {
            gauge
            streakCard
            trendChart
            Spacer()
        }
        .padding()
        .navigationTitle("PCI Score")
        .onAppear { vm.start() }
        .onDisappear { vm.stop() }
    }
    
    private var gauge: some View {
        VStack(spacing: 6) {
            ZStack {
                GaugeBackground()
                    .stroke(Color.gray.opacity(0.2), style: StrokeStyle(lineWidth: 16, lineCap: .round))
                    .frame(height: 160)
                GaugeForeground(progress: progress)
                    .stroke(AngularGradient(gradient: Gradient(colors: [.red, .yellow, .green]), center: .center), style: StrokeStyle(lineWidth: 16, lineCap: .round))
                    .frame(height: 160)
                Text("\(vm.score)")
                    .font(.system(size: 42, weight: .bold))
            }
            Text("Range 300–900 (higher is better)").font(.caption).foregroundColor(.secondary)
        }
    }
    
    private var streakCard: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Current Streak").font(.caption).foregroundColor(.secondary)
                Text("\(vm.streakDays) days").font(.headline)
            }
            Spacer()
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private var trendChart: some View {
        VStack(alignment: .leading) {
            Text("Trend (last 60–120 days)").font(.headline)
            GeometryReader { geo in
                Path { path in
                    let data = vm.trend
                    guard data.count > 1 else { return }
                    let minScore = 300.0
                    let maxScore = 900.0
                    let width = geo.size.width
                    let height = geo.size.height
                    let stepX = width / CGFloat(max(1, data.count - 1))
                    for (i, p) in data.enumerated() {
                        let x = CGFloat(i) * stepX
                        let yRatio = (Double(p.score) - minScore) / (maxScore - minScore)
                        let y = height - CGFloat(yRatio) * height
                        if i == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
                    }
                }
                .stroke(Color.accentColor, lineWidth: 2)
            }
            .frame(height: 140)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
    }
    
    private var progress: Double { max(0, min(1, (Double(vm.score) - 300.0) / 600.0)) }
}

private struct GaugeBackground: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.addArc(center: CGPoint(x: rect.midX, y: rect.maxY), radius: rect.width/2, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        return p
    }
}

private struct GaugeForeground: Shape {
    let progress: Double
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let end = 180.0 * progress
        p.addArc(center: CGPoint(x: rect.midX, y: rect.maxY), radius: rect.width/2, startAngle: .degrees(180), endAngle: .degrees(180 - end), clockwise: true)
        return p
    }
}



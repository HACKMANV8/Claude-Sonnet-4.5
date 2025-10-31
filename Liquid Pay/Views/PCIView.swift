import SwiftUI

struct PCIView: View {
    @StateObject private var vm = UserPCIViewModel()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                gauge
                streakCard
                trendChart
                infoCard
            }
            .padding()
        }
        .navigationTitle("PCI Score")
        .onAppear { vm.start() }
        .onDisappear { vm.stop() }
    }
    
    private var gauge: some View {
        VStack(spacing: 0) {
            // Top row: Title and Score
            HStack(alignment: .center) {
                Text("PCI Score")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                Text("\(vm.score)")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            // Semicircle gauge centered
            ZStack {
                GaugeBackground()
                    .stroke(Color.primary.opacity(0.08), style: StrokeStyle(lineWidth: 20, lineCap: .round))
                    .frame(width: 280, height: 140)
                GaugeForeground(progress: progress)
                    .stroke(AngularGradient(gradient: Gradient(colors: [.red, .orange, .yellow, .green]), center: .center), style: StrokeStyle(lineWidth: 20, lineCap: .round))
                    .frame(width: 280, height: 140)
            }
            .frame(height: 140)
            .padding(.top, 30)
            
            // Bottom: Range text
            Text("Range 300–900 (higher is better)")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 20)
                .padding(.bottom, 20)
        }
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }
    
    private var streakCard: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Current Streak").font(.caption).foregroundColor(.secondary)
                HStack(spacing: 8) {
                    Text("\(vm.streakDays) days").font(.headline)
                    Text(multiplierText)
                        .font(.caption2)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accentColor)
                        .cornerRadius(8)
                }
                Text(nextMilestoneText).font(.caption).foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }
    
    private var trendChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Trend (last 60–120 days)").font(.headline)
            ZStack {
                if vm.trend.count <= 1 {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.secondarySystemBackground))
                        .frame(height: 180)
                        .overlay(Text("Not enough data yet").foregroundColor(.secondary))
                } else {
                    GeometryReader { geo in
                        ZStack {
                            // Grid lines
                            VStack { Spacer(); Rectangle().fill(Color.primary.opacity(0.08)).frame(height: 1) }
                            VStack { Spacer(); Spacer(); Rectangle().fill(Color.primary.opacity(0.08)).frame(height: 1) }
                            // Line + Area
                            let data = vm.trend
                            let minScore = 300.0
                            let maxScore = 900.0
                            let width = geo.size.width
                            let height = geo.size.height
                            let stepX = width / CGFloat(max(1, data.count - 1))
                            Path { path in
                                for (i, p) in data.enumerated() {
                                    let x = CGFloat(i) * stepX
                                    let yRatio = (Double(p.score) - minScore) / (maxScore - minScore)
                                    let y = height - CGFloat(yRatio) * height
                                    if i == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
                                }
                            }
                            .stroke(Color.accentColor, lineWidth: 2)
                            
                            Path { path in
                                for (i, p) in data.enumerated() {
                                    let x = CGFloat(i) * stepX
                                    let yRatio = (Double(p.score) - minScore) / (maxScore - minScore)
                                    let y = height - CGFloat(yRatio) * height
                                    if i == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
                                }
                                path.addLine(to: CGPoint(x: width, y: height))
                                path.addLine(to: CGPoint(x: 0, y: height))
                                path.closeSubpath()
                            }
                            .fill(LinearGradient(colors: [Color.accentColor.opacity(0.25), .clear], startPoint: .top, endPoint: .bottom))
                        }
                    }
                    .frame(height: 180)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(16)
                }
            }
        }
    }

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("What affects PCI?").font(.headline)
            VStack(alignment: .leading, spacing: 6) {
                Text("• On‑time payments boost your score (faster is better)")
                Text("• Long streaks give multipliers at 30d and 60d")
                Text("• Failed or delayed payments drop the score more")
                Text("• Consistency recovers the score towards 700")
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }
    
    private var progress: Double { max(0, min(1, (Double(vm.score) - 300.0) / 600.0)) }
    
    private var deltaToday: String? {
        guard vm.trend.count >= 2 else { return nil }
        let last = vm.trend.last!.score
        let prev = vm.trend.dropLast().last!.score
        let diff = last - prev
        if diff == 0 { return nil }
        return diff > 0 ? "+\(diff) today" : "\(diff) today"
    }
    
    private var category: (title: String, color: Color) {
        switch vm.score {
        case ..<500: return ("Poor", .red)
        case 500..<650: return ("Fair", .orange)
        case 650..<750: return ("Good", .yellow)
        default: return ("Excellent", .green)
        }
    }
    
    private var multiplierText: String {
        if vm.streakDays >= 60 { return "×2 multiplier" }
        if vm.streakDays >= 30 { return "×1.5 multiplier" }
        let left = vm.streakDays < 30 ? 30 - vm.streakDays : 60 - vm.streakDays
        let next = vm.streakDays < 30 ? "30d" : "60d"
        return "\(left)d to \(next) bonus"
    }
    
    private var nextMilestoneText: String {
        if vm.streakDays < 30 { return "Keep going: bonus at 30 days" }
        if vm.streakDays < 60 { return "Great! next bonus at 60 days" }
        return "Max streak bonus active"
    }
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



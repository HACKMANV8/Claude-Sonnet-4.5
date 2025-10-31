import SwiftUI
import FirebaseAuth

struct SpinWheelGameView: View {
    let entryFee: Int
    let winPrize: Int
    let title: String
    var onClose: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var angle: Double = 0
    @State private var spinning: Bool = false
    @State private var charged: Bool = false
    @State private var result: String? = nil
    @State private var winPendingCollect: Bool = false
    @State private var collected: Bool = false
    @State private var confetti: Bool = false
    
    private struct WheelSegment { let coins: Int; let color: Color }
    // Alternate between 50 and 0 coin slices; adjust distribution as desired
    private var segments: [WheelSegment] { [
        WheelSegment(coins: winPrize, color: .green),
        WheelSegment(coins: 0, color: .red),
        WheelSegment(coins: winPrize, color: .green),
        WheelSegment(coins: 0, color: .orange),
        WheelSegment(coins: winPrize, color: .green),
        WheelSegment(coins: 0, color: .red),
        WheelSegment(coins: winPrize, color: .green),
        WheelSegment(coins: 0, color: .orange)
    ] }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Text(title)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                    Text("Entry: \(entryFee) • Win: +\(winPrize)")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.9))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(
                    LinearGradient(colors: [.pink, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .cornerRadius(20)

                // Wheel card
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color(.secondarySystemBackground))
                            .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 6)
                        ZStack {
                            Wheel
                            Triangle().fill(Color.white)
                                .frame(width: 16, height: 16)
                                .offset(y: -145)
                                .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1)
                        }
                    }
                    .frame(width: 300, height: 300)

                    if let r = result {
                        Text(r)
                            .font(.headline)
                            .foregroundColor(.primary)
                    }

                    if winPendingCollect {
                        Button(collected ? "Collected" : "Collect Reward") {
                            guard !collected else { return }
                            confetti = true
                            DispatchQueue.main.asyncAfter(deadline: .now()+1.0) { Task { await awardWin() }; collected = true }
                        }
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(
                            LinearGradient(colors: [.green, .mint], startPoint: .leading, endPoint: .trailing)
                        )
                        .cornerRadius(14)
                        .shadow(color: .green.opacity(0.25), radius: 8, x: 0, y: 4)
                        .disabled(collected)
                        .opacity(collected ? 0.7 : 1)
                    }

                    Button {
                        Task { await spin() }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: spinning ? "timer" : "arrow.2.circlepath")
                            Text(spinning ? "Spinning..." : "Spin Wheel")
                        }
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(
                            LinearGradient(colors: [.purple, .blue], startPoint: .leading, endPoint: .trailing)
                        )
                        .cornerRadius(14)
                        .opacity(spinning ? 0.7 : 1)
                    }
                    .disabled(spinning)
                }
                .padding(16)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(20)

                Button("Close") { dismiss(); onClose() }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Color(.tertiarySystemBackground))
                    .cornerRadius(14)
            }
            .padding(20)
        }
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .top) { GameConfettiView(isActive: $confetti, duration: 1.5, confettiCount: 50) }
    }
    
    private var Wheel: some View {
        ZStack {
            ForEach(0..<segments.count, id: \.self) { i in
                let start = Angle(degrees: (360.0/Double(segments.count))*Double(i))
                let end = Angle(degrees: (360.0/Double(segments.count))*Double(i+1))
                Segment(startAngle: start, endAngle: end)
                    .fill(segments[i].color)
                Text("\(segments[i].coins)")
                    .font(.caption).bold()
                    .foregroundColor(.white)
                    .rotationEffect(Angle(degrees: (start.degrees+end.degrees)/2 + 90))
                    .offset(y: 90)
            }
        }
        .rotationEffect(Angle(degrees: angle))
        .animation(.easeOut(duration: 2.0), value: angle)
        .background(Circle().stroke(Color.white.opacity(0.2), lineWidth: 6))
        .clipShape(Circle())
    }
    
    private func spin() async {
        if !charged { await chargeEntry() }
        spinning = true
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        let spins = Double(Int.random(in: 3...6))*360
        let target = Double.random(in: 0..<360)
        angle += spins + target
        DispatchQueue.main.asyncAfter(deadline: .now()+2.1) {
            spinning = false
            resolveResult()
        }
    }
    
    private func resolveResult() {
        let normalized = (360 - (angle.truncatingRemainder(dividingBy: 360)))
        let segmentAngle = 360.0 / Double(segments.count)
        var index = Int((normalized + segmentAngle/2)/segmentAngle) % segments.count
        if index < 0 { index += segments.count }
        let seg = segments[index]
        if seg.coins > 0 {
            result = "+\(seg.coins) coins! Tap Collect"
            winPendingCollect = true
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } else {
            result = "0 coins - Try again"
            winPendingCollect = false
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        }
    }
    
    private func chargeEntry() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        do { try await RewardsService.shared.chargeGameEntry(uid: uid, fee: entryFee, game: title); charged = true } catch { }
    }
    private func awardWin() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        do { try await RewardsService.shared.awardGameWin(uid: uid, prize: winPrize, game: title) } catch { }
    }
}

private struct Segment: Shape {
    let startAngle: Angle
    let endAngle: Angle
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        p.move(to: center)
        p.addArc(center: center, radius: rect.width/2, startAngle: startAngle - .degrees(90), endAngle: endAngle - .degrees(90), clockwise: false)
        p.closeSubpath()
        return p
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}



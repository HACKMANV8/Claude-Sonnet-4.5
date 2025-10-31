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
    @State private var coinRain: Bool = false
    
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
        VStack(spacing: 16) {
            Text(title).font(.title2).bold()
            Text("Entry: \(entryFee) • Win: +\(winPrize)").font(.caption).foregroundColor(.secondary)
            ZStack {
                Wheel
                Triangle().fill(Color.white).frame(width: 14, height: 14).offset(y: -140)
            }
            .frame(width: 280, height: 280)
            
            if let r = result { Text(r).font(.headline) }
            if winPendingCollect {
                Button(collected ? "Collected" : "Collect") {
                    guard !collected else { return }
                    coinRain = true
                    DispatchQueue.main.asyncAfter(deadline: .now()+1.0) { Task { await awardWin() }; collected = true }
                }
                .buttonStyle(.borderedProminent)
                .disabled(collected)
            }
            
            HStack {
                Button("Spin") { Task { await spin() } }
                    .disabled(spinning)
                Button("Close") { dismiss(); onClose() }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .top) { CoinRainView(isActive: $coinRain, duration: 1.2, coinCount: 26) }
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



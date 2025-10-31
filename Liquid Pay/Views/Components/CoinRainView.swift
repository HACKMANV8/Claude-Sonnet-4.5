import SwiftUI

struct CoinRainView: View {
    @Binding var isActive: Bool
    let duration: Double
    let coinCount: Int
    
    @State private var animTriggers: [Bool] = []
    
    var body: some View {
        ZStack {
            ForEach(0..<coinCount, id: \.self) { i in
                let startX = CGFloat.random(in: 0.05...0.95)
                let size = CGFloat.random(in: 12...24)
                let delay = Double.random(in: 0...0.6)
                CoinShape()
                    .fill(LinearGradient(colors: [.yellow, .orange], startPoint: .top, endPoint: .bottom))
                    .frame(width: size, height: size)
                    .position(x: UIScreen.main.bounds.width * startX, y: animTriggers.indices.contains(i) && animTriggers[i] ? UIScreen.main.bounds.height + 40 : -40)
                    .rotationEffect(.degrees(animTriggers.indices.contains(i) && animTriggers[i] ? 360 : 0))
                    .opacity(animTriggers.indices.contains(i) && animTriggers[i] ? 0.9 : 0)
                    .animation(Animation.easeIn(duration: duration - delay).delay(delay), value: animTriggers.indices.contains(i) ? animTriggers[i] : false)
            }
        }
        .allowsHitTesting(false)
        .onChange(of: isActive) { _, newVal in
            guard newVal else { return }
            animTriggers = Array(repeating: false, count: coinCount)
            // trigger staggered animations
            DispatchQueue.main.async {
                for i in 0..<coinCount {
                    DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.01) {
                        withAnimation { if animTriggers.indices.contains(i) { animTriggers[i] = true } }
                    }
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.7) {
                isActive = false
            }
        }
    }
}

private struct CoinShape: Shape {
    func path(in rect: CGRect) -> Path {
        return Path(ellipseIn: rect)
    }
}



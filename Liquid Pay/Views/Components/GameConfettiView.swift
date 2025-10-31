import SwiftUI

struct GameConfettiView: View {
    @Binding var isActive: Bool
    let duration: Double
    let confettiCount: Int
    
    @State private var animTriggers: [Bool] = []
    
    private let colors: [Color] = [
        .red, .blue, .green, .yellow, .orange, .purple, .pink, .cyan
    ]
    
    var body: some View {
        ZStack {
            ForEach(0..<confettiCount, id: \.self) { i in
                let startX = CGFloat.random(in: 0.05...0.95)
                let size = CGFloat.random(in: 8...16)
                let delay = Double.random(in: 0...0.4)
                let color = colors.randomElement() ?? .blue
                let rotation = Double.random(in: -360...360)
                let rotationSpeed = Double.random(in: 2...6)
                
                // Confetti piece (rectangle)
                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(width: size, height: size * 0.6)
                    .position(
                        x: UIScreen.main.bounds.width * startX,
                        y: animTriggers.indices.contains(i) && animTriggers[i] ? UIScreen.main.bounds.height + 50 : -50
                    )
                    .rotationEffect(.degrees(animTriggers.indices.contains(i) && animTriggers[i] ? rotation + rotationSpeed * 360 : rotation))
                    .opacity(animTriggers.indices.contains(i) && animTriggers[i] ? 1.0 : 0)
                    .animation(
                        Animation.easeIn(duration: duration - delay)
                            .delay(delay),
                        value: animTriggers.indices.contains(i) ? animTriggers[i] : false
                    )
            }
        }
        .allowsHitTesting(false)
        .onChange(of: isActive) { _, newVal in
            guard newVal else { return }
            animTriggers = Array(repeating: false, count: confettiCount)
            // Trigger staggered animations
            DispatchQueue.main.async {
                for i in 0..<confettiCount {
                    DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.008) {
                        withAnimation {
                            if animTriggers.indices.contains(i) {
                                animTriggers[i] = true
                            }
                        }
                    }
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.5) {
                isActive = false
            }
        }
    }
}


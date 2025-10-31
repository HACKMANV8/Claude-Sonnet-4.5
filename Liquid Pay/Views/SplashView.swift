import SwiftUI

struct SplashView: View {
    private let fullText = "LiquidPay"
    @State private var displayedText: String = ""
    @State private var typingTask: Task<Void, Never>?
    @State private var bufferPulse: Bool = false

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            Text(displayedText)
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
                .scaleEffect(bufferPulse ? 1.04 : 1.0)
                .opacity(bufferPulse ? 1.0 : 0.94)
                .animation(.easeInOut(duration: 0.55), value: bufferPulse)
        }
        .onAppear { startTyping() }
        .onDisappear { stopTyping() }
    }

    private func startTyping() {
        stopTyping()
        typingTask = Task { @MainActor in
            displayedText = ""
            bufferPulse = false
            for character in fullText {
                guard !Task.isCancelled else { return }
                displayedText.append(character)
                try? await Task.sleep(nanoseconds: 80_000_000) // 0.08s per character
            }

            guard !Task.isCancelled else { return }

            withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                bufferPulse = true
            }

            try? await Task.sleep(nanoseconds: 650_000_000) // ~0.65s buffer animation

            guard !Task.isCancelled else { return }

            withAnimation(.easeOut(duration: 0.35)) {
                bufferPulse = false
            }
        }
    }

    private func stopTyping() {
        typingTask?.cancel()
        typingTask = nil
    }
}



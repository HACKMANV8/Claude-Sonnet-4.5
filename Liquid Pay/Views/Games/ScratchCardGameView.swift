import SwiftUI
import FirebaseAuth

struct ScratchCardGameView: View {
    let entryFee: Int
    let winPrize: Int
    let title: String
    var onClose: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var revealed: Bool = false
    @State private var win: Bool = Bool.random()
    @State private var charged: Bool = false
    @State private var coinRain: Bool = false
    @State private var collected: Bool = false
    
    var body: some View {
        VStack(spacing: 16) {
            Text(title).font(.title2).bold()
            Text("Entry: \(entryFee) • Win: +\(winPrize)").font(.caption).foregroundColor(.secondary)
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(win ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                    .overlay(Text(win ? "+\(winPrize)" : "Try again").font(.system(size: 44, weight: .bold)).foregroundColor(win ? .green : .red))
                if !revealed {
                    ScratchOverlay(revealed: $revealed)
                        .onAppear { Task { await chargeEntryIfNeeded() } }
                }
            }
            .frame(height: 220)
            .padding()
            
            if revealed {
                if win {
                    Text(collected ? "Collected" : "You win +\(winPrize) coins").font(.headline)
                    Button(collected ? "Collected" : "Collect") {
                        guard !collected else { return }
                        coinRain = true
                        DispatchQueue.main.asyncAfter(deadline: .now()+1.0) {
                            Task { await awardWin() }
                            collected = true
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(collected)
                } else { Text("Better luck next time").font(.headline) }
            } else {
                Text("Scratch to reveal").foregroundColor(.secondary)
            }
            Button("Close") { dismiss(); onClose() }.buttonStyle(.bordered)
        }
        .padding()
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .top) { CoinRainView(isActive: $coinRain, duration: 1.2, coinCount: 26) }
    }
    
    private func chargeEntryIfNeeded() async {
        guard !charged, let uid = Auth.auth().currentUser?.uid else { return }
        do { try await RewardsService.shared.chargeGameEntry(uid: uid, fee: entryFee, game: title); charged = true } catch { }
    }
    private func awardWin() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        do { try await RewardsService.shared.awardGameWin(uid: uid, prize: winPrize, game: title) } catch { }
    }
}

private struct ScratchOverlay: View {
    @Binding var revealed: Bool
    @State private var maskPath = Path()
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16).fill(Color.gray)
                .overlay(Text("SCRATCH").font(.headline).foregroundColor(.white))
                .mask(
                    ZStack {
                        RoundedRectangle(cornerRadius: 16).fill(Color.white)
                        maskPath.stroke(lineWidth: 40).blendMode(.destinationOut)
                    }
                )
        }
        .gesture(DragGesture(minimumDistance: 0).onChanged { value in
            let pt = value.location
            if maskPath.isEmpty { maskPath.move(to: pt) } else { maskPath.addLine(to: pt) }
        }.onEnded { _ in
            revealed = true
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        })
        .compositingGroup()
    }
}



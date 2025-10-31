import SwiftUI
import FirebaseAuth

struct TicTacToeGameView: View {
    let entryFee: Int
    let winPrize: Int
    let title: String
    var onClose: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var board: [String] = Array(repeating: "", count: 9) // "X" / "O" / ""
    @State private var isUserTurn: Bool = true
    @State private var charged: Bool = false
    @State private var resultText: String? = nil
    @State private var winPendingCollect: Bool = false
    @State private var collected: Bool = false
    @State private var confetti: Bool = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Text(title)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                    Text("You vs Computer • Entry: \(entryFee) • Win: +\(winPrize)")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.9))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(
                    LinearGradient(colors: [.teal, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .cornerRadius(20)

                // Board card
                VStack(spacing: 16) {
                    GridView
                        .padding(8)

                    if let r = resultText {
                        Text(r)
                            .font(.headline)
                            .foregroundColor(r.contains("win") ? .green : (r == "Draw" ? .secondary : .orange))
                    } else {
                        Text(isUserTurn ? "Your turn" : "Computer thinking...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
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

                    Button("Close") { dismiss(); onClose() }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color(.tertiarySystemBackground))
                        .cornerRadius(14)
                }
                .padding(16)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(20)
            }
            .padding(20)
        }
        .navigationBarTitleDisplayMode(.inline)
        .task { await chargeEntryIfNeeded() }
        .overlay(alignment: .top) {
            if confetti { ConfettiView().allowsHitTesting(false) }
        }
    }
    
    private var GridView: some View {
        VStack(spacing: 10) {
            ForEach(0..<3) { row in
                HStack(spacing: 10) {
                    ForEach(0..<3) { col in
                        let idx = row*3+col
                        Button {
                            tapCell(idx)
                        } label: {
                            ZStack {
                                // Translucent square with subtle border so targets are obvious
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.primary.opacity(0.06))
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color.primary.opacity(0.15), lineWidth: 1)
                                    .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 2)
                                Text(board[idx])
                                    .font(.system(size: 42, weight: .bold))
                            }
                        }
                        .frame(width: 100, height: 100)
                        .disabled(board[idx] != "" || resultText != nil || !isUserTurn)
                    }
                }
            }
        }
    }
    
    private func tapCell(_ i: Int) {
        guard board[i] == "" && isUserTurn && resultText == nil else { return }
        board[i] = "X"
        isUserTurn = false
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        checkGame()
        if resultText == nil { DispatchQueue.main.asyncAfter(deadline: .now()+0.3) { aiMove() } }
    }
    
    private func aiMove() {
        // Simple AI: win if possible, block if needed, else random
        let lines = winningLines
        // Try winning
        for line in lines { if canComplete(line, symbol: "O") { place(in: line, symbol: "O"); finalizeAfterAIMove(); return } }
        // Try blocking
        for line in lines { if canComplete(line, symbol: "X") { place(in: line, symbol: "O"); finalizeAfterAIMove(); return } }
        // Else random
        let empty = board.enumerated().filter{ $0.element == "" }.map{ $0.offset }
        if let idx = empty.randomElement() { board[idx] = "O" }
        finalizeAfterAIMove()
    }
    
    private func finalizeAfterAIMove() {
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        checkGame()
        if resultText == nil { isUserTurn = true }
    }
    
    private func checkGame() {
        if let w = winner() {
            if w == "X" { resultText = "You win +\(winPrize)! Tap Collect"; winPendingCollect = true; UINotificationFeedbackGenerator().notificationOccurred(.success) }
            else { resultText = "Computer wins"; UINotificationFeedbackGenerator().notificationOccurred(.warning) }
        } else if !board.contains("") {
            resultText = "Draw"
        }
    }
    
    private func winner() -> String? {
        for line in winningLines {
            let a = board[line[0]], b = board[line[1]], c = board[line[2]]
            if a != "" && a == b && b == c { return a }
        }
        return nil
    }
    
    private var winningLines: [[Int]] { [[0,1,2],[3,4,5],[6,7,8],[0,3,6],[1,4,7],[2,5,8],[0,4,8],[2,4,6]] }
    private func canComplete(_ line: [Int], symbol: String) -> Bool {
        let vals = line.map { board[$0] }
        return vals.filter{ $0 == symbol }.count == 2 && vals.contains("")
    }
    private func place(in line: [Int], symbol: String) {
        for i in line where board[i] == "" { board[i] = symbol; break }
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



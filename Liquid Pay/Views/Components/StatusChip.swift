import SwiftUI

struct StatusChip: View {
    let text: String

    private var colors: (bg: Color, fg: Color) {
        switch text.lowercased() {
        case "success", "paid":
            return (.green.opacity(0.15), .green)
        case "failed":
            return (.red.opacity(0.15), .red)
        default: // pending, authorized, etc.
            return (.orange.opacity(0.15), .orange)
        }
    }

    var body: some View {
        Text(text.capitalized)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(colors.bg)
            .foregroundColor(colors.fg)
            .cornerRadius(6)
    }
}



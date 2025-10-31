import SwiftUI

struct RewardsView: View {
    @StateObject private var vm = RewardsViewModel()

    var body: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Your Points").font(.caption).foregroundColor(.secondary)
                Text("\(vm.points)").font(.system(size: 44, weight: .bold))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.yellow.opacity(0.15))
            .cornerRadius(12)

            Text("Earn points for every successful payment. Redeem soon.")
                .foregroundColor(.secondary)

            Spacer()
        }
        .padding()
        .navigationTitle("Rewards")
        .onAppear { vm.startListening() }
    }
}



import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore

@MainActor
final class RewardsViewModel: ObservableObject {
    @Published var coinBalance: Int = 0
    @Published var recentEntries: [CoinEntry] = []
    @Published var errorMessage: String?
    @Published var canLoadMore: Bool = true

    private var listeners: (ListenerRegistration, ListenerRegistration)?
    private var lastLedgerDoc: DocumentSnapshot?

    deinit {
        listeners?.0.remove(); listeners?.1.remove(); listeners = nil
    }

    func startListening() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        listeners?.0.remove(); listeners?.1.remove(); listeners = nil
        listeners = RewardsService.shared.listenToBalanceAndEntries(uid: uid) { [weak self] balance, entries in
            self?.coinBalance = balance
            self?.recentEntries = entries
            self?.canLoadMore = entries.count >= 20
            self?.lastLedgerDoc = nil // will reset; pagination uses explicit fetch
        }
    }
    
    func redeem(amount: Int, note: String? = nil) async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        do {
            try await RewardsService.shared.redeemCoins(uid: uid, amount: amount, note: note)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadMore() async {
        guard let uid = Auth.auth().currentUser?.uid, canLoadMore else { return }
        do {
            let (more, last) = try await RewardsService.shared.fetchMoreLedger(uid: uid, after: lastLedgerDoc)
            if more.isEmpty { canLoadMore = false; return }
            recentEntries.append(contentsOf: more)
            lastLedgerDoc = last
            canLoadMore = more.count >= 20
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}


import Foundation
import FirebaseFirestore
import FirebaseAuth

final class RewardsService {
    static let shared = RewardsService()
    private let db = Firestore.firestore()

    func listenToBalanceAndEntries(uid: String, onUpdate: @escaping (_ balance: Int, _ entries: [CoinEntry]) -> Void) -> (ListenerRegistration, ListenerRegistration) {
        let userRef = db.collection("users").document(uid)
        let ledgerRef = userRef.collection("coin_ledger").order(by: "createdAt", descending: true).limit(to: 20)

        let balanceListener = userRef.addSnapshotListener { snap, _ in
            _ = (snap?.data()?["coinBalance"] as? Int) // intentionally unused; combined update happens below
            // We don't call onUpdate here; the combined update happens in ledger listener.
            // Consumers may also call this directly if needed.
        }

        let ledgerListener = ledgerRef.addSnapshotListener { [weak self] snap, _ in
            guard self != nil else { return }
            let entries: [CoinEntry] = snap?.documents.compactMap { doc in
                let data = doc.data()
                let ts = data["createdAt"] as? Timestamp
                return CoinEntry(
                    id: doc.documentID,
                    type: data["type"] as? String ?? "earn",
                    amount: data["amount"] as? Int ?? 0,
                    note: data["note"] as? String,
                    createdAt: ts?.dateValue()
                )
            } ?? []

            userRef.getDocument { userSnap, _ in
                let balance = (userSnap?.data()?["coinBalance"] as? Int) ?? 0
                onUpdate(balance, entries)
            }
        }

        return (balanceListener, ledgerListener)
    }

    func fetchMoreLedger(uid: String, after last: DocumentSnapshot?, pageSize: Int = 20) async throws -> ([CoinEntry], DocumentSnapshot?) {
        var query: Query = db.collection("users").document(uid).collection("coin_ledger").order(by: "createdAt", descending: true).limit(to: pageSize)
        if let last = last { query = query.start(afterDocument: last) }
        let snap = try await query.getDocuments()
        let entries: [CoinEntry] = snap.documents.compactMap { doc in
            let data = doc.data()
            let ts = data["createdAt"] as? Timestamp
            return CoinEntry(
                id: doc.documentID,
                type: data["type"] as? String ?? "earn",
                amount: data["amount"] as? Int ?? 0,
                note: data["note"] as? String,
                createdAt: ts?.dateValue()
            )
        }
        return (entries, snap.documents.last)
    }

    func redeemCoins(uid: String, amount: Int, note: String?) async throws {
        guard amount > 0 else { return }
        _ = try await db.runTransaction { (tx, errorPointer) -> Any? in
            let userRef = self.db.collection("users").document(uid)
            do {
                let userSnap = try tx.getDocument(userRef)
                let current = (userSnap.data()? ["coinBalance"] as? Int) ?? 0
                if current < amount {
                    errorPointer?.pointee = NSError(domain: "Rewards", code: 400, userInfo: [NSLocalizedDescriptionKey: "Insufficient coins"])
                    return nil
                }

                tx.updateData(["coinBalance": current - amount], forDocument: userRef)

                let ledgerRef = userRef.collection("coin_ledger").document("redeem_\(Int(Date().timeIntervalSince1970))")
                tx.setData([
                    "type": "redeem",
                    "amount": -amount,
                    "note": note ?? "",
                    "createdAt": FieldValue.serverTimestamp()
                ], forDocument: ledgerRef)
            } catch {
                errorPointer?.pointee = error as NSError
            }
            return nil
        }
    }

    func awardCoinsForPayment(uid: String, paymentId: String, amountPaise: Int) async throws {
        let base = max(0, amountPaise) // 1 coin per paise (100 coins = ₹1 earning)
        // Weekend 2x (client optimistic; server is source of truth)
        let weekday = Calendar.current.component(.weekday, from: Date()) // 1=Sun ... 7=Sat
        let isWeekend = (weekday == 1 || weekday == 7)
        let coins = base * (isWeekend ? 2 : 1)
        guard coins > 0 else { return }
        _ = try await db.runTransaction { (tx, errorPointer) -> Any? in
            let userRef = self.db.collection("users").document(uid)
            let ledgerRef = userRef.collection("coin_ledger").document("payment_\(paymentId)")
            do {
                let ledgerSnap = try tx.getDocument(ledgerRef)
                if ledgerSnap.exists { return nil } // idempotent

                let userSnap = try tx.getDocument(userRef)
                let current = (userSnap.data()? ["coinBalance"] as? Int) ?? 0
                tx.setData(["coinBalance": current + coins], forDocument: userRef, merge: true)
                tx.setData([
                    "type": "earn",
                    "amount": coins,
                    "note": isWeekend ? "Payment \(paymentId) (Weekend x2)" : "Payment \(paymentId)",
                    "createdAt": FieldValue.serverTimestamp()
                ], forDocument: ledgerRef)
            } catch {
                errorPointer?.pointee = error as NSError
            }
            return nil
        }
    }

    // MARK: - Vouchers
    func listenActiveVouchers(uid: String, onUpdate: @escaping ([Voucher]) -> Void) -> ListenerRegistration {
        let ref = db.collection("users").document(uid).collection("vouchers").whereField("status", isEqualTo: "active").order(by: "createdAt", descending: true)
        return ref.addSnapshotListener { snap, _ in
            let vouchers: [Voucher] = snap?.documents.compactMap { doc in
                let data = doc.data()
                let ts = data["createdAt"] as? Timestamp
                let rs = data["redeemedAt"] as? Timestamp
                return Voucher(
                    id: doc.documentID,
                    code: data["code"] as? String ?? "",
                    valuePaise: data["valuePaise"] as? Int ?? 0,
                    status: data["status"] as? String ?? "active",
                    createdAt: ts?.dateValue(),
                    redeemedAt: rs?.dateValue()
                )
            } ?? []
            onUpdate(vouchers)
        }
    }

    func createVoucher(uid: String, valuePaise: Int) async throws {
        guard valuePaise >= 100 else { throw NSError(domain: "Rewards", code: 400, userInfo: [NSLocalizedDescriptionKey: "Minimum ₹1"])}
        let coinsRequired = valuePaise * 10 // 10 coins per paise (1000 coins = ₹1)
        _ = try await db.runTransaction { (tx, errorPointer) -> Any? in
            let userRef = self.db.collection("users").document(uid)
            do {
                let userSnap = try tx.getDocument(userRef)
                let current = (userSnap.data()? ["coinBalance"] as? Int) ?? 0
                if current < coinsRequired {
                    errorPointer?.pointee = NSError(domain: "Rewards", code: 400, userInfo: [NSLocalizedDescriptionKey: "Insufficient coins"])
                    return nil
                }

                let code = "LP-\(Int.random(in: 100000...999999))"
                let voucherRef = userRef.collection("vouchers").document()
                tx.updateData(["coinBalance": current - coinsRequired], forDocument: userRef)
                tx.setData([
                    "code": code,
                    "valuePaise": valuePaise,
                    "status": "active",
                    "createdAt": FieldValue.serverTimestamp()
                ], forDocument: voucherRef)

                let ledgerRef = userRef.collection("coin_ledger").document("voucher_\(voucherRef.documentID)")
                tx.setData([
                    "type": "redeem",
                    "amount": -coinsRequired,
                    "note": "Voucher \(code) (₹\(valuePaise/100))",
                    "createdAt": FieldValue.serverTimestamp()
                ], forDocument: ledgerRef)
            } catch {
                errorPointer?.pointee = error as NSError
            }
            return nil
        }
    }

    func markVoucherUsed(uid: String, voucherId: String) async throws {
        try await db.collection("users").document(uid).collection("vouchers").document(voucherId)
            .setData(["status": "used", "redeemedAt": FieldValue.serverTimestamp()], merge: true)
    }

    // MARK: - Daily Reward
    func awardDailyRewardIfEligible(uid: String, min: Int = 5, max: Int = 10, cooldownHours: Double = 24) async throws -> (awarded: Int, nextEligibleAt: Date?) {
        var resultAwarded = 0
        var nextAt: Date? = nil
        _ = try await db.runTransaction { (tx, errorPointer) -> Any? in
            let userRef = self.db.collection("users").document(uid)
            do {
                let userSnap = try tx.getDocument(userRef)
                let current = (userSnap.data()? ["coinBalance"] as? Int) ?? 0
                let lastTs = userSnap.get("lastDailyRewardAt") as? Timestamp
                let lastDate = lastTs?.dateValue()
                if let lastDate = lastDate, Date().timeIntervalSince(lastDate) < cooldownHours * 3600 {
                    nextAt = Date(timeInterval: cooldownHours * 3600, since: lastDate)
                    return nil // not eligible
                }
                let award = Int.random(in: min...max)
                resultAwarded = award
                tx.setData(["coinBalance": current + award, "lastDailyRewardAt": FieldValue.serverTimestamp()], forDocument: userRef, merge: true)
                let ledgerRef = userRef.collection("coin_ledger").document("daily_\(Int(Date().timeIntervalSince1970))")
                tx.setData([
                    "type": "daily_reward",
                    "amount": award,
                    "note": "Daily reward",
                    "createdAt": FieldValue.serverTimestamp()
                ], forDocument: ledgerRef)
            } catch {
                errorPointer?.pointee = error as NSError
            }
            return nil
        }
        return (resultAwarded, nextAt)
    }

    // MARK: - Games (entry and win)
    func chargeGameEntry(uid: String, fee: Int, game: String) async throws {
        guard fee > 0 else { return }
        _ = try await db.runTransaction { (tx, errorPointer) -> Any? in
            let userRef = self.db.collection("users").document(uid)
            do {
                let userSnap = try tx.getDocument(userRef)
                let current = (userSnap.data()? ["coinBalance"] as? Int) ?? 0
                if current < fee {
                    errorPointer?.pointee = NSError(domain: "Rewards", code: 402, userInfo: [NSLocalizedDescriptionKey: "Insufficient coins"])
                    return nil
                }
                tx.updateData(["coinBalance": current - fee], forDocument: userRef)
                let ledgerRef = userRef.collection("coin_ledger").document("game_entry_\(Int(Date().timeIntervalSince1970))")
                tx.setData([
                    "type": "game_entry",
                    "amount": -fee,
                    "note": "Entry: \(game)",
                    "createdAt": FieldValue.serverTimestamp()
                ], forDocument: ledgerRef)
            } catch {
                errorPointer?.pointee = error as NSError
            }
            return nil
        }
    }

    func awardGameWin(uid: String, prize: Int, game: String) async throws {
        guard prize > 0 else { return }
        _ = try await db.runTransaction { (tx, errorPointer) -> Any? in
            let userRef = self.db.collection("users").document(uid)
            do {
                let userSnap = try tx.getDocument(userRef)
                let current = (userSnap.data()? ["coinBalance"] as? Int) ?? 0
                tx.updateData(["coinBalance": current + prize], forDocument: userRef)
                let ledgerRef = userRef.collection("coin_ledger").document("game_win_\(Int(Date().timeIntervalSince1970))")
                tx.setData([
                    "type": "game_win",
                    "amount": prize,
                    "note": "Win: \(game)",
                    "createdAt": FieldValue.serverTimestamp()
                ], forDocument: ledgerRef)
            } catch {
                errorPointer?.pointee = error as NSError
            }
            return nil
        }
    }

    // MARK: - Context Missions (Firestore-backed)
    func setPendingContextRewardIfAbsent(uid: String, paymentId: String, title: String, reason: String, coins: Int) async {
        let ref = db.collection("users").document(uid).collection("context_rewards").document(paymentId)
        do {
            try await db.runTransaction { tx, errPtr in
                do {
                    let snap = try tx.getDocument(ref)
                    if snap.exists { return nil }
                    tx.setData([
                        "status": "pending",
                        "title": title,
                        "reason": reason,
                        "coins": coins,
                        "createdAt": FieldValue.serverTimestamp()
                    ], forDocument: ref)
                } catch {
                    errPtr?.pointee = error as NSError
                }
                return nil
            }
        } catch {
            // no-op for demo; creation is best-effort
        }
    }

    func listenToContextReward(uid: String, paymentId: String, onUpdate: @escaping (ContextReward?) -> Void) -> ListenerRegistration {
        let ref = db.collection("users").document(uid).collection("context_rewards").document(paymentId)
        return ref.addSnapshotListener { snap, _ in
            guard let data = snap?.data() else { onUpdate(nil); return }
            let status = data["status"] as? String ?? ""
            guard status == "pending" else { onUpdate(nil); return }
            let title = data["title"] as? String ?? "Bonus"
            let reason = data["reason"] as? String ?? ""
            let coins = data["coins"] as? Int ?? 0
            onUpdate(ContextReward(paymentId: paymentId, title: title, reason: reason, coins: coins, createdAt: Date()))
        }
    }

    func claimContextReward(uid: String, paymentId: String) async throws {
        let contextRef = db.collection("users").document(uid).collection("context_rewards").document(paymentId)
        _ = try await db.runTransaction { (tx, errorPointer) -> Any? in
            do {
                let snap = try tx.getDocument(contextRef)
                guard snap.exists else { return nil }
                let status = snap.data()? ["status"] as? String ?? ""
                guard status == "pending" else { return nil }
                let coins = snap.data()? ["coins"] as? Int ?? 0
                let title = snap.data()? ["title"] as? String ?? "Context Reward"

                // Update user balance and ledger
                let userRef = self.db.collection("users").document(uid)
                let userSnap = try tx.getDocument(userRef)
                let current = (userSnap.data()? ["coinBalance"] as? Int) ?? 0
                tx.setData(["coinBalance": current + coins], forDocument: userRef, merge: true)

                let ledgerRef = userRef.collection("coin_ledger").document("context_\(paymentId)")
                let ledgerSnap = try tx.getDocument(ledgerRef)
                if !ledgerSnap.exists {
                    tx.setData([
                        "type": "earn",
                        "amount": coins,
                        "note": "Context: \(title)",
                        "createdAt": FieldValue.serverTimestamp()
                    ], forDocument: ledgerRef)
                }

                // Mark context reward claimed
                tx.setData(["status": "claimed", "claimedAt": FieldValue.serverTimestamp()], forDocument: contextRef, merge: true)
            } catch {
                errorPointer?.pointee = error as NSError
            }
            return nil
        }
    }
}



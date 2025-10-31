import Foundation

struct ContextReward: Codable, Equatable {
    let paymentId: String
    let title: String
    let reason: String
    let coins: Int
    let createdAt: Date
}

struct ContextRewardOffer {
    let title: String
    let reason: String
    let coins: Int
}

enum ContextRewardsEngine {
    static func evaluate(amountPaise: Int, recipient: String?, pci: Int?, streakDays: Int?) -> ContextRewardOffer? {
        let amountRupees = Double(amountPaise) / 100.0
        let rec = (recipient ?? "").lowercased()
        let now = Date()
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: now) // 1 Sun ... 7 Sat
        let hour = cal.component(.hour, from: now)

        print("🎯 ContextRewardsEngine: Evaluating for recipient='\(rec)', amount=₹\(amountRupees)")
        
        var base: ContextRewardOffer?

        // Food: Zomato, Swiggy (lowered threshold to ₹1.50 for testing)
        if (rec.contains("zomato") || rec.contains("swiggy")) && amountRupees >= 1.5 {
            base = ContextRewardOffer(title: "Food Bonus", reason: "Zomato/Swiggy order ≥ ₹1.50", coins: 50)
            print("✅ ContextRewardsEngine: Matched Food Bonus!")
        }

        // E-com: Flipkart, Amazon, Myntra
        if base == nil, (rec.contains("flipkart") || rec.contains("amazon") || rec.contains("myntra")) && amountRupees >= 5.0 {
            base = ContextRewardOffer(title: "Shopping Bonus", reason: "E‑commerce purchase ≥ ₹5", coins: 40)
            print("✅ ContextRewardsEngine: Matched Shopping Bonus!")
        }

        // Groceries: Blinkit, BigBasket (weekend morning window)
        let isWeekend = (weekday == 1 || weekday == 7)
        if base == nil, (rec.contains("blinkit") || rec.contains("bigbasket")) && isWeekend && (9...12).contains(hour) {
            base = ContextRewardOffer(title: "Groceries Bonus", reason: "Weekend 9–12 AM grocery run", coins: 30)
            print("✅ ContextRewardsEngine: Matched Groceries Bonus!")
        }

        guard var offer = base else {
            print("❌ ContextRewardsEngine: No match")
            return nil
        }

        // Booster: PCI ≥ 700 or streak ≥ 7 → 1.2x
        let hasBooster = (pci ?? 0) >= 700 || (streakDays ?? 0) >= 7
        if hasBooster {
            let boosted = Int(round(Double(offer.coins) * 1.2))
            offer = ContextRewardOffer(title: offer.title + " (Boosted)", reason: offer.reason + " • Booster 1.2×", coins: boosted)
            print("🚀 ContextRewardsEngine: Booster applied! Final coins: \(offer.coins)")
        }
        
        print("🎁 ContextRewardsEngine: Final offer: \(offer.title) - \(offer.coins) coins")
        return offer
    }
}

// MARK: - Local Storage (UserDefaults)
extension UserDefaults {
    private static let pendingKey = "lp_pendingContextReward"
    private static let claimedKey = "lp_claimedContextRewardIds"

    func getPendingContextReward() -> ContextReward? {
        guard let data = data(forKey: Self.pendingKey) else { return nil }
        return try? JSONDecoder().decode(ContextReward.self, from: data)
    }

    func setPendingContextReward(_ reward: ContextReward?) {
        if let reward = reward, let data = try? JSONEncoder().encode(reward) {
            set(data, forKey: Self.pendingKey)
        } else {
            removeObject(forKey: Self.pendingKey)
        }
    }

    func isContextRewardClaimed(paymentId: String) -> Bool {
        let arr = (array(forKey: Self.claimedKey) as? [String]) ?? []
        return arr.contains(paymentId)
    }

    func markContextRewardClaimed(paymentId: String) {
        var arr = (array(forKey: Self.claimedKey) as? [String]) ?? []
        if !arr.contains(paymentId) {
            arr.append(paymentId)
            set(arr, forKey: Self.claimedKey)
        }
    }
}



import Foundation

struct Referral: Identifiable, Codable {
    let id: String
    let referrerUserId: String
    let referredUserId: String?
    let referralCode: String
    let status: String  // pending | completed
    let bonusAwarded: Bool
    let createdAt: Date?
}


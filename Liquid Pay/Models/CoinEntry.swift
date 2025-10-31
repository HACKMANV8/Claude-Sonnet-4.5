import Foundation

struct CoinEntry: Identifiable, Codable {
    let id: String
    let type: String    // earn | redeem | adjust
    let amount: Int     // positive for earn, negative for redeem
    let note: String?
    let createdAt: Date?
}



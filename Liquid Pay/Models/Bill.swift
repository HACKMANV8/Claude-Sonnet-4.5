import Foundation

struct Bill: Identifiable, Codable {
    let id: String
    let userId: String
    let amountPaise: Int
    let status: String   // pending | paid | failed
    let createdAt: Date?
}



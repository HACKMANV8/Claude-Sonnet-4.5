import Foundation

struct Voucher: Identifiable, Codable, Equatable {
    let id: String
    let code: String
    let valuePaise: Int
    let status: String   // active | used
    let createdAt: Date?
    let redeemedAt: Date?
}



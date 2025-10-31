import Foundation

struct CreateOrderResponse: Decodable {
    let orderId: String
    let amount: Int
    let currency: String
    let keyId: String

    enum CodingKeys: String, CodingKey {
        case orderId
        case amount
        case currency
        case keyId
    }
}

enum CloudFunctionsError: LocalizedError {
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Unexpected server response."
        }
    }
}

enum CloudFunctionsService {
    static func createOrder(amountPaise: Int, billId: String) async throws -> CreateOrderResponse {
        var request = URLRequest(url: AppConfig.functionsBaseURL.appendingPathComponent("createOrder"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "amount": amountPaise,
            "currency": "INR",
            "notes": ["billId": billId]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard (200..<300).contains(status) else {
            let serverMessage = String(data: data, encoding: .utf8) ?? ""
            throw NSError(domain: "CloudFunctions", code: status, userInfo: [NSLocalizedDescriptionKey: "Server error: \(serverMessage)"])
        }
        return try JSONDecoder().decode(CreateOrderResponse.self, from: data)
    }
}



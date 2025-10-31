import Foundation

struct QRPaymentData: Codable {
    let merchantId: String?
    let merchantName: String?
    let amount: Int? // in paise
    let billId: String?
    let note: String?
    
    // Parse QR code string (JSON format)
    static func parse(from qrString: String) -> QRPaymentData? {
        guard let data = qrString.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(QRPaymentData.self, from: data)
    }
    
    // Generate QR code string
    func toQRString() -> String? {
        guard let data = try? JSONEncoder().encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    // Simple format parser (fallback for basic "amount:XXX" format)
    static func parseSimple(from qrString: String) -> QRPaymentData? {
        // Format 1: Liquid Pay custom format
        // "liquidpay://pay?amount=1000&merchant=XYZ&note=Bill"
        if qrString.starts(with: "liquidpay://pay") {
            guard let url = URL(string: qrString),
                  let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
                return nil
            }
            
            var amountPaise: Int?
            var merchantName: String?
            var merchantId: String?
            var billId: String?
            var note: String?
            
            for item in components.queryItems ?? [] {
                switch item.name {
                case "amount":
                    amountPaise = Int(item.value ?? "")
                case "merchant":
                    merchantName = item.value
                case "merchantId":
                    merchantId = item.value
                case "billId":
                    billId = item.value
                case "note":
                    note = item.value
                default:
                    break
                }
            }
            
            return QRPaymentData(
                merchantId: merchantId,
                merchantName: merchantName,
                amount: amountPaise,
                billId: billId,
                note: note
            )
        }
        
        // Format 2: Standard UPI QR codes (GPay, Paytm, PhonePe, etc.)
        // "upi://pay?pa=merchant@upi&pn=MerchantName&am=100&cu=INR&tn=Note"
        if qrString.starts(with: "upi://pay") {
            guard let url = URL(string: qrString),
                  let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
                return nil
            }
            
            var upiId: String?
            var merchantName: String?
            var amountPaise: Int?
            var note: String?
            
            for item in components.queryItems ?? [] {
                switch item.name.lowercased() {
                case "pa": // Payee address (UPI ID)
                    upiId = item.value
                case "pn": // Payee name
                    merchantName = item.value
                case "am": // Amount in rupees
                    if let rupees = Double(item.value ?? "") {
                        amountPaise = Int(rupees * 100)
                    }
                case "tn": // Transaction note
                    note = item.value
                default:
                    break
                }
            }
            
            return QRPaymentData(
                merchantId: upiId,
                merchantName: merchantName,
                amount: amountPaise,
                billId: nil,
                note: note
            )
        }
        
        return nil
    }
}


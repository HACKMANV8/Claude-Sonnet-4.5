import SwiftUI
import CoreImage.CIFilterBuiltins
import FirebaseAuth

struct ReceivePaymentView: View {
    @State private var showQRCode: Bool = false
    @State private var qrImage: UIImage?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // QR Code display (no amount/note; payer enters on their side)
                VStack(spacing: 24) {
                    Text("Scan to Pay")
                        .font(.title2)
                        .bold()
                    
                    if let qrImage = qrImage {
                        Image(uiImage: qrImage)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 250, height: 250)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(12)
                            .shadow(radius: 4)
                    }
                    
                    Button {
                        if let qrImage = qrImage { shareQRCode(qrImage) }
                    } label: {
                        Label("Share QR Code", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                }
                .padding()
                Spacer()
            }
            .navigationTitle("Receive Payment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                if !showQRCode { generateQRCode() }
            }
        }
    }
    
    private func generateQRCode() {
        // Generate a generic pay QR with merchant identity; payer will enter amount and note
        let merchantId = Auth.auth().currentUser?.uid ?? ""
        let merchant = Auth.auth().currentUser?.phoneNumber ?? ""
        var urlString = "liquidpay://pay"
        var comps: [String] = []
        if !merchant.isEmpty { comps.append("merchant=\(merchant)") }
        if !merchantId.isEmpty { comps.append("merchantId=\(merchantId)") }
        if !comps.isEmpty { urlString += "?" + comps.joined(separator: "&") }
        qrImage = generateQRCodeImage(from: urlString)
        showQRCode = true
    }
    
    private func generateQRCodeImage(from string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        
        guard let outputImage = filter.outputImage else { return nil }
        
        let transform = CGAffineTransform(scaleX: 10, y: 10)
        let scaledImage = outputImage.transformed(by: transform)
        
        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else {
            return nil
        }
        
        return UIImage(cgImage: cgImage)
    }
    
    private func shareQRCode(_ image: UIImage) {
        let activityVC = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            var topVC = rootVC
            while let presented = topVC.presentedViewController {
                topVC = presented
            }
            topVC.present(activityVC, animated: true)
        }
    }
}


import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct PayView: View {
    @StateObject private var vm = PaymentViewModel()
    @State private var amountInInr: String = ""
    @State private var upiIdOrPhone: String = ""
    @State private var activeVouchers: [Voucher] = []
    @State private var vouchersListener: ListenerRegistration?
    @State private var selectedVoucher: Voucher?
    @State private var showErrorAlert: Bool = false
    @State private var errorAlertMessage: String = ""
    @State private var showQRScanner: Bool = false
    @State private var showReceivePayment: Bool = false
    @State private var navigateToUPIPay: Bool = false
    @State private var scannedQRData: QRPaymentData?

    var body: some View {
        VStack(spacing: 24) {
            // Large Scan QR Button
            Button {
                showQRScanner = true
            } label: {
        VStack(spacing: 16) {
                    Image(systemName: "qrcode.viewfinder")
                        .font(.system(size: 80))
                    Text("Scan QR Code to Pay")
                        .font(.title3)
                        .bold()
                }
                .frame(maxWidth: .infinity)
                .frame(height: 200)
                .background(
                    LinearGradient(
                        colors: [Color.accentColor.opacity(0.2), Color.accentColor.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .foregroundColor(.accentColor)
                .cornerRadius(20)
            }

            Divider()
            
            // Pay by UPI ID Button
            Button {
                navigateToUPIPay = true
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Pay by UPI ID")
                            .font(.headline)
                        Text("Enter UPI ID to send payment")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
                    .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
            }
            .buttonStyle(.plain)

            if let msg = vm.lastResultMessage {
                Text(msg).foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
        .navigationTitle("Pay")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showReceivePayment = true
                } label: {
                    Image(systemName: "qrcode")
                }
            }
        }
        .onAppear {
            if let uid = Auth.auth().currentUser?.uid {
                vouchersListener?.remove(); vouchersListener = nil
                vouchersListener = RewardsService.shared.listenActiveVouchers(uid: uid) { vouchers in
                    activeVouchers = vouchers
                    if let currentVoucher = selectedVoucher, 
                       !vouchers.contains(where: { $0.id == currentVoucher.id }) {
                        selectedVoucher = nil
                    }
                }
            }
        }
        .onDisappear { vouchersListener?.remove(); vouchersListener = nil }
        .alert("Error", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorAlertMessage)
        }
        .fullScreenCover(isPresented: $showQRScanner) {
            QRScannerView { qrCode in
                handleScannedQR(qrCode)
            }
        }
        .sheet(isPresented: $showReceivePayment) {
            ReceivePaymentView()
        }
        .navigationDestination(isPresented: $navigateToUPIPay) {
            PayByUPIView(
                vouchers: activeVouchers,
                selectedVoucher: $selectedVoucher,
                initialUPIId: scannedQRData?.merchantId ?? "",
                initialAmount: {
                    if let amount = scannedQRData?.amount { return String(amount / 100) }
                    return ""
                }()
            )
        }
    }
    
    private func handleScannedQR(_ qrCode: String) {
        print("🔍 Scanned QR: \(qrCode)")
        
        // Try parsing as JSON first
        if let qrData = QRPaymentData.parse(from: qrCode) {
            print("✅ Parsed as JSON")
            scannedQRData = qrData
            navigateToUPIPay = true
        } else if let qrData = QRPaymentData.parseSimple(from: qrCode) {
            print("✅ Parsed as UPI format")
            scannedQRData = qrData
            navigateToUPIPay = true
        } else {
            print("❌ Failed to parse QR")
            errorAlertMessage = "Invalid QR code format. Please scan a valid UPI QR code."
            showErrorAlert = true
        }
    }
}



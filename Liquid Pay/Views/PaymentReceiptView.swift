import SwiftUI

struct PaymentReceiptView: View {
    let payment: Payment
    @Environment(\.dismiss) private var dismiss
    @State private var showShare = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: payment.status == "success" ? "checkmark.circle.fill" : payment.status == "failed" ? "xmark.circle.fill" : "clock.fill")
                        .font(.system(size: 64))
                        .foregroundColor(payment.status == "success" ? .green : payment.status == "failed" ? .red : .orange)
                    Text(payment.status == "success" ? "Payment Successful" : payment.status == "failed" ? "Payment Failed" : "Payment Pending")
                        .font(.title2).bold()
                    Text(Currency.formatPaise(payment.amountPaise))
                        .font(.system(size: 48, weight: .bold))
                }
                .padding(.top, 20)
                
                // Details Card
                VStack(alignment: .leading, spacing: 16) {
                    DetailRow(label: "Status", value: payment.status.capitalized)
                    if let date = payment.createdAt {
                        DetailRow(label: "Date & Time", value: date.formatted(date: .long, time: .shortened))
                    }
                    if let pid = payment.razorpayPaymentId, !pid.isEmpty {
                        DetailRow(label: "Payment ID", value: pid)
                    }
                    if let bid = payment.billId, !bid.isEmpty {
                        DetailRow(label: "Bill ID", value: bid)
                    }
                    DetailRow(label: "Amount", value: Currency.formatPaise(payment.amountPaise))
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                
                // Actions
                VStack(spacing: 12) {
                    if payment.status == "failed" {
                        NavigationLink(destination: PayView()) {
                            Label("Retry Payment", systemImage: "arrow.clockwise")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.orange)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                    }
                    
                    Button {
                        showShare = true
                    } label: {
                        Label("Share Receipt", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    
                    Button {
                        dismiss()
                    } label: {
                        Text("Close")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .foregroundColor(.primary)
                            .cornerRadius(12)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Receipt")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showShare) {
            ShareSheet(activityItems: [generateReceiptText()])
        }
    }
    
    private func generateReceiptText() -> String {
        var text = "═══════════════════════\n"
        text += "     LIQUID PAY RECEIPT\n"
        text += "═══════════════════════\n\n"
        text += "Amount: \(Currency.formatPaise(payment.amountPaise))\n"
        text += "Status: \(payment.status.capitalized)\n"
        if let date = payment.createdAt {
            text += "Date: \(date.formatted(date: .long, time: .shortened))\n"
        }
        if let pid = payment.razorpayPaymentId, !pid.isEmpty {
            text += "Payment ID: \(pid)\n"
        }
        if let bid = payment.billId, !bid.isEmpty {
            text += "Bill ID: \(bid)\n"
        }
        text += "\n═══════════════════════\n"
        text += "Thank you for using Liquid Pay!\n"
        return text
    }
}

private struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label).foregroundColor(.secondary)
            Spacer()
            Text(value).bold()
        }
    }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}


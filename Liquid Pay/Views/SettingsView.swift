import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import PDFKit

struct SettingsView: View {
    @AppStorage("isDarkMode") private var isDarkMode: Bool = false
    @State private var shareURL: URL?
    @State private var showShare: Bool = false
    @State private var isExporting: Bool = false
    @State private var referralCode: String = ""
    @State private var referralStats: (totalReferred: Int, totalEarned: Int)?
    @State private var showReferralInput: Bool = false
    @State private var referralInputCode: String = ""
    @State private var referralMessage: String?
    
    var body: some View {
        Form {
            Section(header: Text("Account")) {
                HStack {
                    Text("Phone")
                    Spacer()
                    Text(Auth.auth().currentUser?.phoneNumber ?? "—").foregroundColor(.secondary)
                }
                Button(role: .destructive) {
                    try? Auth.auth().signOut()
                } label: {
                    Text("Log Out")
                }
            }
            Section(header: Text("Refer & Earn")) {
                Button {
                    shareURL = nil
                    showShare = true
                } label: {
                    Label("Share Referral Link", systemImage: "square.and.arrow.up")
                }
                .disabled(referralCode.isEmpty)
                
                if let stats = referralStats {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Total Referred: \(stats.totalReferred)").font(.subheadline)
                        Text("Total Earned: \(stats.totalEarned) coins").font(.subheadline).foregroundColor(.green)
                    }
                }
                
                Button {
                    showReferralInput = true
                } label: {
                    Text("Enter Referral Code")
                }
                
                if let msg = referralMessage {
                    Text(msg).font(.caption).foregroundColor(msg.contains("Success") || msg.contains("already") ? .green : .red)
                }
            }
            Section(header: Text("Appearance")) {
                Toggle("Dark Mode", isOn: $isDarkMode)
            }
            Section(header: Text("About")) {
                HStack {
                    Text("Version")
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                        .foregroundColor(.secondary)
                }
            }
            Section(header: Text("Export")) {
                if isExporting { ProgressView("Preparing export...") }
                Button {
                    Task { await exportPaymentsAsCSV() }
                } label: { Text("Export Payments (CSV)") }
                Button {
                    Task { await exportPaymentsAsPDF() }
                } label: { Text("Export Payments (PDF)") }
            }
        }
        .navigationTitle("Settings")
        .sheet(isPresented: $showShare, onDismiss: { shareURL = nil }) {
            if let url = shareURL {
                ShareSheet(activityItems: [url])
            } else {
                let message = "Join Liquid Pay with my referral code \(referralCode) and earn bonus coins! 🎉"
                ShareSheet(activityItems: [message])
            }
        }
        .sheet(isPresented: $showReferralInput) {
            ReferralInputSheet(onSubmit: { code in
                Task {
                    guard let uid = Auth.auth().currentUser?.uid else { return }
                    
                    // Check if already used
                    let userDoc = try? await Firestore.firestore().collection("users").document(uid).getDocument()
                    if let usedCode = userDoc?.data()?["usedReferralCode"] as? String {
                        referralMessage = "You've already used referral code: \(usedCode)"
                        showReferralInput = false
                        return
                    }
                    
                    do {
                        try await ReferralService.shared.applyReferralCode(uid: uid, code: code)
                        referralMessage = "Success! Bonus coins awarded!"
                    } catch {
                        referralMessage = error.localizedDescription
                    }
                }
                showReferralInput = false
            })
            .presentationDetents([.height(200)])
        }
        .onAppear {
            Task {
                guard let uid = Auth.auth().currentUser?.uid else { return }
                referralCode = (try? await ReferralService.shared.getUserReferralCode(uid: uid)) ?? ""
                referralStats = try? await ReferralService.shared.getReferralStats(uid: uid)
                
                // Check if user has already used a referral code
                let userDoc = try? await Firestore.firestore().collection("users").document(uid).getDocument()
                if let usedCode = userDoc?.data()?["usedReferralCode"] as? String {
                    referralMessage = "You've already used referral code: \(usedCode)"
                }
            }
        }
    }

    // MARK: - Export Helpers
    private func fetchPayments() async -> [[String: Any]] {
        guard let uid = Auth.auth().currentUser?.uid else { return [] }
        do {
            let snap = try await Firestore.firestore()
                .collection("payments")
                .whereField("userId", isEqualTo: uid)
                .order(by: "createdAt", descending: true)
                .getDocuments()
            return snap.documents.map { $0.data() }
        } catch { return [] }
    }

    private func exportPaymentsAsCSV() async {
        isExporting = true
        let rows = await fetchPayments()
        let header = ["paymentId","amountPaise","status","billId","createdAt"]
        var csv = header.joined(separator: ",") + "\n"
        for r in rows {
            let pid = (r["razorpayPaymentId"] as? String) ?? ""
            let amt = (r["amountPaise"] as? Int) ?? 0
            let st = (r["status"] as? String) ?? ""
            let bid = (r["billId"] as? String) ?? ""
            let ts = (r["createdAt"] as? Timestamp)?.dateValue().ISO8601Format() ?? ""
            let line = [pid, String(amt), st, bid, ts].map { $0.replacingOccurrences(of: ",", with: " ") }.joined(separator: ",")
            csv.append(contentsOf: line + "\n")
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("payments.csv")
        try? csv.data(using: .utf8)?.write(to: url)
        shareURL = url
        isExporting = false
        showShare = true
    }

    private func exportPaymentsAsPDF() async {
        isExporting = true
        let rows = await fetchPayments()
        let pdfMeta = [kCGPDFContextCreator: "Liquid Pay", kCGPDFContextAuthor: "Liquid Pay App"]
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("payments.pdf") as CFURL
        guard let consumer = CGDataConsumer(url: url),
              let ctx = CGContext(consumer: consumer, mediaBox: nil, pdfMeta as CFDictionary) else { isExporting = false; return }
        let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842) // A4
        ctx.beginPDFPage([kCGPDFContextMediaBox: pageRect] as CFDictionary)
        let title = "Payments Export"
        draw(text: title, at: CGPoint(x: 40, y: pageRect.height - 60), font: .boldSystemFont(ofSize: 18), ctx: ctx)
        var y: CGFloat = pageRect.height - 100
        for r in rows {
            if y < 60 { ctx.endPDFPage(); ctx.beginPDFPage([kCGPDFContextMediaBox: pageRect] as CFDictionary); y = pageRect.height - 60 }
            let pid = (r["razorpayPaymentId"] as? String) ?? ""
            let amt = (r["amountPaise"] as? Int) ?? 0
            let st = (r["status"] as? String) ?? ""
            let ts = (r["createdAt"] as? Timestamp)?.dateValue().formatted(date: .abbreviated, time: .shortened) ?? ""
            let line = "\(pid)  ₹\(Double(amt)/100.0)  \(st)  \(ts)"
            draw(text: line, at: CGPoint(x: 40, y: y), font: .systemFont(ofSize: 12), ctx: ctx)
            y -= 18
        }
        ctx.endPDFPage()
        ctx.closePDF()
        shareURL = (url as URL)
        isExporting = false
        showShare = true
    }

    private func draw(text: String, at point: CGPoint, font: UIFont, ctx: CGContext) {
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        let attrStr = NSAttributedString(string: text, attributes: attrs)
        let line = CTLineCreateWithAttributedString(attrStr)
        ctx.textPosition = point
        CTLineDraw(line, ctx)
    }
}

// MARK: - ShareSheet
private struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - ReferralInputSheet
private struct ReferralInputSheet: View {
    var onSubmit: (_ code: String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var codeText: String = ""
    
    var body: some View {
        VStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 2).fill(Color.secondary.opacity(0.4)).frame(width: 44, height: 4).padding(.top, 8)
            Text("Enter Referral Code").font(.headline)
            TextField("e.g., LPABCD12", text: $codeText)
                .textFieldStyle(.roundedBorder)
                .autocapitalization(.allCharacters)
            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Button("Submit") {
                    guard !codeText.isEmpty else { return }
                    onSubmit(codeText)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }
}



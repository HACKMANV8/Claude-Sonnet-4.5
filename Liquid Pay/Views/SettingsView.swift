import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import PDFKit
import PhotosUI
import UIKit

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
    @State private var showExportPicker: Bool = false
    // Profile state
    @State private var profileName: String = ""
    @State private var profileDOB: Date = Date()
    @State private var profileImage: UIImage?
    @State private var showImagePicker: Bool = false
    @State private var isSavingProfile: Bool = false
    @State private var isEditingProfile: Bool = false
    
    var body: some View {
        Form {
            // Profile
            Section(header: Text("Profile")) {
                if !isEditingProfile {
                    HStack(spacing: 16) {
                        ZStack {
                            if let img = profileImage {
                                Image(uiImage: img)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 72, height: 72)
                                    .clipShape(Circle())
                            } else {
                                Circle().fill(Color(.secondarySystemBackground)).frame(width: 72, height: 72)
                                    .overlay(
                                        Image(systemName: "person.fill")
                                            .font(.system(size: 28))
                                            .foregroundColor(.secondary)
                                    )
                            }
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(profileName.isEmpty ? "Your Name" : profileName)
                                .font(.headline)
                            Text(profileDOB.formatted(date: .abbreviated, time: .omitted))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button("Edit") { isEditingProfile = true }
                            .buttonStyle(.bordered)
                    }
                    .padding(.vertical, 4)
                } else {
                    HStack(spacing: 16) {
                        ZStack {
                            if let img = profileImage {
                                Image(uiImage: img)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 72, height: 72)
                                    .clipShape(Circle())
                            } else {
                                Circle().fill(Color(.secondarySystemBackground)).frame(width: 72, height: 72)
                                    .overlay(
                                        Image(systemName: "person.fill")
                                            .font(.system(size: 28))
                                            .foregroundColor(.secondary)
                                    )
                            }
                        }
                        Button { showImagePicker = true } label: { Text("Change Photo") }
                    }
                    TextField("Your Name", text: $profileName)
                        .textContentType(.name)
                    DatePicker("Date of Birth", selection: $profileDOB, displayedComponents: .date)
                    HStack {
                        Button("Cancel") { isEditingProfile = false }
                        Spacer()
                        Button {
                            Task {
                                await saveProfile()
                                isEditingProfile = false
                            }
                        } label: {
                            if isSavingProfile { ProgressView() } else { Text("Save") }
                        }
                        .disabled(isSavingProfile)
                    }
                }
            }
            Section(header: Text("Account")) {
                HStack {
                    Text("Phone")
                    Spacer()
                    Text(Auth.auth().currentUser?.phoneNumber ?? "—").foregroundColor(.secondary)
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
                    showExportPicker = true
                } label: {
                    Label("Export Payments", systemImage: "square.and.arrow.up")
                }
            }
            // Logout at bottom
            Section {
                HStack { Spacer()
                    Button {
                        try? Auth.auth().signOut()
                    } label: {
                        Text("Log Out")
                            .foregroundColor(.white)
                            .padding(.horizontal, 28)
                            .padding(.vertical, 12)
                            .background(Capsule().fill(Color.red))
                    }
                    Spacer() }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
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
            .presentationDetents([.medium])
        }
        .confirmationDialog("Choose Export Format", isPresented: $showExportPicker, titleVisibility: .visible) {
            Button("Export as PDF") {
                Task { await exportPaymentsAsPDF() }
            }
            Button("Export as CSV") {
                Task { await exportPaymentsAsCSV() }
            }
            Button("Cancel", role: .cancel) { }
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
                await loadProfile()
            }
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(image: $profileImage)
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
    
    // MARK: - Profile Helpers
    private func loadProfile() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let doc = try? await Firestore.firestore().collection("users").document(uid).getDocument()
        let data = doc?.data() ?? [:]
        if let name = data["name"] as? String { profileName = name }
        if let ts = data["dob"] as? Timestamp { profileDOB = ts.dateValue() }
        if let base64 = data["profileImageBase64"] as? String, let imgData = Data(base64Encoded: base64), let img = UIImage(data: imgData) {
            profileImage = img
        }
    }

    private func saveProfile() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        isSavingProfile = true
        var update: [String: Any] = [
            "name": profileName,
            "dob": Timestamp(date: profileDOB)
        ]
        if let img = profileImage, let data = img.jpegData(compressionQuality: 0.6) {
            update["profileImageBase64"] = data.base64EncodedString()
        }
        do {
            try await Firestore.firestore().collection("users").document(uid).setData(update, merge: true)
        } catch { }
        isSavingProfile = false
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

// Simple PHPicker-based image picker
private struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ controller: PHPickerViewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: ImagePicker
        init(_ parent: ImagePicker) { self.parent = parent }
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard let provider = results.first?.itemProvider, provider.canLoadObject(ofClass: UIImage.self) else { return }
            provider.loadObject(ofClass: UIImage.self) { object, _ in
                if let img = object as? UIImage {
                    DispatchQueue.main.async { self.parent.image = img }
                }
            }
        }
    }
}



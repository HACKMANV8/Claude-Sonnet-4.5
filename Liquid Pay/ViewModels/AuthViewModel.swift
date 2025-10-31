import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var phoneNumber: String = "+91"
    @Published var verificationCode: String = ""
    @Published var verificationID: String?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var isSignedIn: Bool = false

    private var authHandle: AuthStateDidChangeListenerHandle?

    init() {
        isSignedIn = Auth.auth().currentUser != nil
        authHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.isSignedIn = (user != nil)
        }
    }

    deinit {
        if let h = authHandle { Auth.auth().removeStateDidChangeListener(h) }
    }

    func sendOTP() async {
        errorMessage = nil
        isLoading = true
        do {
            let id = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
                PhoneAuthProvider.provider().verifyPhoneNumber(self.phoneNumber, uiDelegate: nil) { verificationID, error in
                    if let error = error { continuation.resume(throwing: error); return }
                    continuation.resume(returning: verificationID ?? "")
                }
            }
            guard !id.isEmpty else { throw NSError(domain: "Auth", code: -1, userInfo: [NSLocalizedDescriptionKey: "Empty verificationID"]) }
            verificationID = id
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func confirmCode() async {
        guard let id = verificationID, !verificationCode.isEmpty else {
            errorMessage = "Enter the code sent to your phone"
            return
        }
        errorMessage = nil
        isLoading = true
        do {
            let credential = PhoneAuthProvider.provider().credential(withVerificationID: id, verificationCode: verificationCode)
            let result = try await Auth.auth().signIn(with: credential)
            // Ensure a basic user document exists
            let uid = result.user.uid
            let users = Firestore.firestore().collection("users")
            let docRef = users.document(uid)
            let snapshot = try await docRef.getDocument()
            if !snapshot.exists {
                try await docRef.setData([
                    "uid": uid,
                    "phoneNumber": result.user.phoneNumber ?? "",
                    "createdAt": FieldValue.serverTimestamp(),
                ])
            }
            isSignedIn = true
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func signOut() {
        try? Auth.auth().signOut()
    }
}



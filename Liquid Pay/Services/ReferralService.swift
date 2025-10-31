import Foundation
import FirebaseFirestore
import FirebaseAuth

final class ReferralService {
    static let shared = ReferralService()
    private let db = Firestore.firestore()
    
    private let referrerBonus = 50000 // 500 coins = ₹5
    private let refereeBonus = 25000  // 250 coins = ₹2.5
    
    func generateReferralCode(for uid: String) -> String {
        let prefix = "LP"
        let suffix = String(uid.prefix(6)).uppercased()
        return "\(prefix)\(suffix)"
    }
    
    func getUserReferralCode(uid: String) async throws -> String {
        let userDoc = try await db.collection("users").document(uid).getDocument()
        if let code = userDoc.data()?["referralCode"] as? String {
            return code
        }
        
        // Generate and save new code
        let code = generateReferralCode(for: uid)
        try await db.collection("users").document(uid).setData(["referralCode": code], merge: true)
        return code
    }
    
    func applyReferralCode(uid: String, code: String) async throws {
        let userDoc = try await db.collection("users").document(uid).getDocument()
        let hasUsedReferral = (userDoc.data()?["usedReferralCode"] as? String) != nil
        if hasUsedReferral {
            throw NSError(domain: "Referral", code: 400, userInfo: [NSLocalizedDescriptionKey: "You've already used a referral code"])
        }
        
        // Find referrer
        let referrerSnap = try await db.collection("users").whereField("referralCode", isEqualTo: code).limit(to: 1).getDocuments()
        guard let referrerDoc = referrerSnap.documents.first else {
            throw NSError(domain: "Referral", code: 404, userInfo: [NSLocalizedDescriptionKey: "Invalid referral code"])
        }
        let referrerUid = referrerDoc.documentID
        
        guard referrerUid != uid else {
            throw NSError(domain: "Referral", code: 400, userInfo: [NSLocalizedDescriptionKey: "You can't refer yourself"])
        }
        
        // Create referral record and award coins
        try await db.collection("referrals").addDocument(data: [
            "referrerUserId": referrerUid,
            "referredUserId": uid,
            "referralCode": code,
            "status": "completed",
            "bonusAwarded": true,
            "createdAt": FieldValue.serverTimestamp()
        ])
        
        // Mark user as having used referral
        try await db.collection("users").document(uid).setData(["usedReferralCode": code], merge: true)
        
        // Award bonus to referrer
        let referrerUserRef = db.collection("users").document(referrerUid)
        let referrerLedgerRef = referrerUserRef.collection("coin_ledger").document("referral_\(uid)")
        _ = try await db.runTransaction { (tx, errorPointer) -> Any? in
            do {
                let referrerSnap = try tx.getDocument(referrerUserRef)
                let current = (referrerSnap.data()?["coinBalance"] as? Int) ?? 0
                tx.setData(["coinBalance": current + self.referrerBonus], forDocument: referrerUserRef, merge: true)
                tx.setData([
                    "type": "earn",
                    "amount": self.referrerBonus,
                    "note": "Referral bonus - Friend joined!",
                    "createdAt": FieldValue.serverTimestamp()
                ], forDocument: referrerLedgerRef)
            } catch {
                errorPointer?.pointee = error as NSError
            }
            return nil
        }
        
        // Award bonus to referee
        let refereeUserRef = db.collection("users").document(uid)
        let refereeLedgerRef = refereeUserRef.collection("coin_ledger").document("referral_welcome")
        _ = try await db.runTransaction { (tx, errorPointer) -> Any? in
            do {
                let refereeSnap = try tx.getDocument(refereeUserRef)
                let current = (refereeSnap.data()?["coinBalance"] as? Int) ?? 0
                tx.setData(["coinBalance": current + self.refereeBonus], forDocument: refereeUserRef, merge: true)
                tx.setData([
                    "type": "earn",
                    "amount": self.refereeBonus,
                    "note": "Welcome bonus - Used referral code!",
                    "createdAt": FieldValue.serverTimestamp()
                ], forDocument: refereeLedgerRef)
            } catch {
                errorPointer?.pointee = error as NSError
            }
            return nil
        }
    }
    
    func getReferralStats(uid: String) async throws -> (totalReferred: Int, totalEarned: Int) {
        let referralsSnap = try await db.collection("referrals")
            .whereField("referrerUserId", isEqualTo: uid)
            .whereField("status", isEqualTo: "completed")
            .getDocuments()
        
        let count = referralsSnap.documents.count
        let earned = count * referrerBonus
        return (count, earned)
    }
}


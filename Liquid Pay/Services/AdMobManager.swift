import Foundation
import GoogleMobileAds
import UIKit

@MainActor
final class AdMobManager: NSObject, ObservableObject {
    static let shared = AdMobManager()
    
    private var interstitialAd: GADInterstitialAd?
    private var adShownThisSession: Bool = false // In-memory, resets on app launch
    
    // Test Ad Unit ID - Replace with your real ad unit ID in production
    // Test ID: ca-app-pub-3940256099942544/4411468910
    private let interstitialAdUnitID: String = {
        // Check Info.plist for custom ad unit ID, fallback to test ID
        if let customID = Bundle.main.infoDictionary?["GADInterstitialAdUnitID"] as? String, !customID.isEmpty {
            return customID
        }
        return "ca-app-pub-3940256099942544/4411468910" // Test ID
    }()
    
    private override init() {
        super.init()
        // Register for app lifecycle notifications to reset session on app launch/active
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(resetSession),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }
    
    @objc private func resetSession() {
        // Reset session flag when app becomes active (covers app launch too)
        // Only reset if it's been a significant time since last reset
        let lastResetKey = "lastAdShownTimestamp"
        if let lastShown = UserDefaults.standard.object(forKey: lastResetKey) as? Date {
            // Reset if app was backgrounded for more than 30 minutes
            let minutesSince = Date().timeIntervalSince(lastShown) / 60
            if minutesSince > 30 {
                adShownThisSession = false
            }
        } else {
            adShownThisSession = false
        }
    }
    
    func loadInterstitial() async {
        let request = GADRequest()
        do {
            interstitialAd = try await GADInterstitialAd.load(withAdUnitID: interstitialAdUnitID, request: request)
            interstitialAd?.fullScreenContentDelegate = self
        } catch {
            print("❌ AdMob: Failed to load interstitial ad - \(error.localizedDescription)")
        }
    }
    
    func showInterstitialIfAvailable(from viewController: UIViewController) -> Bool {
        // Only show if ad is loaded and hasn't been shown this session
        guard !adShownThisSession, let ad = interstitialAd else {
            return false
        }
        
        // Mark as shown immediately to prevent double-showing
        adShownThisSession = true
        UserDefaults.standard.set(Date(), forKey: "lastAdShownTimestamp")
        
        // Present ad
        ad.present(fromRootViewController: viewController)
        return true
    }
}

// MARK: - GADFullScreenContentDelegate
extension AdMobManager: GADFullScreenContentDelegate {
    nonisolated func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        Task { @MainActor in
            // Reload ad for next time
            await loadInterstitial()
        }
    }
    
    nonisolated func ad(_ ad: GADFullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("❌ AdMob: Failed to present ad - \(error.localizedDescription)")
        Task { @MainActor in
            // Try to reload for next time
            await loadInterstitial()
        }
    }
    
    nonisolated func adWillPresentFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        print("✅ AdMob: Ad will present")
    }
}


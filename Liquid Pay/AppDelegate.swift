import UIKit
import FirebaseCore
import FirebaseAuth
import UserNotifications
import GoogleMobileAds

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        FirebaseApp.configure()
        #if targetEnvironment(simulator)
        // On simulator, bypass app verification and use test phone numbers
        Auth.auth().settings?.isAppVerificationDisabledForTesting = true
        #endif
        // Register for remote notifications so Firebase Auth can verify via silent push
        UIApplication.shared.registerForRemoteNotifications()
        
        // Set notification delegate to handle foreground notifications
        UNUserNotificationCenter.current().delegate = self
        
        // Initialize AdMob
        MobileAds.shared.start(completionHandler: { status in
            print("✅ AdMob initialized")
        })
        
        // Configure test device for AdMob
        let testDeviceID = "aada182688b00b9efa03807b9989fd14"
        MobileAds.shared.requestConfiguration.testDeviceIdentifiers = [testDeviceID]
        print("📱 AdMob: Test device configured - \(testDeviceID)")
        
        // Load initial ad after configuration
        Task { @MainActor in
            await AdMobManager.shared.loadInterstitial()
        }
        
        return true
    }

    // Forward APNs device token to Firebase Auth when swizzling is off or unreliable
    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Auth.auth().setAPNSToken(deviceToken, type: .unknown)
    }

    // Forward Firebase Auth related push notifications
    func application(_ application: UIApplication,
                     didReceiveRemoteNotification notification: [AnyHashable : Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        if Auth.auth().canHandleNotification(notification) {
            completionHandler(.noData)
            return
        }
        completionHandler(.noData)
    }

    // Forward reCAPTCHA/redirect URLs to Firebase Auth if needed
    func application(_ app: UIApplication, open url: URL,
                     options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        if Auth.auth().canHandle(url) {
            return true
        }
        return false
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension AppDelegate: UNUserNotificationCenterDelegate {
    // This method is called when a notification is delivered to a foreground app
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    // This method is called when the user taps on a notification
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        // Handle notification tap if needed
        completionHandler()
    }
}



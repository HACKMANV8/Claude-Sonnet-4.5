import UIKit
import FirebaseCore
import FirebaseAuth

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



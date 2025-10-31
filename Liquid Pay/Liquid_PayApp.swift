//
//  Liquid_PayApp.swift
//  Liquid Pay
//
//  Created by Rishi Selarka on 30/10/25.
//

import SwiftUI
 
@main
struct Liquid_PayApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @AppStorage("isDarkMode") private var isDarkMode: Bool = false
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(isDarkMode ? .dark : .light)
        }
    }
}

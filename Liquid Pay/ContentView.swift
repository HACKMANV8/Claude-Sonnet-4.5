//
//  ContentView.swift
//  Liquid Pay
//
//  Created by Rishi Selarka on 30/10/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var authVM = AuthViewModel()
    @State private var showSplash = true

    var body: some View {
        ZStack {
            Group {
                if authVM.isSignedIn {
                    MainTabView()
                } else {
                    PhoneSignInView()
                }
            }
            .allowsHitTesting(!showSplash)
            .opacity(showSplash ? 0 : 1)

            if showSplash {
                SplashView()
                    .transition(.opacity)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.easeOut(duration: 0.3)) {
                    showSplash = false
                }
            }
            Task {
                _ = await NotificationService.shared.requestPermission()
            }
        }
    }
}

#Preview {
    ContentView()
}

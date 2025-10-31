//
//  ContentView.swift
//  Liquid Pay
//
//  Created by Rishi Selarka on 30/10/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var authVM = AuthViewModel()

    var body: some View {
        Group {
            if authVM.isSignedIn {
                MainTabView()
            } else {
                PhoneSignInView()
            }
        }
    }
}

#Preview {
    ContentView()
}

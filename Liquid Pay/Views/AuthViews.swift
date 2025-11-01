import SwiftUI
import UIKit

struct PhoneSignInView: View {
    @StateObject private var vm = AuthViewModel()
    @State private var showOTPView = false
    @State private var currentFeatureIndex = 0
    
    // Features to animate
    private let features: [(icon: String, text: String)] = [
        ("lock.shield.fill", "Private by design"),
        ("bolt.fill", "Instant payments"),
        ("chart.line.uptrend.xyaxis", "Track spending"),
        ("gift.fill", "Earn rewards"),
        ("creditcard.fill", "Secure transactions")
    ]
    
    // Timer for feature animation
    @State private var featureTimer: Timer?

    var body: some View {
        ZStack {
            // Gradient Background (Dark Teal/Blue to Purple/Magenta)
            LinearGradient(
                colors: [
                    Color(red: 0.1, green: 0.15, blue: 0.25), // Dark teal-blue
                    Color(red: 0.15, green: 0.1, blue: 0.2),  // Dark purple-magenta
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .ignoresSafeArea()
            .onTapGesture {
                hideKeyboard()
            }
            
            VStack(spacing: 0) {
                // Top Section: App Icon & Tagline
                VStack(spacing: 16) {
                    Spacer()
                        .frame(height: 60)
                    
                    // App Icon Box (Rounded Square with App Name)
                    VStack(spacing: 12) {
                        if let appIcon = UIImage(named: "AppIcon") ?? UIImage(named: "Your paragraph text (5) (1)") {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.white)
                                .frame(width: 100, height: 100)
                                .overlay(
                                    Image(uiImage: appIcon)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 100, height: 100)
                                        .clipShape(RoundedRectangle(cornerRadius: 20))
                                )
                        } else {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.white)
                                .frame(width: 100, height: 100)
                                .overlay(
                                    Text("LP")
                                        .font(.system(size: 40, weight: .bold, design: .rounded))
                                        .foregroundColor(.black)
                                )
                        }
                        
                        Text("Liquid Pay")
                            .font(.system(size: 32, weight: .bold, design: .serif))
                            .foregroundColor(.white)
                        
                        Text("UPI Rewards for Timed Payments")
                            .font(.system(size: 16, weight: .regular, design: .rounded))
                            .foregroundColor(Color.gray.opacity(0.8))
                    }
                    .padding(.top, 40)
                    
                    Spacer()
                }
                
                Spacer()
                
                // Middle Section: Animated Feature Box
                VStack {
                    HStack {
                        Spacer()
                        
                        // Feature Box with sliding animation
                        ZStack {
                            ForEach(0..<features.count, id: \.self) { index in
                                HStack(spacing: 12) {
                                    Image(systemName: features[index].icon)
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundColor(.white)
                                    
                                    Text(features[index].text)
                                        .font(.system(size: 16, weight: .medium, design: .rounded))
                                        .foregroundColor(.white)
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(white: 0.2, opacity: 0.6))
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(.ultraThinMaterial)
                                        )
                                )
                                .offset(x: index == currentFeatureIndex ? 0 : (index < currentFeatureIndex ? -500 : 500))
                                .opacity(index == currentFeatureIndex ? 1 : 0)
                                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: currentFeatureIndex)
                            }
                        }
                        
                        Spacer()
                    }
                    .frame(height: 80)
                    .padding(.horizontal, 20)
                    .clipped()
                    
                    Spacer()
                }
                
                Spacer()
                
                // Bottom Section: Login Form
                VStack(spacing: 20) {
                    if !showOTPView {
                        // Phone Number Input
                        VStack(spacing: 12) {
                            Text("Enter your phone number")
                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            TextField("+91 9876543210", text: $vm.phoneNumber)
                                .textContentType(.telephoneNumber)
                                .keyboardType(.phonePad)
                                .font(.system(size: 16, design: .rounded))
                                .foregroundColor(.black)
                                .padding()
                                .background(Color.white)
                                .cornerRadius(12)
                            
                            if let error = vm.errorMessage {
                                Text(error)
                                    .font(.system(size: 14, design: .rounded))
                                    .foregroundColor(.red.opacity(0.9))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.leading, 4)
                            }
                            
                            Button {
                                Task { 
                                    await vm.sendOTP()
                                    if vm.verificationID != nil {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                            showOTPView = true
                                        }
                                    }
                                }
                            } label: {
                                HStack {
                                    if vm.isLoading {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                    } else {
                                        Text("Send OTP")
                                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 54)
                                .background(vm.isLoading ? Color.gray : Color.white)
                                .foregroundColor(.black)
                                .cornerRadius(12)
                            }
                            .disabled(vm.isLoading || vm.phoneNumber.isEmpty)
                        }
                    } else {
                        // OTP Input
                        VStack(spacing: 12) {
                            Text("Enter OTP")
                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            Text("We've sent a 6-digit code to \(vm.phoneNumber)")
                                .font(.system(size: 14, design: .rounded))
                                .foregroundColor(Color.gray.opacity(0.8))
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            TextField("123456", text: $vm.verificationCode)
                                .keyboardType(.numberPad)
                                .font(.system(size: 24, weight: .semibold, design: .monospaced))
                                .foregroundColor(.black)
                                .multilineTextAlignment(.center)
                                .padding()
                                .background(Color.white)
                                .cornerRadius(12)
                            
                            if let error = vm.errorMessage {
                                Text(error)
                                    .font(.system(size: 14, design: .rounded))
                                    .foregroundColor(.red.opacity(0.9))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.leading, 4)
                            }
                            
                            Button {
                                Task { await vm.confirmCode() }
                            } label: {
                                HStack {
                                    if vm.isLoading {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                    } else {
                                        Text("Verify & Sign In")
                                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 54)
                                .background(vm.isLoading ? Color.gray : Color.white)
                                .foregroundColor(.black)
                                .cornerRadius(12)
                            }
                            .disabled(vm.isLoading || vm.verificationCode.isEmpty)
                            
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    showOTPView = false
                                    vm.verificationCode = ""
                                    vm.errorMessage = nil
                                }
                            } label: {
                                Text("Change phone number")
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundColor(Color.white.opacity(0.8))
                            }
                            .padding(.top, 8)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 40)
                .padding(.bottom, 30)
            }
        }
        .onAppear {
            startFeatureAnimation()
        }
        .onDisappear {
            stopFeatureAnimation()
        }
    }
    
    private func startFeatureAnimation() {
        featureTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { _ in
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                currentFeatureIndex = (currentFeatureIndex + 1) % features.count
            }
        }
    }
    
    private func stopFeatureAnimation() {
        featureTimer?.invalidate()
        featureTimer = nil
    }
}

struct OTPVerifyView: View {
    @ObservedObject var vm: AuthViewModel

    var body: some View {
        PhoneSignInView()
    }
}

// MARK: - Keyboard Dismissal Helper
extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}



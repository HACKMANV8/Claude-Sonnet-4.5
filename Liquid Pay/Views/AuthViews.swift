import SwiftUI

struct PhoneSignInView: View {
    @StateObject private var vm = AuthViewModel()

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                TextField("+91 9876543210", text: $vm.phoneNumber)
                    .textContentType(.telephoneNumber)
                    .keyboardType(.phonePad)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)

                Button {
                    Task { await vm.sendOTP() }
                } label: {
                    Text(vm.isLoading ? "Sending..." : "Send OTP")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .disabled(vm.isLoading)

                if let error = vm.errorMessage {
                    Text(error).foregroundColor(.red)
                }

                if vm.verificationID != nil {
                    NavigationLink("Enter OTP", destination: OTPVerifyView(vm: vm))
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Phone Sign-In")
        }
    }
}

struct OTPVerifyView: View {
    @ObservedObject var vm: AuthViewModel

    var body: some View {
        VStack(spacing: 16) {
            TextField("OTP Code", text: $vm.verificationCode)
                .keyboardType(.numberPad)
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)

            Button {
                Task { await vm.confirmCode() }
            } label: {
                Text(vm.isLoading ? "Verifying..." : "Verify & Sign In")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .disabled(vm.isLoading)

            if let error = vm.errorMessage {
                Text(error).foregroundColor(.red)
            }

            if vm.isSignedIn {
                Text("Signed in!").foregroundColor(.green)
                NavigationLink("Go to Dashboard", destination: DashboardView())
            }

            Spacer()
        }
        .padding()
        .navigationTitle("Verify OTP")
    }
}



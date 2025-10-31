import SwiftUI
import FirebaseAuth

struct SettingsView: View {
    var body: some View {
        Form {
            Section(header: Text("Account")) {
                HStack {
                    Text("Phone")
                    Spacer()
                    Text(Auth.auth().currentUser?.phoneNumber ?? "—").foregroundColor(.secondary)
                }
                Button(role: .destructive) {
                    try? Auth.auth().signOut()
                } label: {
                    Text("Log Out")
                }
            }
            Section(header: Text("About")) {
                HStack {
                    Text("Version")
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("Settings")
    }
}



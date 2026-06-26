import SwiftUI
import FirebaseAuth

struct AccountView: View {
    @Binding var isLoggedIn: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirmation = false

    private let fieldHeight: CGFloat = 42
    private let fieldCornerRadius: CGFloat = 10

    private var email: String {
        guard let user = Auth.auth().currentUser else { return "No email" }
        let raw = user.email ?? user.providerData.compactMap(\.email).first ?? ""
        if raw.hasSuffix("@privaterelay.appleid.com") { return "Apple ID (private email)" }
        return raw.isEmpty ? "No email" : raw
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Email")
                        .font(.footnote)
                        .foregroundColor(.white.opacity(0.7))

                    TextField("", text: .constant(email))
                        .font(.system(size: 17))
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.horizontal, 14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(height: fieldHeight)
                        .background(Color.white.opacity(0.12))
                        .cornerRadius(fieldCornerRadius)
                        .disabled(true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 28)
                .padding(.top, 24)

                Spacer()

                Button { signOut() } label: {
                    Text("Sign Out")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(24)
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 12)

                Button { showDeleteConfirmation = true } label: {
                    Text("Delete Account")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.red.opacity(0.7))
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(24)
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 50)
                .alert("Delete Account", isPresented: $showDeleteConfirmation) {
                    Button("Delete", role: .destructive) { deleteAccount() }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("Are you sure you want to delete your account? This action cannot be undone.")
                }
            }
        }
        .navigationTitle("Account")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.black, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onChange(of: isLoggedIn) { _, loggedIn in
            if !loggedIn { dismiss() }
        }
    }

    private func signOut() {
        try? Auth.auth().signOut()
        isLoggedIn = false
        dismiss()
    }

    private func deleteAccount() {
        Auth.auth().currentUser?.delete { error in
            guard error == nil else { return }
            isLoggedIn = false
            dismiss()
        }
    }
}

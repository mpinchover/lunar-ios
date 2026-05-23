import SwiftUI
import FirebaseAuth

struct AccountOverlayView: View {
    @Binding var isLoggedIn: Bool
    @Binding var isPresented: Bool

    private var email: String {
        Auth.auth().currentUser?.email ?? "No email"
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { isPresented = false }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Color.white.opacity(0.2))
                            .clipShape(Circle())
                    }
                }
                .padding(.bottom, 28)

                Image(systemName: "person.circle.fill")
                    .font(.system(size: 56))
                    .foregroundColor(.white.opacity(0.85))
                    .padding(.bottom, 16)

                Text(email)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.bottom, 36)

                Spacer()

                Button {
                    try? Auth.auth().signOut()
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isLoggedIn = false
                        isPresented = false
                    }
                } label: {
                    Text("Sign Out")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(24)
                }
            }
            .padding(28)
            .background(Color.white.opacity(0.1))
            .cornerRadius(24)
            .padding(.horizontal, 28)
        }
    }
}

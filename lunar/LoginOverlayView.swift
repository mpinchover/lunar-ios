import SwiftUI
import AuthenticationServices

struct LoginOverlayView: View {
    @Binding var isLoggedIn: Bool
    @Binding var isPresented: Bool

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
                .padding(.bottom, 20)

                Text("Sign in to keep watching")
                    .font(.title3.bold())
                    .foregroundColor(.white)
                    .padding(.bottom, 32)

                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    if case .success = result {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isLoggedIn = true
                            isPresented = false
                        }
                    }
                }
                .signInWithAppleButtonStyle(.white)
                .frame(height: 50)
                .cornerRadius(25)
                .padding(.bottom, 12)

                googleSignInButton
            }
            .padding(28)
            .background(Color.white.opacity(0.1))
            .cornerRadius(24)
            .padding(.horizontal, 28)
        }
    }

    private var googleSignInButton: some View {
        Button {
            // Integrate GoogleSignIn SDK for production
            withAnimation(.easeInOut(duration: 0.2)) {
                isLoggedIn = true
                isPresented = false
            }
        } label: {
            HStack(spacing: 10) {
                Text("G")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color(red: 0.26, green: 0.52, blue: 0.96))
                Text("Sign in with Google")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.black)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color.white)
            .cornerRadius(25)
        }
    }
}

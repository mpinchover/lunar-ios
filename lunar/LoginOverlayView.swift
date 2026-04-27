import SwiftUI
import AuthenticationServices
import FirebaseAuth
import GoogleSignIn
import CryptoKit

struct LoginOverlayView: View {
    @Binding var isLoggedIn: Bool
    @Binding var isPresented: Bool

    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage = ""
    @State private var isLoading = false
    @State private var currentNonce: String?

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
                    .padding(.bottom, 28)

                // Apple
                SignInWithAppleButton(.signIn) { request in
                    let nonce = randomNonceString()
                    currentNonce = nonce
                    request.requestedScopes = [.fullName, .email]
                    request.nonce = sha256(nonce)
                } onCompletion: { result in
                    handleAppleResult(result)
                }
                .signInWithAppleButtonStyle(.white)
                .frame(height: 50)
                .cornerRadius(25)
                .padding(.bottom, 12)

                // Google
                Button { signInWithGoogle() } label: {
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
                .padding(.bottom, 24)

                // Divider
                HStack {
                    Rectangle().fill(Color.white.opacity(0.3)).frame(height: 1)
                    Text("or").font(.caption).foregroundColor(.white.opacity(0.5)).padding(.horizontal, 10)
                    Rectangle().fill(Color.white.opacity(0.3)).frame(height: 1)
                }
                .padding(.bottom, 20)

                // Email / password
                VStack(spacing: 10) {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .padding(14)
                        .background(Color.white.opacity(0.12))
                        .cornerRadius(12)
                        .foregroundColor(.white)

                    SecureField("Password", text: $password)
                        .textContentType(.password)
                        .padding(14)
                        .background(Color.white.opacity(0.12))
                        .cornerRadius(12)
                        .foregroundColor(.white)
                }
                .padding(.bottom, 14)

                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 10)
                }

                HStack(spacing: 10) {
                    authButton("Sign In") { signInWithEmail() }
                    authButton("Sign Up") { signUpWithEmail() }
                }
            }
            .padding(28)
            .background(Color.white.opacity(0.1))
            .cornerRadius(24)
            .padding(.horizontal, 28)

            if isLoading {
                Color.black.opacity(0.3).ignoresSafeArea()
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.white)
                    .scaleEffect(1.5)
            }
        }
    }

    private func authButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(Color.white.opacity(0.2))
                .cornerRadius(24)
        }
    }

    // MARK: - Auth

    private func handleAppleResult(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            guard
                let appleCredential = auth.credential as? ASAuthorizationAppleIDCredential,
                let nonce = currentNonce,
                let tokenData = appleCredential.identityToken,
                let token = String(data: tokenData, encoding: .utf8)
            else { return }
            let credential = OAuthProvider.appleCredential(
                withIDToken: token,
                rawNonce: nonce,
                fullName: appleCredential.fullName)
            signIn(with: credential)
        case .failure(let error):
            errorMessage = friendlyError(error)
        }
    }

    private func signInWithGoogle() {
        guard let rootVC = UIApplication.shared.connectedScenes
            .compactMap({ ($0 as? UIWindowScene)?.keyWindow?.rootViewController })
            .first else { return }
        isLoading = true
        GIDSignIn.sharedInstance.signIn(withPresenting: rootVC) { result, error in
            guard let user = result?.user, let idToken = user.idToken?.tokenString, error == nil else {
                errorMessage = error.map { friendlyError($0) } ?? ""
                isLoading = false
                return
            }
            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: user.accessToken.tokenString)
            signIn(with: credential)
        }
    }

    private func signInWithEmail() {
        guard validate() else { return }
        isLoading = true
        Auth.auth().signIn(withEmail: email, password: password) { _, error in
            isLoading = false
            if let error { errorMessage = friendlyError(error); return }
            finish()
        }
    }

    private func signUpWithEmail() {
        guard validate() else { return }
        isLoading = true
        Auth.auth().createUser(withEmail: email, password: password) { _, error in
            isLoading = false
            if let error { errorMessage = friendlyError(error); return }
            finish()
        }
    }

    private func signIn(with credential: AuthCredential) {
        isLoading = true
        Auth.auth().signIn(with: credential) { _, error in
            isLoading = false
            if let error { errorMessage = friendlyError(error); return }
            finish()
        }
    }

    private func finish() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isLoggedIn = true
            isPresented = false
        }
    }

    private func validate() -> Bool {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Please enter your email and password."
            return false
        }
        errorMessage = ""
        return true
    }

    private func friendlyError(_ error: Error) -> String {
        switch AuthErrorCode(rawValue: (error as NSError).code) {
        case .wrongPassword:       return "Incorrect password."
        case .userNotFound:        return "No account found — tap Sign Up."
        case .emailAlreadyInUse:   return "Email already registered — tap Sign In."
        case .weakPassword:        return "Password must be at least 6 characters."
        case .invalidEmail:        return "Please enter a valid email address."
        default:                   return error.localizedDescription
        }
    }

    // MARK: - Nonce (required for Apple + Firebase)

    private func randomNonceString(length: Int = 32) -> String {
        var bytes = [UInt8](repeating: 0, count: length)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(bytes.map { charset[Int($0) % charset.count] })
    }

    private func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8))
            .compactMap { String(format: "%02x", $0) }
            .joined()
    }
}

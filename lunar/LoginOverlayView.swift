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
    @State private var showPasswordEntry = false
    @State private var isCreatingAccount = false

    private let authControlHeight: CGFloat = 42
    private let authControlCornerRadius: CGFloat = 10

    var body: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()
                .onTapGesture { dismissKeyboard() }

            VStack(spacing: 0) {
                HStack {
                    if showPasswordEntry {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showPasswordEntry = false
                                password = ""
                                errorMessage = ""
                            }
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(10)
                                .background(Color.white.opacity(0.2))
                                .clipShape(Circle())
                        }
                    }
                    Spacer()
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { isPresented = false }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(6)
    
                    }
                }
                .padding(.bottom, 20)

                Text(isCreatingAccount ? "Sign up" : "Log in")
                    .font(.title3.bold())
                    .foregroundColor(.white)
                    .padding(.bottom, 28)

                if showPasswordEntry {
                    passwordStep
                } else {
                    emailStep
                }
            }
            .padding(28)
            .background(Color.white.opacity(0.1))
            .cornerRadius(24)
            .padding(.horizontal, 28)
            .onTapGesture { dismissKeyboard() }

            if isLoading {
                Color.black.opacity(0.3).ignoresSafeArea()
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.white)
                    .scaleEffect(1.5)
            }
        }
    }

    private var emailStep: some View {
        Group {
            AuthTextField(
                text: $email,
                placeholder: "email@example.com",
                keyboardType: .emailAddress,
                textContentType: .emailAddress
            )
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity)
                .frame(height: authControlHeight)
                .background(Color.white.opacity(0.12))
                .cornerRadius(authControlCornerRadius)
                .padding(.bottom, 12)

            Button { continueWithEmail() } label: {
                Text("Continue")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: authControlHeight)
                    .background(Color.white)
                    .cornerRadius(authControlCornerRadius)
            }
            .padding(.bottom, 24)


            HStack {
                Rectangle().fill(Color.white.opacity(0.3)).frame(height: 1)
                Text("or").font(.caption).foregroundColor(.white.opacity(0.5)).padding(.horizontal, 10)
                Rectangle().fill(Color.white.opacity(0.3)).frame(height: 1)
            }
            .padding(.bottom, 20)

            SignInWithAppleButton(.signIn) { request in
                let nonce = randomNonceString()
                currentNonce = nonce
                request.requestedScopes = [.fullName, .email]
                request.nonce = sha256(nonce)
            } onCompletion: { result in
                handleAppleResult(result)
            }
            .signInWithAppleButtonStyle(.white)
            .frame(height: authControlHeight)
            .cornerRadius(authControlCornerRadius)
            .padding(.bottom, 12)

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
                .frame(height: authControlHeight)
                .background(Color.white)
                .cornerRadius(authControlCornerRadius)
            }
            .padding(.bottom, 24)

            if isCreatingAccount {
                Button { switchToLogin() } label: {
                    Text("Already have an account")
                        .font(.footnote)
                        .foregroundColor(.white.opacity(0.7))
                }
            } else {
                Button { switchToSignUp() } label: {
                    Text("Create an account")
                        .font(.footnote)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
        }
    }

    private var passwordStep: some View {
        Group {
            Text(verbatim: email)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 12)

            SecureField("Password", text: $password)
                .textContentType(isCreatingAccount ? .newPassword : .password)
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity)
                .frame(height: authControlHeight)
                .background(Color.white.opacity(0.12))
                .cornerRadius(authControlCornerRadius)
                .foregroundColor(.white)
                .padding(.bottom, 14)

            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 10)
            }

            Button {
                if isCreatingAccount {
                    signUpWithEmail()
                } else {
                    signInWithEmail()
                }
            } label: {
                Text(isCreatingAccount ? "Create account" : "Sign in")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: authControlHeight)
                    .background(Color.white)
                    .cornerRadius(authControlCornerRadius)
            }
        }
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }

    private func continueWithEmail() {
        guard validateEmail() else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            showPasswordEntry = true
            password = ""
            errorMessage = ""
        }
    }

    private func switchToSignUp() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isCreatingAccount = true
            errorMessage = ""
        }
    }

    private func switchToLogin() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isCreatingAccount = false
            errorMessage = ""
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
        guard validatePassword() else { return }
        isLoading = true
        Auth.auth().signIn(withEmail: email, password: password) { _, error in
            isLoading = false
            if let error { errorMessage = friendlyError(error); return }
            finish()
        }
    }

    private func signUpWithEmail() {
        guard validatePassword() else { return }
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

    private func validateEmail() -> Bool {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "Please enter your email address."
            return false
        }
        guard trimmed.contains("@"), trimmed.contains(".") else {
            errorMessage = "Please enter a valid email address."
            return false
        }
        email = trimmed
        errorMessage = ""
        return true
    }

    private func validatePassword() -> Bool {
        guard !password.isEmpty else {
            errorMessage = "Please enter your password."
            return false
        }
        errorMessage = ""
        return true
    }

    private func friendlyError(_ error: Error) -> String {
        switch AuthErrorCode(rawValue: (error as NSError).code) {
        case .wrongPassword:       return "Incorrect password."
        case .userNotFound:        return "No account found — create one below."
        case .emailAlreadyInUse:   return "Email already registered — sign in instead."
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

private struct AuthTextField: UIViewRepresentable {
    @Binding var text: String
    let placeholder: String
    var keyboardType: UIKeyboardType = .default
    var textContentType: UITextContentType?

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        field.delegate = context.coordinator
        field.text = text
        field.textColor = .white
        field.tintColor = .white
        field.font = .systemFont(ofSize: 17)
        field.keyboardType = keyboardType
        field.textContentType = textContentType
        field.autocorrectionType = .no
        field.autocapitalizationType = .none
        field.spellCheckingType = .no
        field.borderStyle = .none
        field.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [.foregroundColor: UIColor.white.withAlphaComponent(0.45)]
        )
        field.addTarget(context.coordinator, action: #selector(Coordinator.textDidChange), for: .editingChanged)
        return field
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: AuthTextField

        init(_ parent: AuthTextField) {
            self.parent = parent
        }

        @objc func textDidChange(_ textField: UITextField) {
            parent.text = textField.text ?? ""
        }
    }
}

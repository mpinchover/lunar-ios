import SwiftUI
import AuthenticationServices
import FirebaseAuth
import GoogleSignIn

struct LoginOverlayView: View {
    @Binding var isLoggedIn: Bool
    @Binding var isPresented: Bool

    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var errorMessage = ""
    @State private var isLoading = false
    @State private var appleSignInService = AppleSignInService()
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

                Group {
                    if showPasswordEntry {
                        if isCreatingAccount {
                            signUpPasswordStep
                        } else {
                            loginPasswordStep
                        }
                    } else {
                        emailStep
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
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
        .onAppear(perform: configureAppleSignIn)
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

            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 10)
            }

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

            SignInWithAppleButton(
                isCreatingAccount ? .signUp : .signIn,
                onRequest: { request in
                    errorMessage = ""
                    appleSignInService.configure(request)
                },
                onCompletion: { result in
                    isLoading = true
                    appleSignInService.handle(result)
                }
            )
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

    private var loginPasswordStep: some View {
        Group {
            Text(verbatim: email)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 12)

            passwordField(placeholder: "password", text: $password, contentType: .password)
                .padding(.bottom, 14)

            if !errorMessage.isEmpty {
                authErrorMessage
            }

            Button { signInWithEmail() } label: {
                Text("Submit")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: authControlHeight)
                    .background(Color.white)
                    .cornerRadius(authControlCornerRadius)
            }
            .padding(.bottom, 24)

            passwordBackButton
        }
    }

    private var signUpPasswordStep: some View {
        Group {
            Text(verbatim: email)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 12)

            passwordField(placeholder: "password", text: $password, contentType: .newPassword)
                .padding(.bottom, 12)

            passwordField(placeholder: "confirm password", text: $confirmPassword, contentType: .newPassword)
                .padding(.bottom, 14)

            if !errorMessage.isEmpty {
                authErrorMessage
            }

            Button { signUpWithEmail() } label: {
                Text("Create account")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: authControlHeight)
                    .background(Color.white)
                    .cornerRadius(authControlCornerRadius)
            }
            .padding(.bottom, 24)

            passwordBackButton
        }
    }

    private var passwordBackButton: some View {
        Button { goBackFromPassword() } label: {
            Text("Back")
                .font(.footnote)
                .foregroundColor(.white.opacity(0.7))
        }
    }

    private var authErrorMessage: some View {
        Text(errorMessage)
            .font(.caption)
            .foregroundColor(.red.opacity(0.9))
            .multilineTextAlignment(.center)
            .padding(.bottom, 10)
    }

    private func passwordField(
        placeholder: String,
        text: Binding<String>,
        contentType: UITextContentType
    ) -> some View {
        AuthTextField(
            text: text,
            placeholder: placeholder,
            textContentType: contentType,
            isSecure: true
        )
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity)
        .frame(height: authControlHeight)
        .background(Color.white.opacity(0.12))
        .cornerRadius(authControlCornerRadius)
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
        dismissKeyboard()
        withAnimation(.easeInOut(duration: 0.2)) {
            showPasswordEntry = true
            password = ""
            confirmPassword = ""
            errorMessage = ""
        }
    }

    private func goBackFromPassword() {
        dismissKeyboard()
        withAnimation(.easeInOut(duration: 0.2)) {
            showPasswordEntry = false
            password = ""
            confirmPassword = ""
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

    private func configureAppleSignIn() {
        appleSignInService.onCredential = { credential in
            signIn(with: credential)
        }
        appleSignInService.onFailure = { message in
            isLoading = false
            errorMessage = message
        }
        appleSignInService.onCancel = {
            isLoading = false
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
        guard validateSignUpPasswords() else { return }
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

    private func validateSignUpPasswords() -> Bool {
        guard !password.isEmpty else {
            errorMessage = "Please enter a password."
            return false
        }
        guard password.count >= 6 else {
            errorMessage = "Password must be at least 6 characters."
            return false
        }
        guard !confirmPassword.isEmpty else {
            errorMessage = "Please confirm your password."
            return false
        }
        guard password == confirmPassword else {
            errorMessage = "Passwords do not match."
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
        case .operationNotAllowed: return "Apple sign-in is not enabled for this app."
        case .invalidCredential:   return "Apple sign-in failed. Please try again."
        default:                   return error.localizedDescription
        }
    }
}

private struct AuthTextField: UIViewRepresentable {
    @Binding var text: String
    let placeholder: String
    var keyboardType: UIKeyboardType = .default
    var textContentType: UITextContentType?
    var isSecure: Bool = false

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        field.delegate = context.coordinator
        field.text = text
        field.textColor = .white
        field.tintColor = .white
        field.font = .systemFont(ofSize: 17)
        field.keyboardType = keyboardType
        field.textContentType = textContentType
        field.isSecureTextEntry = isSecure
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

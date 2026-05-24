import AuthenticationServices
import CryptoKit
import FirebaseAuth

@MainActor
final class AppleSignInService {
    var onCredential: ((AuthCredential) -> Void)?
    var onFailure: ((String) -> Void)?
    var onCancel: (() -> Void)?

    private var currentNonce: String?

    func configure(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = randomNonceString()
        currentNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
    }

    func handle(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let appleCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                onFailure?("Unable to read Apple ID credentials.")
                return
            }
            guard let nonce = currentNonce else {
                onFailure?("Invalid sign-in state. Please try again.")
                return
            }
            guard let tokenData = appleCredential.identityToken,
                  let idToken = String(data: tokenData, encoding: .utf8) else {
                onFailure?("Unable to fetch identity token.")
                return
            }

            currentNonce = nil
            let credential = OAuthProvider.appleCredential(
                withIDToken: idToken,
                rawNonce: nonce,
                fullName: appleCredential.fullName
            )
            onCredential?(credential)

        case .failure(let error):
            currentNonce = nil
            if let authError = error as? ASAuthorizationError, authError.code == .canceled {
                onCancel?()
                return
            }
            onFailure?(error.localizedDescription)
        }
    }

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

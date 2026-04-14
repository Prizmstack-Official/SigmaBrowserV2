//
//  PasskeyManager.swift
//  Nook
//
//  Manages passkey (WebAuthn) authorization state for the browser.
//  WKWebView handles WebAuthn challenges automatically once the user
//  grants the browser access to platform credentials via the system prompt.
//

import AppKit
import AuthenticationServices
import Foundation
#if canImport(Security)
import Security
#endif

/// Authorization states the browser can be in relative to passkey access.
enum PasskeyAuthorizationState: String {
    case authorized
    case denied
    case missingEntitlement
    case notDetermined
    case unavailable
}

@MainActor
final class PasskeyManager: NSObject, ObservableObject {

    @Published private(set) var authorizationState: PasskeyAuthorizationState = .notDetermined

    private weak var browserManager: BrowserManager?

    /// System credential manager — nil when the API isn't available.
    private let credentialManager: ASAuthorizationWebBrowserPublicKeyCredentialManager?

    override init() {
        if #available(macOS 13.3, *) {
            self.credentialManager = ASAuthorizationWebBrowserPublicKeyCredentialManager()
        } else {
            self.credentialManager = nil
        }
        super.init()
        refreshAuthorizationState()
    }

    // MARK: - BrowserManager Attachment

    func attach(browserManager: BrowserManager) {
        self.browserManager = browserManager
    }

    // MARK: - Authorization

    /// Re-reads the current authorization state from the system.
    func refreshAuthorizationState() {
        guard let manager = credentialManager else {
            authorizationState = .unavailable
            return
        }

        guard hasBrowserPublicKeyCredentialEntitlement else {
            authorizationState = .missingEntitlement
            return
        }

        if #available(macOS 13.3, *) {
            switch manager.authorizationStateForPlatformCredentials {
            case .authorized:
                authorizationState = .authorized
            case .denied:
                authorizationState = .denied
            case .notDetermined:
                authorizationState = .notDetermined
            @unknown default:
                authorizationState = .notDetermined
            }
        }
    }

    /// Requests passkey authorization from the user if not yet determined.
    /// Returns the resulting state after the request completes.
    @discardableResult
    func requestAuthorizationIfNeeded() async -> PasskeyAuthorizationState {
        guard let manager = credentialManager else { return .unavailable }

        refreshAuthorizationState()
        guard authorizationState == .notDetermined else { return authorizationState }

        if #available(macOS 13.3, *) {
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                manager.requestAuthorizationForPublicKeyCredentials { _ in
                    continuation.resume()
                }
            }
        }

        refreshAuthorizationState()
        return authorizationState
    }

    private var hasBrowserPublicKeyCredentialEntitlement: Bool {
        #if canImport(Security)
        let entitlement = "com.apple.developer.web-browser.public-key-credential" as CFString
        guard let task = SecTaskCreateFromSelf(nil) else { return false }
        return (SecTaskCopyValueForEntitlement(task, entitlement, nil) as? Bool) == true
        #else
        return false
        #endif
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding

extension PasskeyManager: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        // Prefer the key (focused) window; fall back to any visible window.
        NSApp.keyWindow ?? NSApp.windows.first(where: { $0.isVisible }) ?? NSApp.mainWindow ?? ASPresentationAnchor()
    }
}

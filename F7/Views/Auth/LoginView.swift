import SwiftUI
import WebKit

/// F1TV login screen using an in-app WebView for real F1 authentication.
/// The user logs in through the actual F1 website, which handles anti-bot protection naturally.
public struct LoginView: View {
    @Environment(AuthViewModel.self) private var authVM
    
    @State private var showWebLogin = false
    @State private var authManager: F1TVAuthManager?
    
    public var body: some View {
        if showWebLogin, let manager = authManager {
            webLoginView(manager: manager)
        } else {
            landingView
        }
    }
    
    // MARK: - WebView Login
    
    private func webLoginView(manager: F1TVAuthManager) -> some View {
        // Use a UIKit-backed full-screen container to avoid all SwiftUI safe area issues
        F1LoginWebViewContainer(
            webView: manager.webView,
            onCancel: {
                showWebLogin = false
                authManager?.cleanup()
                authManager = nil
            }
        )
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Landing Screen
    
    private var landingView: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 32) {
                Spacer()
                
                VStack(spacing: 12) {
                    Image(systemName: "flag.checkered")
                        .font(.system(size: 48))
                        .foregroundColor(.red)
                    
                    Text("ARGON F7")
                        .font(.system(.largeTitle, design: .default, weight: .black))
                        .foregroundColor(.white)
                    
                    Text("Watch F1TV live races and replays")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                if let error = authVM.errorMessage {
                    HStack {
                        Image(systemName: "exclamationmark.circle.fill")
                        Text(error)
                    }
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal, 24)
                }
                
                if authVM.isLoading {
                    VStack(spacing: 8) {
                        ProgressView()
                            .tint(.red)
                        Text("Authenticating...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Button {
                    startWebLogin()
                } label: {
                    Text("SIGN IN WITH F1TV")
                        .font(.system(.headline, design: .default, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .disabled(authVM.isLoading)
                .padding(.horizontal, 24)
                
                Spacer()
                
                Text("Requires an active F1TV Pro subscription")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 16)
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Actions
    
    private func startWebLogin() {
        let manager = F1TVAuthManager()
        
        manager.onTokenExtracted = { token, cookieHeader in
            print("[LoginView] Token extracted from web login (length: \(token.count)); cookie header length: \(cookieHeader?.count ?? 0)")
            showWebLogin = false
            authVM.loginWithToken(token, cookieHeader: cookieHeader)
            self.authManager?.cleanup()
            self.authManager = nil
        }
        
        manager.onError = { error in
            authVM.errorMessage = error
            showWebLogin = false
            self.authManager?.cleanup()
            self.authManager = nil
        }
        
        self.authManager = manager
        self.showWebLogin = true
        manager.loadLoginPage()
    }
}

// MARK: - UIKit-based full-screen WebView container

/// Uses UIKit directly to avoid SwiftUI safe area layout issues.
/// Places a thin header bar at the top (respecting status bar) and the WebView below it,
/// both managed via Auto Layout for pixel-perfect control.
struct F1LoginWebViewContainer: UIViewControllerRepresentable {
    let webView: WKWebView
    let onCancel: () -> Void
    
    func makeUIViewController(context: Context) -> F1LoginWebViewController {
        let vc = F1LoginWebViewController()
        vc.webView = webView
        vc.onCancel = onCancel
        return vc
    }
    
    func updateUIViewController(_ uiViewController: F1LoginWebViewController, context: Context) {}
}

final class F1LoginWebViewController: UIViewController {
    var webView: WKWebView!
    var onCancel: (() -> Void)?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        
        // Header bar
        let headerBar = UIView()
        headerBar.backgroundColor = UIColor(white: 0.06, alpha: 1)
        headerBar.translatesAutoresizingMaskIntoConstraints = false
        
        let cancelButton = UIButton(type: .system)
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.setTitleColor(.systemRed, for: .normal)
        cancelButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .medium)
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = UILabel()
        titleLabel.text = "Sign in to F1TV"
        titleLabel.textColor = .white
        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        headerBar.addSubview(cancelButton)
        headerBar.addSubview(titleLabel)
        
        // WebView setup
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black
        
        view.addSubview(headerBar)
        view.addSubview(webView)
        
        NSLayoutConstraint.activate([
            // Header bar: top to safe area, full width, fixed content height
            headerBar.topAnchor.constraint(equalTo: view.topAnchor),
            headerBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            
            // Cancel button inside header bar
            cancelButton.leadingAnchor.constraint(equalTo: headerBar.leadingAnchor, constant: 16),
            cancelButton.bottomAnchor.constraint(equalTo: headerBar.bottomAnchor, constant: -10),
            
            // Title centered in header bar
            titleLabel.centerXAnchor.constraint(equalTo: headerBar.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: cancelButton.centerYAnchor),
            
            // Header bar bottom = safe area top + button height + padding
            headerBar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 40),
            
            // WebView: directly below header bar, extends to all edges
            webView.topAnchor.constraint(equalTo: headerBar.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }
    
    @objc private func cancelTapped() {
        onCancel?()
    }
}

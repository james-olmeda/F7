import SwiftUI
import CoreText

@main
struct ArgonF7App: App {
    
    @State private var telemetryViewModel = TelemetryViewModel()
    @State private var authViewModel: AuthViewModel
    @State private var contentBrowserViewModel: ContentBrowserViewModel
    @State private var videoPlayerViewModel: VideoPlayerViewModel
    @State private var standingsViewModel = StandingsViewModel()
    @State private var newsViewModel = F1NewsViewModel()
    
    init() {
        Self.registerInterFonts()

        // Create the content service with a session provider
        let authenticator = F1TVAPIAuthenticator()
        let authVM = AuthViewModel(authenticator: authenticator)
        
        let contentService = F1TVContentService { [authVM] in
            authVM.currentSession
        }
        
        _authViewModel = State(initialValue: authVM)
        _contentBrowserViewModel = State(initialValue: ContentBrowserViewModel(contentService: contentService))
        _videoPlayerViewModel = State(initialValue: VideoPlayerViewModel(contentService: contentService))
        
        setupDependencies()
    }
    
    var body: some Scene {
        WindowGroup {
            Group {
                if authViewModel.isAuthenticated {
                    RaceDashboardView()
                        .environment(telemetryViewModel)
                        .environment(authViewModel)
                        .environment(contentBrowserViewModel)
                        .environment(videoPlayerViewModel)
                        .environment(standingsViewModel)
                        .environment(newsViewModel)
                } else {
                    LoginView()
                        .environment(authViewModel)
                }
            }
            .environment(\.font, .inter(size: 16))
        }
    }
    
    private func setupDependencies() {
        print("[ArgonF7App] Setting up Core Dependencies...")
    }

    private static func registerInterFonts() {
        guard let fontURLs = Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: "Fonts") else {
            return
        }

        for url in fontURLs {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}

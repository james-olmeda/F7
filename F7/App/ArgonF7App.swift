import SwiftUI

@main
struct ArgonF7App: App {
    
    @State private var telemetryViewModel = TelemetryViewModel()
    @State private var authViewModel: AuthViewModel
    @State private var contentBrowserViewModel: ContentBrowserViewModel
    @State private var videoPlayerViewModel: VideoPlayerViewModel
    @State private var standingsViewModel = StandingsViewModel()
    @State private var newsViewModel = F1NewsViewModel()
    
    init() {
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
    }
    
    private func setupDependencies() {
        print("[ArgonF7App] Setting up Core Dependencies...")
    }
}


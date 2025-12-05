import SwiftUI
import UIKit

struct RootView: View {
    @EnvironmentObject private var gatekeeper: Gatekeeper

    var body: some View {
        Group {
            switch gatekeeper.route {
            case .loading:
                Color(uiColor: .systemGray5)
                    .ignoresSafeArea()
                    .overlay(
                        ProgressView()
                            .tint(.gray)
                    )
            case .web(let url):
                WebContainerView(url: url)
            case .native:
                ContentView()
            }
        }
        .onAppear {
            gatekeeper.start()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            Task {
                await gatekeeper.refreshConfig()
            }
        }
    }
}

import SwiftUI
import UIKit
import Combine

struct RootView: View {
    @EnvironmentObject private var gatekeeper: Gatekeeper

    var body: some View {
        Group {
            switch gatekeeper.route {
            case .loading:
                LoadingView()
                    .environmentObject(gatekeeper)
            case .notificationPrompt(let url):
                NotificationPromptView(url: url)
                    .environmentObject(gatekeeper)
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


private struct LoadingView: View {
    @EnvironmentObject private var gatekeeper: Gatekeeper
    @State private var dotCount: Int = 1
    private let dotTimer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack(alignment: .center) {
            Image("loadingbg")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            LinearGradient(
                colors: [Color.black.opacity(0.55), Color.black.opacity(0.1)],
                startPoint: .bottom,
                endPoint: .center
            )
            .ignoresSafeArea()

            if gatekeeper.loadingError {
                VStack(spacing: 26) {
                    Spacer(minLength: 80)

                    ZStack {
                        Image("notifybg")
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 340)
                        Text("PLEASE, CHECK YOUR INTERNET CONNECTION AND RESTART")
                            .font(.system(size: 18, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .lineSpacing(8)
                            .padding(.horizontal, 52)
                            .padding(.vertical, 36)
                    }

                    Button {
                        gatekeeper.restart()
                    } label: {
                        Image("back")
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 180)
                            .shadow(color: Color.black.opacity(0.35), radius: 6, x: 0, y: 4)
                    }

                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .padding(.horizontal, 24)
                .padding(.bottom, 30)
            } else {
                VStack {
                    Spacer()
                    Text("LOADING\(String(repeating: ".", count: dotCount))")
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: Color.black.opacity(0.35), radius: 6, x: 0, y: 2)
                        .padding(.bottom, 44)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onReceive(dotTimer) { _ in
            withAnimation(.easeInOut(duration: 0.25)) {
                dotCount = dotCount % 3 + 1
            }
        }
    }
}

private struct NotificationPromptView: View {
    @EnvironmentObject private var gatekeeper: Gatekeeper
    let url: URL

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Image("loadingbg")
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .ignoresSafeArea()
            }
            .overlay(alignment: .bottom) {
                ZStack(alignment: .bottom) {
                    Image("mask")
                        .resizable()
                        .scaledToFill()
                        .frame(
                            width: proxy.size.width,
                            height: proxy.size.height * 0.8 + proxy.safeAreaInsets.bottom - 40
                        )
                        .offset(y: 40)
                        .ignoresSafeArea()

                    VStack(spacing: 16) {
                        Text("ALLOW NOTIFICATIONS ABOUT BONUSES AND PROMOS")
                            .font(.system(size: 22, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .lineSpacing(6)
                            .padding(.horizontal, 24)

                        Text("STAY TUNED WITH BEST OFFERS FROM OUR CASINO")
                            .font(.system(size: 16, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .padding(.horizontal, 30)

                        Button {
                            gatekeeper.openWebAfterNotificationPrompt(url: url, requestPermission: true)
                        } label: {
                            Image("yes")
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: 240)
                                .shadow(color: Color.black.opacity(0.35), radius: 6, x: 0, y: 4)
                        }
                        .padding(.top, 12)

                        Button {
                            gatekeeper.openWebAfterNotificationPrompt(url: url, requestPermission: false)
                        } label: {
                            Text("SKIP")
                                .font(.system(size: 15, weight: .heavy, design: .rounded))
                                .foregroundColor(.white.opacity(0.9))
                                .padding(.top, 6)
                        }
                        .padding(.bottom, 16 + proxy.safeAreaInsets.bottom)
                    }
                    .padding(.horizontal, 24)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .ignoresSafeArea()
            }
        }
        .ignoresSafeArea()
    }
}

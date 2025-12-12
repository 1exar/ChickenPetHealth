import SwiftUI
import WebKit

struct WebContainerView: View {
    let url: URL

    var body: some View {
        WebView(url: url)
            .ignoresSafeArea()
    }
}

private struct WebView: UIViewRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator {
        Coordinator(rootURL: url)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.navigationDelegate = context.coordinator
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        if uiView.url != url {
            uiView.load(URLRequest(url: url))
        }
    }

}

private final class Coordinator: NSObject, WKNavigationDelegate {
    private let redirectResolver = RedirectResolver()
    private let rootURL: URL
    private var lastMainFrameURL: URL?
    private var isResolvingRedirect = false

    init(rootURL: URL) {
        self.rootURL = rootURL
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if navigationAction.targetFrame?.isMainFrame == true, let url = navigationAction.request.url {
            lastMainFrameURL = url
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        handleTooManyRedirectsIfNeeded(for: webView, error: error)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        handleTooManyRedirectsIfNeeded(for: webView, error: error)
    }

    private func handleTooManyRedirectsIfNeeded(for webView: WKWebView, error: Error) {
        guard let urlError = error as? URLError, urlError.code == .httpTooManyRedirects else { return }
        guard isResolvingRedirect == false else { return }

        // WKWebView stops after ~20 redirects; resolve the chain manually and reload.
        let fallbackURL = lastMainFrameURL ?? webView.url ?? rootURL
        isResolvingRedirect = true

        Task {
            let resolvedURL = await redirectResolver.resolve(url: fallbackURL)
            await MainActor.run {
                isResolvingRedirect = false
                guard let resolvedURL else { return }
                var request = URLRequest(url: resolvedURL)
                request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
                webView.load(request)
            }
        }
    }
}

private final class RedirectResolver: NSObject, URLSessionTaskDelegate {
    private lazy var session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.waitsForConnectivity = false
        return URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }()

    func resolve(url: URL, maxRedirects: Int = 80) async -> URL? {
        var currentURL = url

        for _ in 0..<maxRedirects {
            var request = URLRequest(url: currentURL)
            request.httpMethod = "HEAD"
            request.timeoutInterval = 8

            do {
                let (_, response) = try await session.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse else { return currentURL }

                guard (300..<400).contains(httpResponse.statusCode),
                      let location = httpResponse.value(forHTTPHeaderField: "Location"),
                      let nextURL = URL(string: location, relativeTo: currentURL)?.absoluteURL else {
                    return currentURL
                }

                currentURL = nextURL
            } catch {
                return currentURL
            }
        }

        return currentURL
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}

import SwiftUI
@preconcurrency import WebKit
import UIKit
import UniformTypeIdentifiers

struct WebContainerView: View {
    let url: URL

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            WebView(url: url)
        }
    }
}

private struct WebView: UIViewRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator {
        Coordinator(rootURL: url)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        let userContentController = WKUserContentController()
        let preferences = WKWebpagePreferences()
        preferences.preferredContentMode = .mobile
        configuration.defaultWebpagePreferences = preferences
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = .all

        // Prevent zooming when keyboard appears by locking viewport scale.
        let viewportScript = """
        (function() {
            var meta = document.querySelector('meta[name=viewport]');
            if (!meta) {
                meta = document.createElement('meta');
                meta.name = 'viewport';
                document.head.appendChild(meta);
            }
            meta.setAttribute('content', 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no');
        })();
        """
        let script = WKUserScript(source: viewportScript, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        userContentController.addUserScript(script)
        configuration.userContentController = userContentController

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.contentInsetAdjustmentBehavior = .automatic
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.scrollView.pinchGestureRecognizer?.isEnabled = false
        context.coordinator.attach(webView)
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        if uiView.url != url {
            uiView.load(URLRequest(url: url))
        }
    }

}

private final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, UIDocumentPickerDelegate {
    private let redirectResolver = RedirectResolver()
    private let rootURL: URL
    private var lastMainFrameURL: URL?
    private var isResolvingRedirect = false
    private weak var webView: WKWebView?
    private var orientationObserver: NSObjectProtocol?
    private var filePickerCompletion: (([URL]?) -> Void)?

    init(rootURL: URL) {
        self.rootURL = rootURL
    }

    deinit {
        if let orientationObserver {
            NotificationCenter.default.removeObserver(orientationObserver)
        }
    }

    func attach(_ webView: WKWebView) {
        self.webView = webView
        resetZoom()
        updateSafeAreaInsets()

        orientationObserver = NotificationCenter.default.addObserver(
            forName: UIDevice.orientationDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.resetZoom()
            self?.updateSafeAreaInsets()
        }
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let url = navigationAction.request.url, shouldOpenExternally(url) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
            decisionHandler(.cancel)
            return
        }

        if navigationAction.targetFrame?.isMainFrame == true, let url = navigationAction.request.url {
            lastMainFrameURL = url
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        resetZoom()
        updateSafeAreaInsets()
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        handleTooManyRedirectsIfNeeded(for: webView, error: error)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        handleTooManyRedirectsIfNeeded(for: webView, error: error)
    }

    // Handle target=_blank and new window requests by loading them in the current web view.
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        guard navigationAction.targetFrame == nil else { return nil }
        webView.load(navigationAction.request)
        return nil
    }

    @objc
    func webView(_ webView: WKWebView, runOpenPanelWith parameters: Any, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping ([URL]?) -> Void) {
        guard #available(iOS 14.0, *) else {
            completionHandler(nil)
            return
        }
        guard let presenter = presentingViewController else {
            completionHandler(nil)
            return
        }

        filePickerCompletion = completionHandler

        let allowsMultiple = (parameters as AnyObject).value(forKey: "allowsMultipleSelection") as? Bool ?? false
        let contentTypes: [UTType] = [.image, .movie, .item]

        let picker = UIDocumentPickerViewController(forOpeningContentTypes: contentTypes, asCopy: true)
        picker.allowsMultipleSelection = allowsMultiple
        picker.delegate = self
        presenter.present(picker, animated: true)
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

    private func resetZoom() {
        guard let webView else { return }

        let scrollView = webView.scrollView
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 1.0
        scrollView.bouncesZoom = false
        if scrollView.zoomScale != 1.0 {
            scrollView.setZoomScale(1.0, animated: false)
        }

        if webView.pageZoom != 1.0 {
            webView.pageZoom = 1.0
        }
    }

    private func updateSafeAreaInsets() {
        guard let webView else { return }
        let insets = keyWindow?.safeAreaInsets ?? webView.safeAreaInsets
        webView.scrollView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: insets.bottom, right: 0)
        webView.scrollView.scrollIndicatorInsets = UIEdgeInsets(top: insets.top, left: 0, bottom: insets.bottom, right: 0)
    }

    private func shouldOpenExternally(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else { return false }
        if ["http", "https", "about", "file", "data"].contains(scheme) { return false }
        return true
    }

    private var presentingViewController: UIViewController? {
        guard var controller = keyWindow?.rootViewController else { return nil }
        while let presented = controller.presentedViewController {
            controller = presented
        }
        return controller
    }

    private var keyWindow: UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        filePickerCompletion?(urls)
        filePickerCompletion = nil
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        filePickerCompletion?(nil)
        filePickerCompletion = nil
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

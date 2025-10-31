import SwiftUI
import WebKit
import FirebaseAuth

struct GamesWebView: UIViewRepresentable {
    let urlString: String
    let entryFee: Int
    let gameName: String
    var onRequestEntry: (() -> Void)?
    var onResult: ((Bool) -> Void)?
    
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.userContentController.add(context.coordinator, name: "lpGame")
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.isOpaque = false
        webView.backgroundColor = .clear
        if urlString.lowercased().hasPrefix("demo:") {
            let kind = urlString.replacingOccurrences(of: "demo:", with: "").lowercased()
            webView.loadHTMLString(Self.demoHTML(kind: kind), baseURL: nil)
        } else if let url = URL(string: urlString) {
            webView.load(URLRequest(url: url))
        } else {
            webView.loadHTMLString("<html><body style='font-family:-apple-system;background:#0b0e14;color:#fff;display:flex;align-items:center;justify-content:center;height:100vh'>Game Unavailable</body></html>", baseURL: nil)
        }
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {}
    
    class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        let parent: GamesWebView
        init(_ parent: GamesWebView) { self.parent = parent }
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "lpGame" else { return }
            guard let body = message.body as? [String: Any], let type = body["type"] as? String else { return }
            switch type {
            case "ready":
                injectBootstrap(into: (message.webView))
            case "requestEntry":
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                parent.onRequestEntry?()
            case "result":
                if let payload = body["payload"] as? [String: Any], let win = payload["win"] as? Bool {
                    UINotificationFeedbackGenerator().notificationOccurred(win ? .success : .warning)
                    parent.onResult?(win)
                }
            default:
                break
            }
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            injectBootstrap(into: webView)
        }
        
        private func injectBootstrap(into webView: WKWebView?) {
            guard let webView = webView else { return }
            let uid = Auth.auth().currentUser?.uid ?? "anon"
            let js = "window.__LP = { entryFee: \(parent.entryFee), game: '\(parent.gameName)', userId: '\(uid)' }"
            webView.evaluateJavaScript(js, completionHandler: nil)
        }
    }
}

// MARK: - Demo HTML Games
extension GamesWebView {
    static func demoHTML(kind: String) -> String {
        let title: String
        switch kind {
        case "scratch": title = "Scratch Card"
        case "spin": title = "Spin Wheel"
        case "ttt", "tic-tac-toe": title = "Tic‑Tac‑Toe"
        default: title = "Mini Game"
        }
        return """
<!doctype html>
<html><head><meta name='viewport' content='width=device-width, initial-scale=1'>
<style>
  body{margin:0;background:#0b0e14;color:#fff;font-family:-apple-system,system-ui;display:flex;align-items:center;justify-content:center;height:100vh}
  .card{background:#121826;border:1px solid #1f2937;border-radius:16px;padding:24px;width:90%;max-width:420px;text-align:center}
  button{background:#4c6ef5;color:#fff;border:0;border-radius:12px;padding:12px 16px;font-size:16px;margin-top:12px}
  button:disabled{background:#4b5563}
  .muted{color:#9ca3af;font-size:13px}
  .title{font-size:20px;font-weight:700;margin-bottom:8px}
  .result{font-size:18px;margin-top:12px}
  .win{color:#22c55e}.lose{color:#f43f5e}
  .badge{display:inline-block;background:#111827;border:1px solid #1f2937;border-radius:999px;padding:4px 10px;margin-top:8px;color:#9ca3af;font-size:12px}
  .sep{height:1px;background:#1f2937;margin:16px 0}
</style></head>
<body>
  <div class='card'>
    <div class='title'>\(title)</div>
    <div class='muted'>Entry fee will be charged when you start.</div>
    <div class='badge' id='fee'>Loading fee…</div>
    <div class='sep'></div>
    <button id='start'>Start Game</button>
    <button id='play' disabled>Play</button>
    <div id='msg' class='result'></div>
  </div>
  <script>
    // iOS bootstrap
    const bridge = window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.lpGame;
    function post(obj){ bridge && bridge.postMessage(obj) }
    post({ type: 'ready' });
    // Poll for bootstrap injected by iOS
    const feeEl = document.getElementById('fee');
    const startBtn = document.getElementById('start');
    const playBtn = document.getElementById('play');
    const msg = document.getElementById('msg');
    function updateFee(){
      if (window.__LP && window.__LP.entryFee != null){ feeEl.textContent = `Entry: ${window.__LP.entryFee} coins`; }
    }
    updateFee(); setInterval(updateFee, 300);
    startBtn.addEventListener('click', ()=>{ post({ type: 'requestEntry' }); startBtn.disabled = true; playBtn.disabled = false; msg.textContent = 'Entry charged. Ready!'; msg.className = 'result'; });
    playBtn.addEventListener('click', ()=>{ playBtn.disabled = true; msg.textContent = 'Playing…'; setTimeout(()=>{ const win = Math.random() < 0.5; post({ type: 'result', payload: { win } }); msg.textContent = win ? '+50 coins!' : 'Better luck next time'; msg.className = 'result ' + (win ? 'win':'lose'); }, 800); });
  </script>
</body></html>
"""
    }
}



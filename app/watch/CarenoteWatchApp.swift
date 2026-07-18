import SwiftUI
import WatchConnectivity

// CARENOTE Apple Watch 앱 (v1) — 입력 위주(물·복약)
// (통신 관리자 WatchConn 을 같은 파일에 포함해 파일 2개만으로 구성)
@main
struct CarenoteWatchApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

/// 워치 → 아이폰 전송 관리자.
/// 폰이 가까우면 즉시(sendMessage), 아니면 큐(transferUserInfo)로 전달.
final class WatchConn: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchConn()

    override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    func send(_ payload: [String: Any]) {
        guard WCSession.isSupported() else { return }
        let s = WCSession.default
        if s.isReachable {
            s.sendMessage(payload, replyHandler: nil, errorHandler: { _ in
                s.transferUserInfo(payload)
            })
        } else {
            s.transferUserInfo(payload)
        }
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}
}

import SwiftUI
import Combine
import WatchConnectivity

// CARENOTE Apple Watch 앱 (v2) — 복약 하나씩 체크 · 물 · 걷기/뛰기
// (통신 관리자 WatchConn + 상태 WatchState 를 같은 파일에 포함)
@main
struct CarenoteWatchApp: App {
    @StateObject private var state = WatchState.shared
    init() { _ = WatchConn.shared }   // 세션 활성화
    var body: some Scene {
        WindowGroup {
            ContentView().environmentObject(state)
        }
    }
}

/// 폰에서 받은 오늘 복약 목록 등 상태.
final class WatchState: ObservableObject {
    static let shared = WatchState()
    @Published var meds: [[String: String]] = []   // [{ id, name, taken:"1"/"" }]
}

/// 워치 ↔ 아이폰 통신 관리자.
final class WatchConn: NSObject, WCSessionDelegate {
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

    private func apply(_ ctx: [String: Any]) {
        if let meds = ctx["meds"] as? [[String: String]] {
            DispatchQueue.main.async { WatchState.shared.meds = meds }
        }
    }

    func session(_ s: WCSession, activationDidCompleteWith st: WCSessionActivationState, error: Error?) {
        apply(s.receivedApplicationContext)
    }
    func session(_ s: WCSession, didReceiveApplicationContext ctx: [String: Any]) { apply(ctx) }
}

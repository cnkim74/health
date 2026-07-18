import Foundation
import WatchConnectivity

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
                s.transferUserInfo(payload)   // 실패 시 큐로 폴백
            })
        } else {
            s.transferUserInfo(payload)        // 폰이 꺼져 있어도 다음 실행 때 전달
        }
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}
}

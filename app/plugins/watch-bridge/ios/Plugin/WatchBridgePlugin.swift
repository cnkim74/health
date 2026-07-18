import Foundation
import Capacitor
import WatchConnectivity

/**
 * CARENOTE 애플워치 브리지 (iPhone 측)
 * 워치에서 보낸 입력(물·복약 등)을 받아 JS로 전달('watchAction' 이벤트).
 * 폰이 꺼져 있어도 transferUserInfo 로 큐잉되어 다음 실행 시 전달됩니다.
 */
@objc(WatchBridgePlugin)
public class WatchBridgePlugin: CAPPlugin, WCSessionDelegate {

    override public func load() {
        if WCSession.isSupported() {
            let s = WCSession.default
            s.delegate = self
            s.activate()
        }
    }

    // 워치 연결(도달 가능) 여부
    @objc func isReachable(_ call: CAPPluginCall) {
        let ok = WCSession.isSupported() ? WCSession.default.isReachable : false
        call.resolve(["reachable": ok])
    }

    // 폰 → 워치로 상태 전달(옵션): { context: { ... } }
    @objc func updateContext(_ call: CAPPluginCall) {
        guard WCSession.isSupported() else { call.resolve(); return }
        let ctx = call.getObject("context") ?? [:]
        do { try WCSession.default.updateApplicationContext(ctx); call.resolve() }
        catch { call.reject(error.localizedDescription) }
    }

    private func emit(_ info: [String: Any]) {
        notifyListeners("watchAction", data: info)
    }

    // ── 수신 ──
    public func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        DispatchQueue.main.async { self.emit(message) }
    }
    public func session(_ session: WCSession, didReceiveMessage message: [String: Any],
                        replyHandler: @escaping ([String: Any]) -> Void) {
        DispatchQueue.main.async { self.emit(message) }
        replyHandler(["ok": true])
    }
    public func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        DispatchQueue.main.async { self.emit(userInfo) }
    }

    // ── 필수 델리게이트 ──
    public func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}
    public func sessionDidBecomeInactive(_ session: WCSession) {}
    public func sessionDidDeactivate(_ session: WCSession) { WCSession.default.activate() }
}

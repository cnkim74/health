import Foundation
import Capacitor
import LocalAuthentication

/**
 * CARENOTE 생체인증 플러그인 (Face ID / Touch ID)
 * - isAvailable: 생체인증 사용 가능 여부와 종류 반환
 * - authenticate: Face ID/Touch ID 로 잠금 해제(실패 시 기기 암호로도 가능)
 */
@objc(BiometricPlugin)
public class BiometricPlugin: CAPPlugin {

    @objc func isAvailable(_ call: CAPPluginCall) {
        let ctx = LAContext()
        var err: NSError?
        let ok = ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &err)
        var type = "none"
        switch ctx.biometryType {
        case .faceID:  type = "faceID"
        case .touchID: type = "touchID"
        default:       type = "none"
        }
        call.resolve(["available": ok, "type": type])
    }

    @objc func authenticate(_ call: CAPPluginCall) {
        let reason = call.getString("reason") ?? "CARENOTE 잠금 해제"
        let ctx = LAContext()
        ctx.localizedFallbackTitle = "기기 암호 입력"
        // 생체인증 우선, 실패/불가 시 기기 암호로도 해제 가능
        ctx.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, error in
            DispatchQueue.main.async {
                if success {
                    call.resolve(["success": true])
                } else {
                    let code = (error as NSError?)?.code ?? -1
                    call.reject(error?.localizedDescription ?? "인증에 실패했습니다.", String(code))
                }
            }
        }
    }
}

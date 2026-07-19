import Foundation
import UIKit
import Capacitor
import AuthenticationServices

/**
 * CARENOTE OAuth 플러그인
 * ASWebAuthenticationSession 으로 인앱(모달 시트) 로그인을 띄우고,
 * carenote:// 커스텀 스킴 콜백을 자동으로 받아 JS로 돌려준다.
 * (SFSafariViewController 는 커스텀 스킴 리디렉션을 막기 때문에 이 API 사용)
 */
@objc(OauthPlugin)
public class OauthPlugin: CAPPlugin, ASWebAuthenticationPresentationContextProviding {

    private var session: ASWebAuthenticationSession?

    @objc func authenticate(_ call: CAPPluginCall) {
        guard let urlStr = call.getString("url"), let url = URL(string: urlStr) else {
            call.reject("로그인 URL이 필요합니다."); return
        }
        let scheme = call.getString("callbackScheme") ?? "carenote"

        DispatchQueue.main.async {
            let s = ASWebAuthenticationSession(url: url, callbackURLScheme: scheme) { callbackURL, error in
                if let error = error {
                    let ns = error as NSError
                    if ns.domain == ASWebAuthenticationSessionErrorDomain,
                       ns.code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                        call.reject("사용자가 취소했습니다.", "CANCELLED")
                    } else {
                        call.reject(error.localizedDescription)
                    }
                    self.session = nil
                    return
                }
                guard let callbackURL = callbackURL else {
                    call.reject("콜백 URL을 받지 못했습니다.")
                    self.session = nil
                    return
                }
                call.resolve(["url": callbackURL.absoluteString])
                self.session = nil
            }
            s.presentationContextProvider = self
            s.prefersEphemeralWebBrowserSession = false
            self.session = s
            s.start()
        }
    }

    public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        if let w = self.bridge?.viewController?.view.window { return w }
        return UIApplication.shared.windows.first ?? ASPresentationAnchor()
    }
}

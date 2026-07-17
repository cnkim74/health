import Foundation
import Capacitor
import CoreLocation

/**
 * CARENOTE 러닝/걷기 GPS 트래커
 * CoreLocation으로 실시간 위치를 스트리밍. JS는 'location' 리스너로 수신.
 *   requestPerm()  → 위치 권한 요청
 *   start()        → 고정밀 위치 업데이트 시작
 *   stop()         → 중지
 * 이벤트: 'location' { lat, lng, speed(m/s), accuracy(m), ts(ms) }
 */
@objc(RunTrackerPlugin)
public class RunTrackerPlugin: CAPPlugin, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var running = false

    public override func load() {
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 5           // 5m 이동마다 갱신
        manager.activityType = .fitness
        manager.allowsBackgroundLocationUpdates = false
    }

    @objc public func requestPerm(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            self.manager.requestWhenInUseAuthorization()
            call.resolve(["status": self.authString(self.currentStatus())])
        }
    }

    @objc public func start(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            let st = self.currentStatus()
            if st == .denied || st == .restricted {
                call.reject("위치 권한이 필요해요. 설정 > CARENOTE > 위치에서 허용해 주세요.")
                return
            }
            if st == .notDetermined { self.manager.requestWhenInUseAuthorization() }
            self.running = true
            self.manager.startUpdatingLocation()
            call.resolve(["started": true])
        }
    }

    @objc public func stop(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            self.running = false
            self.manager.stopUpdatingLocation()
            call.resolve(["stopped": true])
        }
    }

    public func locationManager(_ m: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard running else { return }
        for loc in locations {
            self.notifyListeners("location", data: [
                "lat": loc.coordinate.latitude,
                "lng": loc.coordinate.longitude,
                "speed": max(0, loc.speed),
                "accuracy": loc.horizontalAccuracy,
                "ts": loc.timestamp.timeIntervalSince1970 * 1000
            ])
        }
    }

    public func locationManager(_ m: CLLocationManager, didFailWithError error: Error) {
        self.notifyListeners("locationError", data: ["message": error.localizedDescription])
    }

    private func currentStatus() -> CLAuthorizationStatus {
        if #available(iOS 14.0, *) { return manager.authorizationStatus }
        return CLLocationManager.authorizationStatus()
    }
    private func authString(_ s: CLAuthorizationStatus) -> String {
        switch s {
        case .authorizedWhenInUse, .authorizedAlways: return "granted"
        case .denied: return "denied"
        case .restricted: return "restricted"
        default: return "prompt"
        }
    }
}

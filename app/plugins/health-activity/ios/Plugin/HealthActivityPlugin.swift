import Foundation
import Capacitor
import HealthKit

/**
 * CARENOTE HealthKit 브리지
 * 오늘(자정~현재)의 걸음수·활동 칼로리·기초대사량·걷기/달리기 거리를 합산해 반환.
 * Apple Watch 데이터도 HealthKit에 자동 병합되므로 별도 처리 불필요.
 */
@objc(HealthActivityPlugin)
public class HealthActivityPlugin: CAPPlugin {
    private let store = HKHealthStore()

    private var readTypes: Set<HKObjectType> {
        var set = Set<HKObjectType>()
        for ident in [HKQuantityTypeIdentifier.stepCount,
                      .activeEnergyBurned,
                      .basalEnergyBurned,
                      .distanceWalkingRunning] {
            if let t = HKObjectType.quantityType(forIdentifier: ident) { set.insert(t) }
        }
        return set
    }

    @objc public func isAvailable(_ call: CAPPluginCall) {
        call.resolve(["available": HKHealthStore.isHealthDataAvailable()])
    }

    // 주의: requestPermissions는 CAPPlugin 기본 메서드와 이름이 충돌하므로 requestAuth 사용
    @objc public func requestAuth(_ call: CAPPluginCall) {
        guard HKHealthStore.isHealthDataAvailable() else {
            call.reject("이 기기에서 HealthKit을 사용할 수 없습니다")
            return
        }
        store.requestAuthorization(toShare: nil, read: readTypes) { granted, error in
            if let error = error {
                call.reject(error.localizedDescription)
            } else {
                call.resolve(["granted": granted])
            }
        }
    }

    @objc public func getTodayActivity(_ call: CAPPluginCall) {
        guard HKHealthStore.isHealthDataAvailable() else {
            call.reject("이 기기에서 HealthKit을 사용할 수 없습니다")
            return
        }

        let now = Date()
        let start = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: now, options: .strictStartDate)

        // (결과 키, HK 식별자, 단위, 환산 계수)
        let metrics: [(String, HKQuantityTypeIdentifier, HKUnit, Double)] = [
            ("steps", .stepCount,              HKUnit.count(),       1.0),
            ("cal",   .activeEnergyBurned,     HKUnit.kilocalorie(), 1.0),
            ("bcal",  .basalEnergyBurned,      HKUnit.kilocalorie(), 1.0),
            ("dist",  .distanceWalkingRunning, HKUnit.meter(),       0.001) // m → km
        ]

        var result = [String: Double]()
        let lock = NSLock()
        let group = DispatchGroup()

        for (key, ident, unit, factor) in metrics {
            guard let qt = HKQuantityType.quantityType(forIdentifier: ident) else { continue }
            group.enter()
            let query = HKStatisticsQuery(quantityType: qt,
                                          quantitySamplePredicate: predicate,
                                          options: .cumulativeSum) { _, stats, _ in
                let value = stats?.sumQuantity()?.doubleValue(for: unit) ?? 0
                lock.lock()
                result[key] = value * factor
                lock.unlock()
                group.leave()
            }
            store.execute(query)
        }

        group.notify(queue: .main) {
            call.resolve([
                "steps": Int(result["steps"] ?? 0),
                "cal":   Int(result["cal"] ?? 0),
                "bcal":  Int(result["bcal"] ?? 0),
                "dist":  ((result["dist"] ?? 0) * 100).rounded() / 100
            ])
        }
    }
}

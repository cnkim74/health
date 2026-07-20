import Foundation
import Capacitor
import HealthKit

/**
 * CARENOTE HealthKit 브리지
 * 오늘(자정~현재)의 걸음수·활동 칼로리·기초대사량·걷기/달리기 거리를 합산해 반환.
 * 최근 며칠간의 혈당(리브레 등 CGM이 애플 건강에 기록한 값)도 반환.
 * Apple Watch·리브레 데이터도 HealthKit에 자동 병합되므로 별도 처리 불필요.
 */
@objc(HealthActivityPlugin)
public class HealthActivityPlugin: CAPPlugin {
    private let store = HKHealthStore()

    // mg/dL 단위
    private let mgdl = HKUnit.gramUnit(with: .milli).unitDivided(by: HKUnit.literUnit(with: .deci))

    private var readTypes: Set<HKObjectType> {
        var set = Set<HKObjectType>()
        for ident in [HKQuantityTypeIdentifier.stepCount,
                      .activeEnergyBurned,
                      .basalEnergyBurned,
                      .distanceWalkingRunning,
                      .bloodGlucose,
                      .bodyMass,
                      .bodyFatPercentage,
                      .heartRate,
                      .restingHeartRate,
                      .heartRateVariabilitySDNN,
                      .dietaryWater,
                      .bloodPressureSystolic,
                      .bloodPressureDiastolic] {
            if let t = HKObjectType.quantityType(forIdentifier: ident) { set.insert(t) }
        }
        if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) { set.insert(sleep) }
        // 혈압은 수축기/이완기 quantity 타입으로 읽음(위 목록에 포함). correlation 타입은
        // 읽기 권한 요청 시 iOS가 예외를 던져 앱이 크래시하므로 넣지 않는다.
        if #available(iOS 14.0, *) { set.insert(HKObjectType.electrocardiogramType()) }
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

    /**
     * 최근 N일(기본 3일)간의 혈당 샘플을 반환.
     * 리브레·CGM이 애플 건강에 기록해 둔 값을 그대로 읽음 (별도 연동 불필요).
     * 반환: { readings: [ { ts: ISO8601, mgdl: Int } ] }
     */
    @objc public func getRecentGlucose(_ call: CAPPluginCall) {
        guard HKHealthStore.isHealthDataAvailable(),
              let qt = HKQuantityType.quantityType(forIdentifier: .bloodGlucose) else {
            call.resolve(["readings": []])
            return
        }
        let days = call.getInt("days") ?? 3
        let now = Date()
        let start = Calendar.current.date(byAdding: .day, value: -max(1, days), to: now) ?? now
        let predicate = HKQuery.predicateForSamples(withStart: start, end: now, options: .strictStartDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        let iso = ISO8601DateFormatter()
        let query = HKSampleQuery(sampleType: qt, predicate: predicate,
                                  limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { [weak self] _, samples, _ in
            guard let self = self else { call.resolve(["readings": []]); return }
            var readings: [[String: Any]] = []
            for s in (samples as? [HKQuantitySample]) ?? [] {
                let v = s.quantity.doubleValue(for: self.mgdl)
                if v > 0 {
                    readings.append(["ts": iso.string(from: s.startDate), "mgdl": Int(v.rounded())])
                }
            }
            call.resolve(["readings": readings])
        }
        store.execute(query)
    }

    /**
     * 최근 N일(기본 14일)간 혈압 측정값을 날짜와 함께 반환(하루 단위 반영용).
     * 수축기·이완기를 각각 조회해 같은 측정시각(startDate)으로 짝지음.
     * 반환: { readings: [ { ts: ISO8601, sys: Int, dia: Int } ] }
     */
    @objc public func getRecentBP(_ call: CAPPluginCall) {
        guard HKHealthStore.isHealthDataAvailable(),
              let sysT = HKQuantityType.quantityType(forIdentifier: .bloodPressureSystolic),
              let diaT = HKQuantityType.quantityType(forIdentifier: .bloodPressureDiastolic) else {
            call.resolve(["readings": []]); return
        }
        let days = call.getInt("days") ?? 14
        let now = Date()
        let start = Calendar.current.date(byAdding: .day, value: -max(1, days), to: now) ?? now
        let pred = HKQuery.predicateForSamples(withStart: start, end: now, options: .strictStartDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        let mmHg = HKUnit.millimeterOfMercury()
        let iso = ISO8601DateFormatter()
        let group = DispatchGroup()
        var sysMap = [String: Int]()
        var diaMap = [String: Int]()
        group.enter()
        store.execute(HKSampleQuery(sampleType: sysT, predicate: pred, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, samples, _ in
            for s in (samples as? [HKQuantitySample]) ?? [] { sysMap[iso.string(from: s.startDate)] = Int(s.quantity.doubleValue(for: mmHg).rounded()) }
            group.leave()
        })
        group.enter()
        store.execute(HKSampleQuery(sampleType: diaT, predicate: pred, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, samples, _ in
            for s in (samples as? [HKQuantitySample]) ?? [] { diaMap[iso.string(from: s.startDate)] = Int(s.quantity.doubleValue(for: mmHg).rounded()) }
            group.leave()
        })
        group.notify(queue: .main) {
            var readings: [[String: Any]] = []
            for (ts, sys) in sysMap { if let dia = diaMap[ts] { readings.append(["ts": ts, "sys": sys, "dia": dia]) } }
            call.resolve(["readings": readings])
        }
    }

    // 최신 샘플 1개 값
    private func latest(_ ident: HKQuantityTypeIdentifier, _ unit: HKUnit, _ cb: @escaping (Double?) -> Void) {
        guard let qt = HKQuantityType.quantityType(forIdentifier: ident) else { cb(nil); return }
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let q = HKSampleQuery(sampleType: qt, predicate: nil, limit: 1, sortDescriptors: [sort]) { _, samples, _ in
            cb((samples?.first as? HKQuantitySample)?.quantity.doubleValue(for: unit))
        }
        store.execute(q)
    }
    // 오늘 합계
    private func todaySum(_ ident: HKQuantityTypeIdentifier, _ unit: HKUnit, _ cb: @escaping (Double) -> Void) {
        guard let qt = HKQuantityType.quantityType(forIdentifier: ident) else { cb(0); return }
        let start = Calendar.current.startOfDay(for: Date())
        let pred = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)
        let q = HKStatisticsQuery(quantityType: qt, quantitySamplePredicate: pred, options: .cumulativeSum) { _, s, _ in
            cb(s?.sumQuantity()?.doubleValue(for: unit) ?? 0)
        }
        store.execute(q)
    }

    /**
     * 바이탈: 체중·체지방·안정시심박·최근심박·HRV·물섭취(오늘 mL)·수면(어젯밤 시간)
     */
    @objc public func getVitals(_ call: CAPPluginCall) {
        guard HKHealthStore.isHealthDataAvailable() else { call.resolve([:]); return }
        var r = [String: Any]()
        let lock = NSLock(); let group = DispatchGroup()
        func put(_ k: String, _ v: Double?) { if let v = v { lock.lock(); r[k] = v; lock.unlock() } }

        group.enter(); latest(.bodyMass, .gramUnit(with: .kilo)) { put("weight", $0.map { ($0*10).rounded()/10 }); group.leave() }
        group.enter(); latest(.bodyFatPercentage, .percent()) { put("bodyFat", $0.map { ($0*100*10).rounded()/10 }); group.leave() }
        group.enter(); latest(.restingHeartRate, HKUnit.count().unitDivided(by: .minute())) { put("restingHR", $0.map { $0.rounded() }); group.leave() }
        group.enter(); latest(.heartRate, HKUnit.count().unitDivided(by: .minute())) { put("hr", $0.map { $0.rounded() }); group.leave() }
        group.enter(); latest(.heartRateVariabilitySDNN, .secondUnit(with: .milli)) { put("hrv", $0.map { $0.rounded() }); group.leave() }
        group.enter(); todaySum(.dietaryWater, .literUnit(with: .milli)) { put("waterMl", $0.rounded()); group.leave() }

        // 수면: 어젯밤(어제 18시 ~ 지금) asleep 시간 합산
        group.enter()
        if let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            let cal = Calendar.current
            let start = cal.date(byAdding: .hour, value: -18, to: cal.startOfDay(for: Date())) ?? Date()
            let pred = HKQuery.predicateForSamples(withStart: start, end: Date(), options: [])
            let q = HKSampleQuery(sampleType: sleepType, predicate: pred, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
                var asleep: TimeInterval = 0
                for s in (samples as? [HKCategorySample]) ?? [] {
                    // inBed(0), awake(2) 제외한 나머지를 수면으로
                    if s.value != HKCategoryValueSleepAnalysis.inBed.rawValue &&
                       !(s.value == 2) {
                        asleep += s.endDate.timeIntervalSince(s.startDate)
                    }
                }
                put("sleepHours", (asleep/3600*10).rounded()/10)
                group.leave()
            }
            store.execute(q)
        } else { group.leave() }

        // 혈압: 수축기·이완기를 각각(quantity 타입) 최근값으로 조회.
        // (correlation 타입은 읽기 권한이 불가하므로 개별 조회 — 오므론 등이 애플 건강에 기록한 값)
        let bpUnit = HKUnit.millimeterOfMercury()
        let bpSort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        if let sysT = HKQuantityType.quantityType(forIdentifier: .bloodPressureSystolic) {
            group.enter()
            let q = HKSampleQuery(sampleType: sysT, predicate: nil, limit: 1, sortDescriptors: [bpSort]) { _, samples, _ in
                if let s = samples?.first as? HKQuantitySample { put("bpSys", s.quantity.doubleValue(for: bpUnit).rounded()) }
                group.leave()
            }
            store.execute(q)
        }
        if let diaT = HKQuantityType.quantityType(forIdentifier: .bloodPressureDiastolic) {
            group.enter()
            let q = HKSampleQuery(sampleType: diaT, predicate: nil, limit: 1, sortDescriptors: [bpSort]) { _, samples, _ in
                if let d = samples?.first as? HKQuantitySample { put("bpDia", d.quantity.doubleValue(for: bpUnit).rounded()) }
                group.leave()
            }
            store.execute(q)
        }

        group.notify(queue: .main) { call.resolve(r) }
    }

    /**
     * 최근 심전도(ECG) 분류·평균심박 (iOS 14+)
     * 반환: { available, classification, avgHR, ts }
     */
    @objc public func getECG(_ call: CAPPluginCall) {
        guard #available(iOS 14.0, *) else { call.resolve(["available": false]); return }
        let ecgType = HKObjectType.electrocardiogramType()
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let q = HKSampleQuery(sampleType: ecgType, predicate: nil, limit: 1, sortDescriptors: [sort]) { _, samples, _ in
            guard let ecg = samples?.first as? HKElectrocardiogram else { call.resolve(["available": false]); return }
            let cls: String
            switch ecg.classification {
            case .sinusRhythm: cls = "정상 동리듬"
            case .atrialFibrillation: cls = "심방세동 의심"
            case .inconclusiveLowHeartRate: cls = "낮은 심박(판정불가)"
            case .inconclusiveHighHeartRate: cls = "높은 심박(판정불가)"
            case .inconclusivePoorReading, .inconclusiveOther: cls = "판정 불가"
            case .notSet: cls = "미분류"
            default: cls = "기타"
            }
            var avg: Double? = nil
            if let hr = ecg.averageHeartRate { avg = hr.doubleValue(for: HKUnit.count().unitDivided(by: .minute())) }
            let iso = ISO8601DateFormatter()
            call.resolve(["available": true, "classification": cls,
                          "avgHR": avg.map { Int($0.rounded()) } as Any,
                          "ts": iso.string(from: ecg.endDate)])
        }
        store.execute(q)
    }
}

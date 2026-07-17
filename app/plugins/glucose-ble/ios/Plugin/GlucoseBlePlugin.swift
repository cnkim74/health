import Foundation
import Capacitor
import CoreBluetooth

/**
 * CARENOTE 표준 블루투스 혈당기 리더
 * Bluetooth SIG 표준 Glucose Service(0x1808)를 구현한 혈당기(아큐첵 가이드/인스탄트 등)에서
 * 저장된 모든 혈당 기록을 읽어 반환.
 *
 * JS 인터페이스:
 *   requestPerm()                → 블루투스 권한 확인
 *   scanAndRead({timeout})       → 혈당기 스캔·연결·전체 기록 읽기
 *      → { device: 이름, readings: [ { ts: ISO8601, mgdl: Int, meal: Int? } ] }
 */
@objc(GlucoseBlePlugin)
public class GlucoseBlePlugin: CAPPlugin, CBCentralManagerDelegate, CBPeripheralDelegate {

    private var central: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var pendingCall: CAPPluginCall?
    private var readings: [[String: Any]] = []
    private var deviceName: String = ""
    private var scanTimeout: TimeInterval = 20
    private var timeoutWork: DispatchWorkItem?
    private var overallWork: DispatchWorkItem?
    private var finished = false

    // 표준 UUID
    private let glucoseService   = CBUUID(string: "1808")
    private let cMeasurement     = CBUUID(string: "2A18") // Glucose Measurement (notify)
    private let cFeature         = CBUUID(string: "2A51") // Glucose Feature (read, 암호화 → 페어링 트리거)
    private let cRACP            = CBUUID(string: "2A52") // Record Access Control Point (write+indicate)

    private var measureChar: CBCharacteristic?
    private var racpChar: CBCharacteristic?
    private var featureChar: CBCharacteristic?
    private var paired = false

    private func ensureCentral() {
        if central == nil {
            central = CBCentralManager(delegate: self, queue: nil)
        }
    }

    @objc public func requestPerm(_ call: CAPPluginCall) {
        ensureCentral()
        // iOS는 첫 스캔 시 권한 팝업을 띄움. 여기선 상태만 반환.
        call.resolve(["state": stateString(central?.state ?? .unknown)])
    }

    @objc public func scanAndRead(_ call: CAPPluginCall) {
        if pendingCall != nil { call.reject("이미 혈당기와 통신 중입니다"); return }
        self.scanTimeout = TimeInterval((call.getInt("timeout") ?? 20))
        self.pendingCall = call
        self.readings = []
        self.deviceName = ""
        self.finished = false
        self.paired = false
        self.measureChar = nil; self.racpChar = nil; self.featureChar = nil
        ensureCentral()
        // 블루투스가 켜져 있으면 즉시 스캔, 아니면 centralManagerDidUpdateState에서 시작
        if central.state == .poweredOn { startScan() }
    }

    private func startScan() {
        guard let _ = pendingCall else { return }
        central.scanForPeripherals(withServices: [glucoseService], options: nil)
        // 스캔 단계 타임아웃: 지정 시간 내 기기를 못 찾으면 실패
        let work = DispatchWorkItem { [weak self] in
            guard let self = self, !self.finished else { return }
            if self.peripheral == nil {
                self.fail("혈당기를 찾지 못했어요. 혈당기의 블루투스(설정/동기화 모드)를 켜고 가까이 둔 뒤 다시 시도해 주세요.")
            }
        }
        timeoutWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + scanTimeout, execute: work)
        // 전체 안전 타임아웃: 페어링/읽기가 아무리 걸려도 120초 후엔 무조건 종료 (앱 멈춤 방지)
        let overall = DispatchWorkItem { [weak self] in
            guard let self = self, !self.finished else { return }
            if self.readings.isEmpty {
                self.fail("혈당기 연결이 지연됐어요. 페어링 코드를 확인하고 다시 시도해 주세요.")
            } else {
                self.finishSuccess() // 일부라도 받았으면 그걸로 마무리
            }
        }
        overallWork = overall
        DispatchQueue.main.asyncAfter(deadline: .now() + 120, execute: overall)
    }

    // MARK: - CBCentralManagerDelegate
    public func centralManagerDidUpdateState(_ cm: CBCentralManager) {
        if cm.state == .poweredOn, pendingCall != nil, peripheral == nil {
            startScan()
        } else if cm.state == .unauthorized {
            fail("블루투스 권한이 필요해요. 설정 > CARENOTE > 블루투스를 켜 주세요.")
        } else if cm.state == .poweredOff {
            fail("블루투스가 꺼져 있어요. 블루투스를 켜 주세요.")
        }
    }

    public func centralManager(_ cm: CBCentralManager, didDiscover p: CBPeripheral,
                               advertisementData: [String: Any], rssi RSSI: NSNumber) {
        guard peripheral == nil else { return }
        peripheral = p
        deviceName = p.name ?? "혈당기"
        cm.stopScan()
        p.delegate = self
        cm.connect(p, options: nil)
    }

    public func centralManager(_ cm: CBCentralManager, didConnect p: CBPeripheral) {
        p.discoverServices([glucoseService])
    }

    public func centralManager(_ cm: CBCentralManager, didFailToConnect p: CBPeripheral, error: Error?) {
        fail("혈당기 연결 실패: \(error?.localizedDescription ?? "알 수 없음")")
    }

    public func centralManager(_ cm: CBCentralManager, didDisconnectPeripheral p: CBPeripheral, error: Error?) {
        // 정상 완료(finished) 후 끊김은 무시. 그 외엔, 받은 기록이 있으면 성공 처리, 없으면 실패.
        guard !finished else { return }
        if !readings.isEmpty {
            finishSuccess()
        } else {
            fail("혈당기 연결이 끊겼어요. 페어링 코드를 확인하고 다시 시도해 주세요.")
        }
    }

    // MARK: - CBPeripheralDelegate
    public func peripheral(_ p: CBPeripheral, didDiscoverServices error: Error?) {
        guard let svc = p.services?.first(where: { $0.uuid == glucoseService }) else {
            fail("이 기기는 표준 혈당 서비스를 지원하지 않아요."); return
        }
        p.discoverCharacteristics([cMeasurement, cFeature, cRACP], for: svc)
    }

    public func peripheral(_ p: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let chars = service.characteristics else { fail("특성 탐색 실패"); return }
        for c in chars {
            if c.uuid == cMeasurement { measureChar = c }
            if c.uuid == cRACP { racpChar = c }
            if c.uuid == cFeature { featureChar = c }
        }
        guard measureChar != nil, racpChar != nil else { fail("혈당 특성을 찾지 못했어요."); return }
        // ① 먼저 암호화된 Feature 특성을 읽어 페어링(passkey) 팝업을 확실히 띄움
        if let f = featureChar {
            p.readValue(for: f)
        } else {
            // Feature 없으면 바로 구독으로 진행 (구독 시 페어링 트리거)
            subscribeAndRequest(p)
        }
    }

    private func subscribeAndRequest(_ p: CBPeripheral) {
        guard let m = measureChar, let r = racpChar else { return }
        p.setNotifyValue(true, for: m)
        p.setNotifyValue(true, for: r)
    }

    public func peripheral(_ p: CBPeripheral, didUpdateNotificationStateFor c: CBCharacteristic, error: Error?) {
        // RACP 구독 완료 후 "저장된 모든 기록 보고" 명령 전송
        if c.uuid == cRACP, c.isNotifying, error == nil {
            let cmd = Data([0x01, 0x01]) // Op 0x01(Report stored records), Operator 0x01(All)
            p.writeValue(cmd, for: c, type: .withResponse)
        }
    }

    public func peripheral(_ p: CBPeripheral, didUpdateValueFor c: CBCharacteristic, error: Error?) {
        // Feature 읽기 성공 = 페어링 완료 → 이제 구독+기록요청 시작
        if c.uuid == cFeature {
            if let e = error {
                fail("페어링에 실패했어요: \(e.localizedDescription). 혈당기에 표시된 코드를 아이폰 팝업에 입력해 주세요.")
                return
            }
            if !paired { paired = true; subscribeAndRequest(p) }
            return
        }
        if error != nil { return }
        guard let data = c.value else { return }
        if c.uuid == cMeasurement {
            if let r = parseGlucoseMeasurement(data) { readings.append(r) }
        } else if c.uuid == cRACP {
            // RACP 응답: [0x06(Response Code), 0x00, requestOpCode, responseCode]
            // responseValue 0x01 = 성공. 성공/무기록이면 완료 처리.
            let bytes = [UInt8](data)
            if bytes.count >= 1 && bytes[0] == 0x06 {
                finishSuccess()
            }
        }
    }

    // MARK: - Glucose Measurement 파싱
    private func parseGlucoseMeasurement(_ data: Data) -> [String: Any]? {
        let b = [UInt8](data)
        guard b.count >= 10 else { return nil }
        var i = 0
        let flags = b[i]; i += 1
        let timeOffsetPresent = (flags & 0x01) != 0
        let concPresent       = (flags & 0x02) != 0
        let unitMolL          = (flags & 0x04) != 0
        // sequence number (uint16 LE)
        i += 2
        // base time
        let year = Int(b[i]) | (Int(b[i+1]) << 8); i += 2
        let month = Int(b[i]); i += 1
        let day = Int(b[i]); i += 1
        let hour = Int(b[i]); i += 1
        let minute = Int(b[i]); i += 1
        let second = Int(b[i]); i += 1

        var offsetMin = 0
        if timeOffsetPresent {
            guard i + 2 <= b.count else { return nil }
            let raw = Int(b[i]) | (Int(b[i+1]) << 8)
            offsetMin = raw > 0x7FFF ? raw - 0x10000 : raw // int16
            i += 2
        }

        var mgdl: Int? = nil
        var mealCtx: Int? = nil
        if concPresent {
            guard i + 3 <= b.count else { return nil }
            let sfloat = Int(b[i]) | (Int(b[i+1]) << 8); i += 2
            let value = sfloatToDouble(sfloat)
            let typeLoc = b[i]; i += 1
            let type = Int(typeLoc & 0x0F)
            _ = type
            if unitMolL {
                mgdl = Int((value * 1000.0 * 18.0182).rounded()) // mol/L → mmol/L → mg/dL
            } else {
                mgdl = Int((value * 100000.0).rounded())          // kg/L → mg/dL
            }
        }
        _ = mealCtx

        // 날짜 조합 (기기 로컬 시간 기준)
        var comp = DateComponents()
        comp.year = year; comp.month = month; comp.day = day
        comp.hour = hour; comp.minute = minute; comp.second = second
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone.current
        guard var date = cal.date(from: comp) else { return nil }
        if offsetMin != 0 { date = date.addingTimeInterval(TimeInterval(offsetMin * 60)) }

        guard let mg = mgdl, mg > 0, mg < 2000 else { return nil }
        let iso = ISO8601DateFormatter()
        return ["ts": iso.string(from: date), "mgdl": mg]
    }

    // IEEE-11073 16-bit SFLOAT → Double
    private func sfloatToDouble(_ raw: Int) -> Double {
        var mantissa = raw & 0x0FFF
        var exponent = (raw >> 12) & 0x0F
        if exponent >= 0x0008 { exponent = -((0x000F + 1) - exponent) }       // 4-bit signed
        if mantissa >= 0x0800 { mantissa = -((0x0FFF + 1) - mantissa) }        // 12-bit signed
        return Double(mantissa) * pow(10.0, Double(exponent))
    }

    // MARK: - 완료/실패 처리
    private func finishSuccess() {
        guard !finished, let call = pendingCall else { return }
        finished = true
        timeoutWork?.cancel(); overallWork?.cancel()
        cleanup()
        call.resolve(["device": deviceName, "readings": readings])
        pendingCall = nil
    }

    private func fail(_ msg: String) {
        guard !finished, let call = pendingCall else { return }
        finished = true
        timeoutWork?.cancel(); overallWork?.cancel()
        cleanup()
        call.reject(msg)
        pendingCall = nil
    }

    private func cleanup() {
        if central?.isScanning == true { central.stopScan() }
        if let p = peripheral { central.cancelPeripheralConnection(p) }
        peripheral = nil
    }

    private func stateString(_ s: CBManagerState) -> String {
        switch s {
        case .poweredOn: return "on"
        case .poweredOff: return "off"
        case .unauthorized: return "unauthorized"
        case .unsupported: return "unsupported"
        default: return "unknown"
        }
    }
}

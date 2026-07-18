import SwiftUI

struct ContentView: View {
    @EnvironmentObject var state: WatchState
    @State private var toast: String = ""

    private func act(_ payload: [String: Any], _ msg: String) {
        WatchConn.shared.send(payload)
        WKInterfaceDevice.current().play(.success)
        toast = msg
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) { if toast == msg { toast = "" } }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 10) {
                    Text("CARENOTE").font(.headline)

                    // ── 복약 ──
                    if state.meds.isEmpty {
                        Button { act(["action": "meds_all_done"], "복약 완료 ✓") } label: {
                            Label("오늘 복약 완료", systemImage: "pills.fill").frame(maxWidth: .infinity)
                        }.tint(.green)
                    } else {
                        Text("오늘 복약").font(.caption).foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        ForEach(state.meds, id: \.self) { m in
                            let taken = (m["taken"] ?? "") == "1"
                            Button {
                                act(["action": "med_taken", "id": m["id"] ?? ""], "\(m["name"] ?? "약") ✓")
                            } label: {
                                HStack {
                                    Image(systemName: taken ? "checkmark.circle.fill" : "circle")
                                    Text(m["name"] ?? "약").lineLimit(1)
                                    Spacer()
                                }.frame(maxWidth: .infinity)
                            }.tint(taken ? .green : .gray)
                        }
                    }

                    // ── 물 ──
                    Button { act(["action": "water", "ml": 250], "물 250ml ✓") } label: {
                        Label("물 +250ml", systemImage: "drop.fill").frame(maxWidth: .infinity)
                    }.tint(.blue)
                    Button { act(["action": "water", "ml": 500], "물 +500ml") } label: {
                        Label("물 +500ml", systemImage: "drop.fill").frame(maxWidth: .infinity)
                    }.tint(.blue)

                    // ── 운동 ──
                    NavigationLink { WorkoutView(type: "walk") } label: {
                        Label("걷기 시작", systemImage: "figure.walk").frame(maxWidth: .infinity)
                    }.tint(.orange)
                    NavigationLink { WorkoutView(type: "run") } label: {
                        Label("뛰기 시작", systemImage: "figure.run").frame(maxWidth: .infinity)
                    }.tint(.pink)

                    if !toast.isEmpty {
                        Text(toast).font(.footnote).foregroundColor(.secondary)
                    }
                }.padding()
            }
        }
    }
}

/// 걷기/뛰기 — 3·2·1 카운트다운 후 스톱워치. 종료 시 폰에 기록 전송.
struct WorkoutView: View {
    let type: String
    @Environment(\.dismiss) private var dismiss
    @State private var countdown = 3
    @State private var started = false
    @State private var startAt = Date()
    @State private var elapsed = 0
    @State private var timer: Timer? = nil

    private var title: String { type == "run" ? "뛰기" : "걷기" }
    private var color: Color { type == "run" ? .pink : .orange }
    private func fmt(_ s: Int) -> String { String(format: "%02d:%02d", s / 60, s % 60) }

    var body: some View {
        VStack(spacing: 14) {
            Text(title).font(.headline)
            if !started {
                Text("\(countdown)")
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .foregroundColor(color)
                Text("준비하세요").font(.footnote).foregroundColor(.secondary)
            } else {
                Image(systemName: type == "run" ? "figure.run" : "figure.walk")
                    .font(.system(size: 46, weight: .semibold))
                    .foregroundColor(color)
                    .symbolEffect(.bounce, options: .repeating.speed(type == "run" ? 1.6 : 0.85))
                    .frame(height: 56)
                Text(fmt(elapsed))
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Button {
                    WatchConn.shared.send(["action": "workout_end", "type": type, "seconds": elapsed])
                    WKInterfaceDevice.current().play(.stop)
                    timer?.invalidate()
                    dismiss()
                } label: {
                    Label("종료 & 저장", systemImage: "stop.fill").frame(maxWidth: .infinity)
                }.tint(.red)
            }
        }
        .padding()
        .onAppear { runCountdown() }
        .onDisappear { timer?.invalidate() }
    }

    private func runCountdown() {
        countdown = 3
        WKInterfaceDevice.current().play(.click)
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { t in
            countdown -= 1
            if countdown > 0 {
                WKInterfaceDevice.current().play(.click)
            } else {
                t.invalidate()
                startWorkout()
            }
        }
    }

    private func startWorkout() {
        started = true
        startAt = Date(); elapsed = 0
        WatchConn.shared.send(["action": "workout_start", "type": type])
        WKInterfaceDevice.current().play(.start)
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            elapsed = Int(Date().timeIntervalSince(startAt))
        }
    }
}

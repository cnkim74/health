import SwiftUI

struct ContentView: View {
    @State private var toast: String = ""

    private func act(_ payload: [String: Any], _ msg: String) {
        WatchConn.shared.send(payload)
        WKInterfaceDevice.current().play(.success)   // 햅틱
        toast = msg
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            if toast == msg { toast = "" }
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                Text("CARENOTE")
                    .font(.headline)
                    .padding(.bottom, 2)

                Button {
                    act(["action": "meds_all_done"], "복약 완료 ✓")
                } label: {
                    Label("오늘 복약 완료", systemImage: "pills.fill")
                        .frame(maxWidth: .infinity)
                }
                .tint(.green)

                Button {
                    act(["action": "water", "ml": 250], "물 250ml ✓")
                } label: {
                    Label("물 +250ml", systemImage: "drop.fill")
                        .frame(maxWidth: .infinity)
                }
                .tint(.blue)

                Button {
                    act(["action": "water", "ml": 500], "물 +500ml")
                } label: {
                    Label("물 +500ml", systemImage: "drop.fill")
                        .frame(maxWidth: .infinity)
                }
                .tint(.blue)

                if !toast.isEmpty {
                    Text(toast)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .transition(.opacity)
                }
            }
            .padding()
        }
    }
}

#Preview {
    ContentView()
}

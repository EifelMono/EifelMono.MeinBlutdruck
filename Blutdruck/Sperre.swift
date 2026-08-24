import SwiftUI
import LocalAuthentication

/// Schützt die Werte vor fremden Blicken: Face ID, Touch ID oder Gerätecode.
@MainActor
final class Schutz: ObservableObject {

    @Published var entsperrt = false
    @Published var fehler = ""
    @AppStorage("sperreAktiv") var aktiv = true {
        didSet { if !aktiv { entsperrt = true } }
    }

    var verfahren: String {
        let zusammenhang = LAContext()
        _ = zusammenhang.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
        switch zusammenhang.biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        default: return "Gerätecode"
        }
    }

    func pruefen() async {
        guard aktiv else { entsperrt = true; return }
        guard !entsperrt else { return }
        let zusammenhang = LAContext()
        zusammenhang.localizedCancelTitle = "Abbrechen"
        do {
            entsperrt = try await zusammenhang.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: "Deine Blutdruckwerte sind geschützt.")
            fehler = ""
        } catch {
            entsperrt = false
            fehler = (error as? LAError)?.code == .userCancel ? "" : error.localizedDescription
        }
    }

    func sperren() {
        if aktiv { entsperrt = false }
    }
}

struct Sperrbildschirm: View {
    @EnvironmentObject var schutz: Schutz

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "lock.fill")
                .font(.system(size: 44)).foregroundStyle(.secondary)
            Text("Geschützt").font(.title2.bold())
            Text("Die Auswertung wird erst nach dem Entsperren angezeigt.")
                .font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
            if !schutz.fehler.isEmpty {
                Text(schutz.fehler).font(.footnote).foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
            Button("Mit \(schutz.verfahren) entsperren") {
                Task { await schutz.pruefen() }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(30)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

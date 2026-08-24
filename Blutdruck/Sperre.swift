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
            fehler = meldung(zu: error)
        }
    }

    /// Systemmeldungen kommen auf Englisch – hier in verständliches Deutsch übersetzt.
    private func meldung(zu fehler: Error) -> String {
        guard let la = fehler as? LAError else { return "Entsperren nicht möglich." }
        switch la.code {
        case .userCancel, .systemCancel, .appCancel:
            return ""
        case .userFallback:
            return "Bitte den Gerätecode eingeben."
        case .biometryNotEnrolled:
            return "Auf diesem Gerät ist \(verfahren) nicht eingerichtet."
        case .biometryNotAvailable:
            return "\(verfahren) steht hier nicht zur Verfügung."
        case .biometryLockout:
            return "Zu viele Versuche – bitte einmal mit dem Gerätecode entsperren."
        case .passcodeNotSet:
            return "Für den Schutz muss ein Gerätecode eingerichtet sein."
        case .authenticationFailed:
            return "Nicht erkannt. Bitte noch einmal versuchen."
        default:
            return "Entsperren nicht möglich."
        }
    }

    func sperren() {
        if aktiv { entsperrt = false }
    }
}

/// Hintergrund für Sperr- und Abdeckbildschirm – ruhig, in den Farben der App.
struct Schutzhintergrund: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color.sysFarbe.opacity(0.18),
                                    Color.diaFarbe.opacity(0.22)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            LinearGradient(colors: [Color(.systemBackground).opacity(0.86),
                                    Color(.systemBackground).opacity(0.62)],
                           startPoint: .top, endPoint: .bottom)
            // Zwei weiche Ringe wie ein abklingender Herzschlag
            ForEach(0..<2) { i in
                Circle()
                    .strokeBorder(Color.diaFarbe.opacity(0.10), lineWidth: 1.5)
                    .frame(width: 260 + CGFloat(i) * 150, height: 260 + CGFloat(i) * 150)
            }
        }
        .ignoresSafeArea()
    }
}

/// Wird gezeigt, sobald die App in den Hintergrund oder in die Übersicht wandert.
struct Abdeckung: View {
    var body: some View {
        ZStack {
            Schutzhintergrund()
            VStack(spacing: 14) {
                Image("Logo")
                    .resizable().scaledToFit().frame(width: 84, height: 84)
                    .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 19, style: .continuous)
                        .strokeBorder(.white.opacity(0.5)))
                    .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
                Text("Mein Blutdruck").font(.title3.weight(.semibold))
                Label("geschützt", systemImage: "lock.fill")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
    }
}

struct Sperrbildschirm: View {
    @EnvironmentObject var schutz: Schutz

    var body: some View {
        ZStack {
            Schutzhintergrund()
            VStack(spacing: 16) {
                PulsendesLogo()
                Text("Mein Blutdruck").font(.title2.weight(.semibold))
                Text("Deine Werte sind geschützt und werden erst nach dem Entsperren angezeigt.")
                    .font(.callout).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center).padding(.horizontal, 24)
                if !schutz.fehler.isEmpty {
                    Text(schutz.fehler).font(.footnote).foregroundStyle(Color.statusKritisch)
                        .multilineTextAlignment(.center).padding(.horizontal, 24)
                }
                Button {
                    Task { await schutz.pruefen() }
                } label: {
                    Label("Mit \(schutz.verfahren) entsperren",
                          systemImage: schutz.verfahren == "Face ID" ? "faceid" : "lock.open.fill")
                        .padding(.horizontal, 6)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.top, 4)
            }
            .padding(30)
        }
    }
}

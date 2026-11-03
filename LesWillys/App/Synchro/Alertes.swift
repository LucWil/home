import SwiftUI
import CloudKit
import UserNotifications

/// Prévenir la famille : « Ambre a mis 4 articles au surgélateur ».
/// App ouverte → une bannière en haut de l'écran ; app fermée → une notification.
@MainActor
final class Alertes: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let partagee = Alertes()

    struct Annonce: Identifiable, Equatable {
        let id: String
        let membre: String
        let phrase: String
        let onglet: String
        let icone: String
    }
    @Published var courante: Annonce?

    /// Réglage dans Chez nous.
    static var actives: Bool {
        get { Base.reglages.object(forKey: "alertes") as? Bool ?? true }
        set { Base.reglages.set(newValue, forKey: "alertes") }
    }

    static func demanderAutorisation() async {
        let centre = UNUserNotificationCenter.current()
        centre.delegate = partagee
        _ = try? await centre.requestAuthorization(options: [.alert, .sound, .badge])
    }

    /// Appelé quand des activités arrivent d'iCloud.
    static func annoncer(_ enregistrements: [CKRecord]) {
        guard actives, let moi = Base.moi else { return }
        let recentes = enregistrements.compactMap { r -> Annonce? in
            let a = Activite(membre: "", genre: "", onglet: "accueil", detail: "")
            a.lire(r)
            // Ni ses propres gestes, ni les vieilles nouvelles (première synchro d'un appareil).
            guard a.membre != moi, Date.now.timeIntervalSince(a.quand) < 15 * 60 else { return nil }
            let nom = Famille.membre(a.membre)?.nom ?? ""
            return Annonce(id: r.recordID.recordName + "\(a.nombre)", membre: a.membre,
                           phrase: "\(nom) \(a.phrase)", onglet: a.onglet, icone: a.icone)
        }
        guard !recentes.isEmpty else { return }

        if UIApplication.shared.applicationState == .active {
            withAnimation(Anim.douce) { partagee.courante = recentes.last }
            Retour.leger()
        } else {
            for a in recentes {
                let c = UNMutableNotificationContent()
                c.title = "Les Willys"
                c.body = a.phrase
                c.sound = .default
                c.threadIdentifier = a.onglet          // les notifications se rangent par onglet
                c.userInfo = ["onglet": a.onglet]
                // Même identifiant pour une ligne regroupée : la notification se met à jour au lieu de s'empiler.
                let id = a.id.components(separatedBy: "/").last ?? a.id
                UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: String(id.prefix(36)), content: c, trigger: nil))
            }
        }
    }

    // Toucher une notification ouvre l'app sur le bon onglet.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let onglet = response.notification.request.content.userInfo["onglet"] as? String ?? "accueil"
        await MainActor.run { _ = UIApplication.shared.open(URL(string: "willys://\(onglet)")!) }
    }
}

/// La bannière qui glisse en haut de l'écran quand quelqu'un fait quelque chose.
struct BanniereActivite: View {
    @Binding var onglet: Onglet
    @ObservedObject private var alertes = Alertes.partagee

    var body: some View {
        if let a = alertes.courante {
            Button {
                if let o = Onglet(rawValue: a.onglet) { onglet = o }
                avecAnimation { alertes.courante = nil }
            } label: {
                HStack(spacing: 12) {
                    Aimant(membre: a.membre, taille: 34)
                    Text(a.phrase).font(.willys(.subheadline, poids: .semibold)).foregroundStyle(.primary)
                        .multilineTextAlignment(.leading).lineLimit(2)
                    Spacer(minLength: 0)
                    Image(systemName: a.icone).foregroundStyle(Theme.accent).font(.title3)
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(.regularMaterial, in: Capsule())
                .shadow(color: .black.opacity(0.15), radius: 12, y: 6)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .transition(.move(edge: .top).combined(with: .opacity))
            .task(id: a.id) {
                try? await Task.sleep(for: .seconds(4))
                avecAnimation { if alertes.courante?.id == a.id { alertes.courante = nil } }
            }
            .accessibilityLabel(a.phrase)
            .accessibilityHint("Ouvre l'onglet concerné")
        }
    }
}

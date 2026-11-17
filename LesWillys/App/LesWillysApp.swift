import SwiftUI
import SwiftData
import CloudKit
import UIKit
import UserNotifications

@main
struct LesWillysApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var delegue
    @Environment(\.scenePhase) private var phase

    var body: some Scene {
        WindowGroup {
            RacineView()
                .environmentObject(SynchroFamille.partagee)
        }
        .modelContainer(Base.app)
        .onChange(of: phase) { _, p in
            // En revenant dans l'app : on envoie ce que les widgets ont noté et on récupère les nouveautés.
            if p == .active { Task { await SynchroFamille.partagee.synchroniserMaintenant() } }
        }
    }
}

/// Nécessaire pour recevoir l'invitation iCloud (le lien envoyé par Chouchou) et les notifications
/// silencieuses de CloudKit quand quelqu'un modifie quelque chose.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        application.registerForRemoteNotifications()
        UNUserNotificationCenter.current().delegate = Alertes.partagee   // toucher une notification ouvre le bon onglet
        Theme.appliquerAuxBarres()
        return true
    }

    func application(_ application: UIApplication, configurationForConnecting scene: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: nil, sessionRole: scene.role)
        config.delegateClass = SceneDelegate.self
        return config
    }
}

final class SceneDelegate: NSObject, UIWindowSceneDelegate {
    func windowScene(_ windowScene: UIWindowScene, userDidAcceptCloudKitShareWith invitation: CKShare.Metadata) {
        Task { @MainActor in await SynchroFamille.partagee.accepter(invitation) }
    }
}

/// Les six onglets, comme dans l'app web.
enum Onglet: String, CaseIterable, Identifiable {
    case accueil, calendrier, cuisine, loisirs, chezNous = "chez-nous"
    var id: String { rawValue }
    var titre: String {
        switch self {
        case .accueil: "La famille"
        case .calendrier: "Calendrier"
        case .cuisine: "Cuisine"
        case .loisirs: "Loisirs"
        case .chezNous: "Chez nous"
        }
    }
    var icone: String {
        switch self {
        case .accueil: "heart"
        case .calendrier: "calendar"
        case .cuisine: "frying.pan"
        case .loisirs: "ticket"
        case .chezNous: "house"
        }
    }
}

struct RacineView: View {
    @Environment(\.modelContext) private var ctx
    @Environment(\.colorScheme) private var scheme
    @Environment(\.scenePhase) private var phase
    @State private var moi: String? = RacineView.demo("demoMoi") ?? Base.moi.flatMap { Famille.estActif($0) ? $0 : nil }
    @State private var onglet: Onglet = RacineView.demo("demoOnglet").flatMap(Onglet.init(rawValue:)) ?? .accueil

    /// Pour les captures d'écran automatiques (simulateur, GitHub) : `-demoMoi loulou -demoOnglet loisirs`
    /// au lancement choisit le membre et l'onglet. Sans effet dans l'usage normal.
    static func demo(_ cle: String) -> String? { UserDefaults.standard.string(forKey: cle) }
    @State private var partieLoisirs: LoisirsView.Partie = RacineView.demo("demoLoisirs").flatMap(LoisirsView.Partie.init(cle:)) ?? .voyages
    @State private var boniOuvert = false

    var body: some View {
        Group {
            if let moi {
                TabView(selection: $onglet) {
                    ForEach(Onglet.allCases) { o in
                        NavigationStack { ecran(o, moi: moi) }
                            .tabItem { Label(o.titre, systemImage: o.icone) }
                            .tag(o)
                    }
                }
                .tint(Theme.accent)
                .font(.willys(.body))
                .transition(.opacity)
                .sensoryFeedback(.selection, trigger: onglet)
                .sheet(isPresented: $boniOuvert) { NavigationStack { BoniView(moi: moi) } }
                .task(id: moi) {
                    noterVisite(moi)
                    await SynchroFamille.partagee.demarrer()
                    // Tant que l'app est ouverte, on redit « je suis là » toutes les minutes.
                    while !Task.isCancelled {
                        try? await Task.sleep(for: .seconds(60))
                        if phase == .active { noterVisite(moi) }
                    }
                }
                .onChange(of: onglet) { _, _ in noterVisite(moi) }
                .overlay(alignment: .top) { BanniereActivite(onglet: $onglet) }
                .onReceive(NotificationCenter.default.publisher(for: .willysModifie)) { _ in
                    SynchroFamille.partagee.envoyerFile()
                }
            } else {
                ChoixMembreView { choisi in
                    Retour.aimant()
                    Base.moi = choisi
                    avecAnimation { moi = choisi }
                    Base.rafraichirWidgets()
                }
                .transition(.opacity)
            }
        }
        .background(Theme.emaille(scheme))
        // Les widgets ouvrent l'app sur le bon onglet : willys://cuisine, willys://calendrier, willys://boni…
        .onOpenURL { url in
            if url.host == "boni" { boniOuvert = true }
            // Voyages et week-ends vivent maintenant dans Loisirs (liens du fil, des widgets, des notifications)
            else if let p = LoisirsView.Partie(cle: url.host ?? "") { partieLoisirs = p; onglet = .loisirs }
            else if let o = Onglet(rawValue: url.host ?? "") { onglet = o }
        }
    }

    @ViewBuilder private func ecran(_ o: Onglet, moi: String) -> some View {
        switch o {
        case .accueil: AccueilView(moi: moi)
        case .calendrier: CalendrierView(moi: moi)
        case .cuisine: CuisineView(moi: moi)
        case .loisirs: LoisirsView(moi: moi, partie: $partieLoisirs)
        case .chezNous: ChezNousView(moi: moi) { self.moi = nil; Base.moi = nil }
        }
    }

    private func noterVisite(_ moi: String) {
        Presence.signaler(onglet: onglet.rawValue, dans: ctx)
    }
}

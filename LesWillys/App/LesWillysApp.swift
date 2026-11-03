import SwiftUI
import SwiftData
import CloudKit
import UIKit

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
    case accueil, calendrier, voyages, cuisine, weekends, chezNous = "chez-nous"
    var id: String { rawValue }
    var titre: String {
        switch self {
        case .accueil: "La famille"
        case .calendrier: "Calendrier"
        case .voyages: "Voyages"
        case .cuisine: "Cuisine"
        case .weekends: "Week-ends"
        case .chezNous: "Chez nous"
        }
    }
    var icone: String {
        switch self {
        case .accueil: "heart"
        case .calendrier: "calendar"
        case .voyages: "airplane"
        case .cuisine: "frying.pan"
        case .weekends: "sun.max"
        case .chezNous: "house"
        }
    }
}

struct RacineView: View {
    @Environment(\.modelContext) private var ctx
    @Environment(\.colorScheme) private var scheme
    @State private var moi: String? = Base.moi
    @State private var onglet: Onglet = .accueil
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
                .sheet(isPresented: $boniOuvert) { NavigationStack { BoniView(moi: moi) } }
                .task(id: moi) {
                    noterVisite(moi)
                    await SynchroFamille.partagee.demarrer()
                }
                .onReceive(NotificationCenter.default.publisher(for: .willysModifie)) { _ in
                    SynchroFamille.partagee.envoyerFile()
                }
            } else {
                ChoixMembreView { choisi in
                    Base.moi = choisi
                    moi = choisi
                    Base.rafraichirWidgets()
                }
            }
        }
        .background(Theme.emaille(scheme))
        // Les widgets ouvrent l'app sur le bon onglet : willys://cuisine, willys://calendrier, willys://boni…
        .onOpenURL { url in
            if url.host == "boni" { boniOuvert = true }
            else if let o = Onglet(rawValue: url.host ?? "") { onglet = o }
        }
    }

    @ViewBuilder private func ecran(_ o: Onglet, moi: String) -> some View {
        switch o {
        case .accueil: AccueilView(moi: moi)
        case .calendrier: CalendrierView(moi: moi)
        case .voyages: IdeesView(genre: "voyage", moi: moi)
        case .cuisine: CuisineView(moi: moi)
        case .weekends: IdeesView(genre: "weekend", moi: moi)
        case .chezNous: ChezNousView(moi: moi) { self.moi = nil; Base.moi = nil }
        }
    }

    private func noterVisite(_ moi: String) {
        let anciennes = (try? ctx.fetch(FetchDescriptor<Visite>(predicate: #Predicate { $0.membre == moi }))) ?? []
        anciennes.forEach(ctx.delete)
        ctx.insert(Visite(membre: moi))
        ctx.enregistrer()
    }
}

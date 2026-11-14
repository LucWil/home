import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Chez nous : le jardin (récoltes pesées, heures passées) et les réglages de l'app
/// (reprendre une sauvegarde de l'app web, changer d'aimant).
struct ChezNousView: View {
    let moi: String
    let changerDeMembre: () -> Void
    @Environment(\.modelContext) private var ctx
    @EnvironmentObject private var synchro: SynchroFamille
    @Query(sort: \DocumentBrut.cree, order: .reverse) private var docs: [DocumentBrut]
    @State private var importer = false
    @State private var bilan: String?
    @State private var confirmerChangement = false
    @State private var alertes = Alertes.actives

    private var foyer: String { Famille.foyer(de: moi) ?? "" }
    private func de(_ c: String) -> [[String: Any]] { docs.filter { $0.collection == c && $0.foyer == foyer }.map(\.valeurs) }

    var body: some View {
        List {
            Section {
                NavigationLink { WeekendMaisonView() } label: {
                    Label("Week-end à la maison · 8 h + 4 h", systemImage: "hammer")
                }
            } footer: { Text("Planifie tes tâches et tes peintures : l'écran dit quand chacune sera finie.") }

            Section {
                NavigationLink { PresDeChezNousView(moi: moi) } label: {
                    Label("Près de chez nous : marchés, activités, pharmacie de garde", systemImage: "location.north.circle")
                }
                NavigationLink { FrejusPlacardsView(moi: moi) } label: {
                    Label("Les placards de Fréjus", systemImage: "sun.max")
                }
            } footer: { Text("Armoires, frigo, congélateur, vaisselle : l'inventaire à l'arrivée, le départ, et ce qu'il faut racheter.") }

            Section {
                NavigationLink { Kit72View(moi: moi) } label: {
                    Label("Kit 72 heures", systemImage: "cross.case")
                }
            } footer: { Text("Tenir 3 jours sans courant, sans eau ni chauffage : la liste, notre plan et nos retours d'expérience.") }

            partage

            Section("Le jardin") {
                let recoltes = de("harvest")
                let grammes = recoltes.reduce(0.0) { $0 + $1.nombre("g") }
                let valeur = recoltes.reduce(0.0) { $0 + $1.nombre("g") / 1000 * $1.nombre("pricekg") }
                let heures = de("work").reduce(0.0) { $0 + $1.nombre("h") }
                // trois chiffres côte à côte, ou l'un sous l'autre quand le texte est agrandi
                ViewThatFits(in: .horizontal) {
                    HStack { statsJardin(grammes, valeur, heures) }
                    VStack(alignment: .leading, spacing: 10) { statsJardin(grammes, valeur, heures) }
                }
                if recoltes.isEmpty && de("garden").isEmpty {
                    ContentUnavailableView("Le potager attend", systemImage: "leaf",
                        description: Text("Les récoltes et les heures passées au jardin, reprises de l'app web, apparaîtront ici."))
                }
                ForEach(Array(recoltes.prefix(15).enumerated()), id: \.offset) { _, r in
                    HStack {
                        Text(r.s("name")).bold()
                        Spacer()
                        Text("\(Int(r.nombre("g"))) g").monospacedDigit()
                        Text(r.s("date")).font(.willys(.caption)).foregroundStyle(.secondary)
                    }
                }
                ForEach(Array(de("garden").prefix(15).enumerated()), id: \.offset) { _, g in
                    HStack { Image(systemName: "leaf"); Text(g.s("name", g.s("nom"))); Spacer(); Text(g.s("date")).font(.willys(.caption)).foregroundStyle(.secondary) }
                }
            }

            Section {
                Button { importer = true } label: { Label("Reprendre une sauvegarde de l'app web", systemImage: "square.and.arrow.down") }
                if let bilan { Text(bilan).font(.willys(.footnote)).foregroundStyle(.secondary) }
            } header: { Text("Les données") } footer: {
                Text("Dans l'app web : Calendrier › La maison › Sauvegarde › Télécharger, ou le bouton « Données » du Coffre des Willys. Reprendre deux fois le même fichier ne crée pas de doublons.")
            }

            Section("Cet appareil") {
                HStack { Aimant(membre: moi, taille: 30); Text("Tu es \(Famille.membre(moi)?.nom ?? "") · foyer \(Famille.nomFoyer(foyer))") }
                Button("Changer d'aimant", role: .destructive) { confirmerChangement = true }
                    .confirmationDialog("Changer d'aimant sur cet appareil ?", isPresented: $confirmerChangement, titleVisibility: .visible) {
                        Button("Changer d'aimant", role: .destructive) { changerDeMembre() }
                    } message: {
                        Text("Les données restent ; l'app te redemandera qui tu es.")
                    }
            }
        }
        .navigationTitle("Chez nous")
        .fileImporter(isPresented: $importer, allowedContentTypes: [.json]) { resultat in
            do {
                let url = try resultat.get()
                let acces = url.startAccessingSecurityScopedResource()
                defer { if acces { url.stopAccessingSecurityScopedResource() } }
                bilan = try ImportSauvegarde(ctx: ctx).importer(Data(contentsOf: url)).description
                Base.rafraichirWidgets()
            } catch {
                bilan = "Import impossible : \(error.localizedDescription)"
            }
        }
    }
}

extension ChezNousView {
    @ViewBuilder fileprivate func statsJardin(_ grammes: Double, _ valeur: Double, _ heures: Double) -> some View {
        Stat(valeur: String(format: "%.1f kg", grammes / 1000), libelle: "récoltés")
        Stat(valeur: valeur.euros, libelle: "économisés")
        Stat(valeur: String(format: "%.0f h", heures), libelle: "au jardin")
    }

    /// La maison commune iCloud : Chouchou invite, les autres acceptent le lien une seule fois.
    @ViewBuilder var partage: some View {
        Section {
            switch synchro.etat {
            case .pasDeCompteICloud:
                Label("Connecte-toi à iCloud dans les Réglages de l'iPhone pour partager avec la famille.",
                      systemImage: "icloud.slash")
            case .enAttenteInvitation:
                Label("Pas encore dans la maison commune. Ouvre le lien d'invitation que Chouchou t'a envoyé (Messages ou WhatsApp).",
                      systemImage: "envelope.open")
            case .pret:
                Label {
                    Text(synchro.derniereSynchro.map { "Partagé avec la famille · à jour \($0.formatted(.relative(presentation: .named)))" }
                         ?? "Partagé avec la famille")
                } icon: {
                    Image(systemName: "checkmark.icloud").symbolEffect(.bounce, value: synchro.derniereSynchro)
                }
                .foregroundStyle(Theme.ok)
            case .erreur(let message):
                Label(message, systemImage: "exclamationmark.icloud").foregroundStyle(Theme.alerte)
            }
            if synchro.estProprietaire {
                Button { Task { await synchro.inviterLaFamille() } } label: {
                    Label("Inviter la famille", systemImage: "person.badge.plus")
                }
            }
            Toggle(isOn: Binding(get: { alertes }, set: { alertes = $0; Alertes.actives = $0; if $0 { Task { await Alertes.demanderAutorisation() } } })) {
                Label("Me prévenir quand quelqu'un range, mange ou prévoit quelque chose", systemImage: "bell.badge")
            }
            .tint(Theme.ok)
            Button { Task { await synchro.synchroniserMaintenant() } } label: {
                Label("Synchroniser maintenant", systemImage: "arrow.triangle.2.circlepath")
            }
        } header: { Text("Partage familial") } footer: {
            Text(synchro.estProprietaire
                 ? "La maison commune est dans ton iCloud. « Inviter la famille » envoie un lien à chacun ; ils n'ont qu'à le toucher une fois. Les IBAN restent sur cet appareil."
                 : "Toutes les données sont dans l'iCloud de Chouchou et partagées avec toute la famille. Accepter l'invitation une fois suffit pour l'iPhone et l'iPad.")
        }
    }
}

struct Stat: View {
    let valeur: String
    let libelle: String
    var body: some View {
        VStack(alignment: .leading) {
            Text(valeur).font(Theme.titre(20)).monospacedDigit()
            Text(libelle).font(.willys(.caption)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

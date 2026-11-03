import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Chez nous : le jardin (récoltes pesées, heures passées) et les réglages de l'app
/// (reprendre une sauvegarde de l'app web, changer d'aimant).
struct ChezNousView: View {
    let moi: String
    let changerDeMembre: () -> Void
    @Environment(\.modelContext) private var ctx
    @Query(sort: \DocumentBrut.cree, order: .reverse) private var docs: [DocumentBrut]
    @State private var importer = false
    @State private var bilan: String?

    private var foyer: String { Famille.foyer(de: moi) ?? "" }
    private func de(_ c: String) -> [[String: Any]] { docs.filter { $0.collection == c && $0.foyer == foyer }.map(\.valeurs) }

    var body: some View {
        List {
            Section("Le jardin") {
                let recoltes = de("harvest")
                let grammes = recoltes.reduce(0.0) { $0 + $1.nombre("g") }
                let valeur = recoltes.reduce(0.0) { $0 + $1.nombre("g") / 1000 * $1.nombre("pricekg") }
                let heures = de("work").reduce(0.0) { $0 + $1.nombre("h") }
                HStack {
                    Stat(valeur: String(format: "%.1f kg", grammes / 1000), libelle: "récoltés")
                    Stat(valeur: valeur.euros, libelle: "économisés")
                    Stat(valeur: String(format: "%.0f h", heures), libelle: "au jardin")
                }
                ForEach(Array(recoltes.prefix(15).enumerated()), id: \.offset) { _, r in
                    HStack {
                        Text(r.s("name")).bold()
                        Spacer()
                        Text("\(Int(r.nombre("g"))) g").monospacedDigit()
                        Text(r.s("date")).font(.caption).foregroundStyle(.secondary)
                    }
                }
                ForEach(Array(de("garden").prefix(15).enumerated()), id: \.offset) { _, g in
                    HStack { Image(systemName: "leaf"); Text(g.s("name", g.s("nom"))); Spacer(); Text(g.s("date")).font(.caption).foregroundStyle(.secondary) }
                }
            }

            Section {
                Button { importer = true } label: { Label("Reprendre une sauvegarde de l'app web", systemImage: "square.and.arrow.down") }
                if let bilan { Text(bilan).font(.footnote).foregroundStyle(.secondary) }
            } header: { Text("Les données") } footer: {
                Text("Dans l'app web : Calendrier › La maison › Sauvegarde › Télécharger, ou le bouton « Données » du Coffre des Willys. Reprendre deux fois le même fichier ne crée pas de doublons.")
            }

            Section("Cet appareil") {
                HStack { Aimant(membre: moi, taille: 30); Text("Tu es \(Famille.membre(moi)?.nom ?? "") · foyer \(Famille.nomFoyer(foyer))") }
                Button("Changer d'aimant", role: .destructive) { changerDeMembre() }
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

struct Stat: View {
    let valeur: String
    let libelle: String
    var body: some View {
        VStack(alignment: .leading) {
            Text(valeur).font(.system(size: 20, weight: .heavy, design: .rounded)).monospacedDigit()
            Text(libelle).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

import SwiftUI
import SwiftData

/// Le week-end à la maison : 8 h le samedi, 4 h le dimanche. On y met les choses à faire, dans l'ordre ;
/// l'écran les range dans les créneaux, dit quand chacune sera finie et ce qui reste de temps libre.
struct WeekendMaisonView: View {
    @Environment(\.modelContext) private var ctx
    @Environment(\.colorScheme) private var scheme
    @Query(sort: \TacheMaison.ordre) private var taches: [TacheMaison]
    @State private var feuille: Feuille?

    enum Feuille: String, Identifiable { case tache, peinture; var id: String { rawValue } }

    private var plan: Plan { PlanWeekend.repartir(taches) }
    private let fr = Locale(identifier: "fr_BE")

    var body: some View {
        let p = plan
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                vueCreneaux(p)
                listeTaches(p)
                if !taches.isEmpty { tempsLibre(p) }
            }
            .padding(16)
        }
        .background(Theme.emaille(scheme))
        .navigationTitle("Week-end à la maison")
        .toolbar {
            ToolbarItem {
                Menu {
                    Button("Une tâche", systemImage: "hammer") { feuille = .tache }
                    Button("Une peinture", systemImage: "paintbrush") { feuille = .peinture }
                } label: { Label("Ajouter", systemImage: "plus") }
            }
        }
        .sheet(item: $feuille) { f in
            NavigationStack {
                switch f {
                case .tache: FormulaireTacheMaison(ordre: (taches.map(\.ordre).max() ?? 0) + 1)
                case .peinture: FormulairePeinture(ordre: (taches.map(\.ordre).max() ?? 0) + 1)
                }
            }
        }
    }

    // MARK: Les créneaux

    private func vueCreneaux(_ p: Plan) -> some View {
        let prochains = Array(p.creneaux.prefix(4))
        return VStack(alignment: .leading, spacing: 10) {
            TitreSection("Le temps dont tu disposes")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                ForEach(prochains) { c in
                    let u = p.utilise(c)
                    Porte(teinte: c.estSamedi ? Theme.accent : nil) {
                        Text("\(c.nom) \(c.date.formatted(.dateTime.day().month(.abbreviated).locale(fr)))")
                            .font(.willys(.footnote, poids: .bold))
                        Text("\(heuresTexte(u)) / \(heuresTexte(c.capacite))").font(Theme.titre(20)).monospacedDigit()
                        ProgressView(value: min(u, c.capacite), total: c.capacite)
                            .tint(u >= c.capacite ? Theme.alerte : Theme.ok)
                        Text(p.reste(c) > 0 ? "Libre : \(heuresTexte(p.reste(c)))" : "Complet")
                            .font(.willys(.caption)).foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    // MARK: Les tâches

    private func listeTaches(_ p: Plan) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            TitreSection("À faire, dans l'ordre")
            if taches.isEmpty {
                ContentUnavailableView("Rien de prévu", systemImage: "hammer",
                    description: Text("Ajoute une tâche ou une peinture avec le bouton +. L'écran calcule quand ce sera fini."))
            } else {
                Porte {
                    ForEach(Array(taches.enumerated()), id: \.element.id) { i, t in
                        if i > 0 { Divider() }
                        ligne(t, p)
                    }
                }
            }
        }
    }

    private func ligne(_ t: TacheMaison, _ p: Plan) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Button {
                Retour.succes(); avecAnimation { t.fait.toggle(); ctx.enregistrer() }
            } label: {
                Image(systemName: t.fait ? "checkmark.circle.fill" : "circle").font(.title2)
                    .foregroundStyle(t.fait ? Theme.ok : .secondary).frame(width: 44, height: 44)
            }
            .accessibilityLabel(t.fait ? "Marquer comme à faire" : "Marquer comme fait")
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: t.estPeinture ? "paintbrush.fill" : "hammer.fill").foregroundStyle(Theme.accent)
                    Text(t.titre).bold().strikethrough(t.fait)
                }
                Text(detail(t)).font(.willys(.footnote)).foregroundStyle(.secondary)
                if !t.fait {
                    ForEach(p.morceaux(de: t.cle)) { m in
                        let c = p.creneaux[m.creneau]
                        Text("\(c.nom) \(c.date.formatted(.dateTime.day().month(.abbreviated).locale(fr))) · \(heuresTexte(m.heures))")
                            .font(.willys(.footnote, poids: .semibold))
                    }
                    if let fin = p.fin[t.cle] {
                        Label("Fini le \(fin.date.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(fr)))",
                              systemImage: "flag.checkered").font(.willys(.footnote, poids: .bold)).foregroundStyle(Theme.ok)
                    } else {
                        Label("Ne tient pas dans les six prochains mois", systemImage: "exclamationmark.triangle")
                            .font(.willys(.footnote)).foregroundStyle(Theme.alerte)
                    }
                }
            }
            Spacer(minLength: 0)
            Menu {
                if t.ordre > (taches.first?.ordre ?? 0) { Button("Passer avant", systemImage: "arrow.up") { echanger(t, -1) } }
                if t.ordre < (taches.last?.ordre ?? 0) { Button("Passer après", systemImage: "arrow.down") { echanger(t, 1) } }
                Button("Retirer", systemImage: "trash", role: .destructive) { avecAnimation { ctx.delete(t); ctx.enregistrer() } }
            } label: { Image(systemName: "ellipsis.circle").font(.title3).frame(width: 44, height: 44) }
            .accessibilityLabel("Autres actions")
        }
    }

    private func detail(_ t: TacheMaison) -> String {
        guard t.estPeinture else { return heuresTexte(t.heures) + " de travail" }
        let e = Peinture.estimer(surface: t.surface, plafond: t.surfacePlafond, couches: t.couches, sousCouche: t.sousCouche)
        let m2 = Int((t.surface + t.surfacePlafond).rounded())
        return "\(m2) m² · \(e.couchesTotales) couche\(e.couchesTotales > 1 ? "s" : "") · \(heuresTexte(t.heures)) de travail"
            + (e.attente > 0 ? " + \(heuresTexte(e.attente)) de séchage" : "") + " · ≈ \(e.litres.formatted()) L"
    }

    private func echanger(_ t: TacheMaison, _ sens: Int) {
        let l = taches
        guard let i = l.firstIndex(where: { $0.id == t.id }), l.indices.contains(i + sens) else { return }
        Retour.leger()
        avecAnimation { let a = l[i].ordre; l[i].ordre = l[i + sens].ordre; l[i + sens].ordre = a; ctx.enregistrer() }
    }

    // MARK: Utiliser le temps qui reste

    private func tempsLibre(_ p: Plan) -> some View {
        let premierLibre = p.creneaux.first { p.reste($0) > 0.0001 }
        return VStack(alignment: .leading, spacing: 10) {
            TitreSection("Utiliser le temps qui reste")
            if let c = premierLibre {
                let h = p.reste(c)
                let idees = IdeesDeTemps.quiTiennent(dans: h)
                Porte {
                    Text("Il te reste \(heuresTexte(h)) le \(c.nom.lowercased()) \(c.date.formatted(.dateTime.day().month(.wide).locale(fr))).")
                        .font(.willys(.headline))
                    if idees.isEmpty { Text("Trop court pour une tâche : profite !").foregroundStyle(.secondary) }
                    FlowLayout(spacing: 8) {
                        ForEach(idees, id: \.titre) { i in
                            Button {
                                Retour.leger()
                                avecAnimation {
                                    ctx.insert(TacheMaison(titre: i.titre, heures: i.heures, ordre: (taches.map(\.ordre).max() ?? 0) + 1))
                                    ctx.enregistrer()
                                }
                            } label: {
                                Text("\(i.titre) · \(heuresTexte(i.heures))").font(.willys(.subheadline, poids: .semibold))
                                    .padding(.horizontal, 12).frame(minHeight: 44)
                                    .background(Theme.accent.opacity(0.25), in: Capsule())
                            }
                            .buttonStyle(StyleAimant())
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Formulaires

struct FormulaireTacheMaison: View {
    let ordre: Int
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var fermer
    @State private var titre = ""
    @State private var heures = 2.0

    var body: some View {
        Form {
            TextField("Qu'y a-t-il à faire ?", text: $titre)
            Stepper(value: $heures, in: 0.5...16, step: 0.5) { Text("Temps : \(heuresTexte(heures))") }
        }
        .navigationTitle("Une tâche")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Annuler") { fermer() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Ajouter") {
                    ctx.insert(TacheMaison(titre: titre.trimmingCharacters(in: .whitespaces), heures: heures, ordre: ordre))
                    ctx.enregistrer(); Retour.succes(); fermer()
                }
                .disabled(titre.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }
}

struct FormulairePeinture: View {
    let ordre: Int
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var fermer
    @State private var piece = ""
    @State private var murs = 30.0
    @State private var plafond = 0.0
    @State private var couches = 2
    @State private var sousCouche = false

    private var estimation: Peinture.Estimation {
        Peinture.estimer(surface: murs, plafond: plafond, couches: couches, sousCouche: sousCouche)
    }

    var body: some View {
        Form {
            Section("La pièce") {
                TextField("Ex. salon, chambre de Robin", text: $piece)
                Stepper(value: $murs, in: 0...300, step: 5) { Text("Murs : \(Int(murs)) m²") }
                Stepper(value: $plafond, in: 0...100, step: 5) { Text("Plafond : \(Int(plafond)) m²") }
            }
            Section("La peinture") {
                Stepper(value: $couches, in: 1...4) { Text("\(couches) couche\(couches > 1 ? "s" : "")") }
                Toggle("Sous-couche d'abord", isOn: $sousCouche)
            }
            Section {
                ligne("Préparation (bâches, adhésif, rebouchage)", estimation.preparation)
                ligne("Application, bords compris", estimation.application)
                ligne("Nettoyage et rangement", estimation.nettoyage)
                HStack { Text("Temps de travail").bold(); Spacer(); Text(heuresTexte(estimation.travail)).bold().monospacedDigit() }
                if estimation.attente > 0 {
                    HStack { Text("Séchage entre les couches"); Spacer(); Text(heuresTexte(estimation.attente)).monospacedDigit() }
                        .foregroundStyle(.secondary)
                }
                HStack { Text("Peinture à prévoir"); Spacer(); Text("≈ \(estimation.litres.formatted()) L").monospacedDigit() }
            } header: { Text("Prévision") } footer: {
                Text("Repères de bricoleur : environ 7 m² par heure et par couche au rouleau, 10 m² par litre. Pendant le séchage, tu peux faire autre chose.")
            }
        }
        .navigationTitle("Une peinture")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Annuler") { fermer() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Ajouter") {
                    let nom = piece.trimmingCharacters(in: .whitespaces)
                    ctx.insert(TacheMaison(peinture: nom.isEmpty ? "Peinture" : "Peindre : \(nom)", surface: murs,
                                           surfacePlafond: plafond, couches: couches, sousCouche: sousCouche, ordre: ordre))
                    ctx.enregistrer(); Retour.succes(); fermer()
                }
                .disabled(murs + plafond == 0)
            }
        }
    }

    private func ligne(_ t: String, _ h: Double) -> some View {
        HStack { Text(t); Spacer(); Text(heuresTexte((h * 2).rounded() / 2)).monospacedDigit() }.foregroundStyle(.secondary)
    }
}

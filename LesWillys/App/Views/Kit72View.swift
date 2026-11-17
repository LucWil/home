import SwiftUI
import SwiftData

/// Le kit 72 heures du foyer : la liste à cocher, le plan familial, l'essai « sans courant » et les retours d'expérience.
struct Kit72View: View {
    let moi: String
    @Environment(\.modelContext) private var ctx
    @Query private var kits: [KitFoyer]
    @Query private var elements: [ElementKit]
    @Query(sort: \NoteKit.cree, order: .reverse) private var notes: [NoteKit]
    @State private var foyer: String = ""
    @State private var note = ""

    private var kit: KitFoyer? { kits.first { $0.cle == foyer } }
    private var personnes: Int { max(1, kit?.personnes ?? (Famille.foyers.first { $0.id == foyer }?.membres.count ?? 2)) }

    var body: some View {
        let sc = Kit72.score(elements, foyer: foyer)
        let bientot = Kit72.aRenouveler(elements, foyer: foyer)
        List {
            Section {
                Picker("Foyer", selection: $foyer) { ForEach(Famille.foyers, id: \.id) { Text($0.nom).tag($0.id) } }
                    .pickerStyle(.segmented)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Prêts à \(sc) %").font(Theme.titre(24))
                    ProgressView(value: Double(sc), total: 100).tint(sc >= 80 ? Theme.ok : sc >= 40 ? Theme.accent : .orange)
                }
                Stepper("Nous sommes \(personnes) à la maison", value: Binding(get: { personnes }, set: { n in modifierKit { $0.personnes = n } }), in: 1...12)
                ForEach(bientot) { e in
                    Label("\(Kit72.libelle(e.element)) : \(e.exp < Jour.aujourdhui ? "périmé" : "à renouveler avant le \(Jour.joli(e.exp, .dateTime.day().month(.abbreviated)))")",
                          systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange).font(.willys(.subheadline, poids: .semibold))
                }
            } footer: {
                Text("Le Centre national de crise demande à chaque foyer de pouvoir tenir 72 heures seul : de l'eau, de quoi manger sans cuisiner, de la lumière, une radio, des médicaments et un peu d'argent liquide. Pas de panique : on coche petit à petit, on fait tourner les réserves, et on se raconte ce qui marche.")
            }

            ForEach(Kit72.groupes, id: \.titre) { g in
                let n = g.choses.filter { c in elements.contains { $0.foyer == foyer && $0.element == c.id && $0.ok } }.count
                Section {
                    DisclosureGroup {
                        ForEach(g.choses) { c in
                            LigneKit(chose: c, foyer: foyer, personnes: personnes, moi: moi, element: elements.first { $0.cle == foyer + "_" + c.id })
                                .id(foyer + c.id)
                        }
                    } label: {
                        HStack { Text(g.titre).font(.willys(.headline)); Spacer(); Text("\(n) / \(g.choses.count)").foregroundStyle(n == g.choses.count ? Theme.ok : .secondary) }
                    }
                }
            }

            PlanKit(kit: kit, foyer: foyer, moi: moi)

            Section {
                HStack {
                    TextField("Ex. les packs d'eau sont en promo jusqu'à samedi", text: $note, axis: .vertical)
                    Button("Partager") {
                        let t = note.trimmingCharacters(in: .whitespacesAndNewlines); guard !t.isEmpty else { return }
                        ctx.insert(NoteKit(texte: t, foyer: Famille.foyer(de: moi) ?? foyer, par: moi)); ctx.enregistrer(); note = ""; Retour.succes()
                    }
                    .disabled(note.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                if notes.isEmpty { Text("Rien encore. Le premier conseil est pour toi.").foregroundStyle(.secondary) }
                ForEach(notes.prefix(20)) { n in
                    HStack(alignment: .top, spacing: 10) {
                        Aimant(membre: n.par, taille: 26)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(n.texte)
                            Text("\(Famille.membre(n.par)?.nom ?? "") · \(n.cree.formatted(.dateTime.day().month(.abbreviated).locale(Locale(identifier: "fr_BE"))))")
                                .font(.willys(.caption)).foregroundStyle(.secondary)
                        }
                    }
                    .swipeActions { if n.par == moi { Button("Supprimer", role: .destructive) { ctx.delete(n); ctx.enregistrer() } } }
                }
            } header: { Text("Nos retours d'expérience") } footer: { Text("Ce qui a marché, une bonne adresse, un conseil : visible par toute la famille.") }

            Section { EmptyView() } footer: {
                Text("D'après les conseils du Centre national de crise (campagne « Préparés ensemble ») et de la Commission européenne. Cette liste est un point de départ, à adapter à votre famille.")
            }
        }
        .navigationTitle("Kit 72 heures")
        .onAppear { if foyer.isEmpty { foyer = Famille.foyer(de: moi) ?? Famille.foyers[0].id } }
    }

    private func modifierKit(_ f: (KitFoyer) -> Void) {
        let k: KitFoyer
        if let x = kit { k = x } else { k = KitFoyer(foyer: foyer, personnes: personnes); ctx.insert(k) }
        f(k); k.par = moi; k.quand = .now
        ctx.enregistrer()
    }
}

/// Une chose de la liste : cochée ou non, ce qu'on a, et la date pour ce qui périme.
private struct LigneKit: View {
    let chose: ChoseKit
    let foyer: String
    let personnes: Int
    let moi: String
    let element: ElementKit?
    @Environment(\.modelContext) private var ctx
    @State private var qte = ""

    var body: some View {
        let ok = element?.ok == true
        VStack(alignment: .leading, spacing: 6) {
            Button {
                modifier { $0.ok.toggle() }; Retour.leger()
            } label: {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: ok ? "checkmark.circle.fill" : "circle").font(.title3).foregroundStyle(ok ? Theme.ok : .secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(chose.libelle).font(.willys(.body, poids: .semibold))
                        Text("conseillé : \(chose.quantite(personnes))").font(.willys(.caption)).foregroundStyle(.secondary)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityValue(ok ? "coché" : "pas coché")
            if !chose.conseil.isEmpty { Text(chose.conseil).font(.willys(.caption)).foregroundStyle(.secondary) }
            TextField("ce qu'on a (ex. 2 packs de 6 × 1,5 L)", text: $qte)
                .font(.willys(.subheadline)).textFieldStyle(.roundedBorder)
                .onSubmit { modifier { $0.qte = qte } }
            if chose.date && ok {
                DatePicker(element?.exp.isEmpty != false ? "À consommer avant (à choisir)" : "À consommer avant",
                           selection: Binding(get: { element.flatMap { $0.exp.isEmpty ? nil : Jour.date($0.exp) } ?? Date.now.addingTimeInterval(365 * 86400) },
                                              set: { d in modifier { $0.exp = Jour.chaine(d) } }),
                           displayedComponents: .date)
                    .font(.willys(.subheadline))
                    .environment(\.locale, Locale(identifier: "fr_BE"))
            }
        }
        .padding(.vertical, 4)
        .onAppear { qte = element?.qte ?? "" }
    }

    private func modifier(_ f: (ElementKit) -> Void) {
        let e: ElementKit
        if let x = element { e = x } else { e = ElementKit(foyer: foyer, element: chose.id); ctx.insert(e) }
        f(e); e.par = moi; e.quand = .now
        ctx.enregistrer()
    }
}

/// Le plan familial et l'essai « sans courant ».
private struct PlanKit: View {
    let kit: KitFoyer?
    let foyer: String
    let moi: String
    @Environment(\.modelContext) private var ctx
    @State private var rdv = ""
    @State private var rdv2 = ""
    @State private var petites = ""
    @State private var contacts = ""
    @State private var radio = ""
    @State private var essaiDate = Date.now
    @State private var essaiFait = false
    @State private var essaiDuree = ""
    @State private var essaiBilan = ""

    var body: some View {
        Section {
            TextField("Si on est séparés, on se retrouve où ?", text: $rdv, axis: .vertical)
            TextField("Et si la maison n'est pas accessible ?", text: $rdv2, axis: .vertical)
            TextField("Qui va chercher les petites à l'école ?", text: $petites, axis: .vertical)
            TextField("Les numéros à garder : 112, médecin, voisins, famille", text: $contacts, axis: .vertical).lineLimit(2...6)
            TextField("La radio à écouter (ex. La Première, Radio 1)", text: $radio)
            Button("Enregistrer le plan") {
                enregistrer { $0.rdv = rdv; $0.rdv2 = rdv2; $0.petites = petites; $0.contacts = contacts; $0.radio = radio }
            }
        } header: { Text("Notre plan") } footer: { Text("À décider ensemble, au calme, et à écrire aussi sur papier.") }

        Section {
            Toggle("On a fait un essai", isOn: $essaiFait)
            if essaiFait {
                DatePicker("Le", selection: $essaiDate, displayedComponents: .date).environment(\.locale, Locale(identifier: "fr_BE"))
                TextField("Combien de temps (ex. une soirée, 24 h)", text: $essaiDuree)
                TextField("Ce qu'on en retient", text: $essaiBilan, axis: .vertical).lineLimit(2...6)
                Button("Noter l'essai") {
                    enregistrer { $0.essaiDate = Jour.chaine(essaiDate); $0.essaiDuree = essaiDuree; $0.essaiBilan = essaiBilan }
                }
            }
        } header: { Text("On a essayé") } footer: { Text("Une soirée ou un week-end « sans courant » en famille : le meilleur moyen de voir ce qui manque.") }
        .onAppear(perform: charger)
        .onChange(of: foyer) { charger() }
    }

    private func charger() {
        rdv = kit?.rdv ?? ""; rdv2 = kit?.rdv2 ?? ""; petites = kit?.petites ?? ""; contacts = kit?.contacts ?? ""; radio = kit?.radio ?? ""
        essaiFait = !(kit?.essaiDate ?? "").isEmpty
        essaiDate = kit.flatMap { $0.essaiDate.isEmpty ? nil : Jour.date($0.essaiDate) } ?? .now
        essaiDuree = kit?.essaiDuree ?? ""; essaiBilan = kit?.essaiBilan ?? ""
    }

    private func enregistrer(_ f: (KitFoyer) -> Void) {
        let k: KitFoyer
        if let x = kit { k = x } else {
            k = KitFoyer(foyer: foyer, personnes: Famille.foyers.first { $0.id == foyer }?.membres.count ?? 2); ctx.insert(k)
        }
        f(k); k.par = moi; k.quand = .now
        ctx.enregistrer(); Retour.succes()
    }
}

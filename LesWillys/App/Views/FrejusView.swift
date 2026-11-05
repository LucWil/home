import SwiftUI
import SwiftData

/// Les placards de la maison de Fréjus : l'inventaire à l'arrivée, la vaisselle et la maison,
/// le départ, et la liste à racheter. Le stock lui-même se range et se mange dans l'onglet Cuisine.
struct FrejusPlacardsView: View {
    let moi: String
    @Environment(\.modelContext) private var ctx
    @Environment(\.openURL) private var ouvrir
    @Query(sort: \Article.nom) private var stock: [Article]
    @Query(sort: \ObjetMaison.objet) private var objets: [ObjetMaison]
    @Query(sort: \ARacheter.cree) private var liste: [ARacheter]
    @Query private var evenements: [Evenement]
    @AppStorage(Frejus.cleLieu, store: Base.reglages) private var lieu = ""
    @State private var feuille: Feuille?
    @State private var nouveau = ""

    enum Feuille: String, Identifiable { case inventaire, maison, depart; var id: String { rawValue } }

    private var placards: [Article] { stock.filter { $0.foyer == Frejus.cle } }
    private var sejour: Evenement? { Frejus.sejour(evenements, moi: moi) }

    var body: some View {
        List {
            Section {
                if let s = sejour {
                    Label("Vous êtes à Fréjus jusqu'au \(Jour.joli(s.fin, .dateTime.day().month(.wide)))", systemImage: "sun.max")
                        .font(.willys(.headline))
                } else if let p = Frejus.prochain(evenements) {
                    Label("Prochain séjour le \(Jour.joli(p.debut, .dateTime.day().month(.wide)))", systemImage: "calendar")
                }
                compteur("Les armoires", .armoire, "cabinet")
                compteur("Le frigo", .frais, "refrigerator")
                compteur("Le congélateur", .surgelateur, "snowflake")
                let alertes = placards.filter { Frejus.alerte($0) != nil }
                if !alertes.isEmpty {
                    Label("\(alertes.count) à vérifier : \(alertes.prefix(4).map(\.nom).joined(separator: ", "))", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(Theme.alerte)
                }
            } footer: {
                Text("Pendant un séjour au calendrier, l'onglet Cuisine passe tout seul sur Fréjus : ce qu'on range, mange ou cuisine compte pour ces placards. Le boni reste celui de ton foyer.")
            }

            Section("Le séjour") {
                etape("1. Les placards à l'arrivée", "Toujours là, entamé, plus là, et ce qu'on trouve en plus.", "Faire l'inventaire", .inventaire)
                etape("2. La vaisselle et la maison", objets.isEmpty ? "Commencer avec la liste type d'une maison de vacances." : "Compter : ce qui manque part dans la liste à racheter.", objets.isEmpty ? "Commencer la liste" : "Compter", .maison)
                etape("3. Avant de partir", "Vider le frigo, repérer ce qui sera périmé au prochain séjour.", "Préparer le départ", .depart)
            }

            Section {
                ForEach(liste) { a in
                    HStack { Aimant(membre: a.par, taille: 22); Text(a.nom) }
                        .swipeActions { Button("Acheté", systemImage: "checkmark") { avecAnimation { ctx.delete(a); ctx.enregistrer() } }.tint(Theme.ok) }
                }
                HStack {
                    TextField("Ajouter (ex. huile d'olive, sacs poubelle)", text: $nouveau).onSubmit(ajouter)
                    Button("Ajouter", action: ajouter).disabled(nouveau.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                if !liste.isEmpty {
                    ShareLink(item: "À racheter pour Fréjus : " + liste.map(\.nom).joined(separator: ", ")) {
                        Label("Envoyer la liste", systemImage: "square.and.arrow.up")
                    }
                }
            } header: { Text("À racheter pour Fréjus") } footer: {
                Text("Ce qu'on finit dans les armoires et ce qui manque à l'inventaire arrive ici tout seul. Glisse vers la gauche quand c'est acheté.")
            }
        }
        .navigationTitle("Les placards de Fréjus")
        .sheet(item: $feuille) { f in
            NavigationStack {
                switch f {
                case .inventaire: InventaireFrejus(moi: moi, articles: placards)
                case .maison: if objets.isEmpty { ListeTypeFrejus(moi: moi, deja: []) } else { ComptageMaison(moi: moi, objets: objets) }
                case .depart: DepartFrejus(moi: moi, articles: placards, prochain: Frejus.prochain(evenements))
                }
            }
        }
    }

    private func compteur(_ nom: String, _ r: Rangement, _ icone: String) -> some View {
        Button {
            lieu = Frejus.cle
            ouvrir(URL(string: "willys://cuisine")!)
        } label: {
            LabeledContent { Text("\(placards.filter { $0.rangement == r.rawValue }.count)").monospacedDigit() } label: { Label(nom, systemImage: icone) }
        }
        .accessibilityHint("Ouvre la cuisine de Fréjus")
    }

    private func etape(_ titre: String, _ texte: String, _ bouton: String, _ f: Feuille) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(titre).font(.willys(.headline))
            Text(texte).font(.willys(.footnote)).foregroundStyle(.secondary)
            Button(bouton) { feuille = f }.buttonStyle(.borderedProminent).buttonBorderShape(.capsule)
        }
        .padding(.vertical, 4)
    }

    private func ajouter() {
        let noms = nouveau.split(separator: ",").map(String.init)
        Frejus.aRacheter(noms, par: moi, dans: ctx); ctx.enregistrer()
        nouveau = ""; Retour.succes()
    }
}

/// L'inventaire d'arrivée, armoire par armoire : ce qui demande un coup d'œil est en haut.
struct InventaireFrejus: View {
    let moi: String
    let articles: [Article]
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var fermer
    @State private var choix: [String: Choix] = [:]
    @State private var restes: [String: String] = [:]
    @State private var enPlus = ""
    @State private var rachat: [String]?

    enum Choix: String, CaseIterable { case la = "Là", entame = "Entamé", parti = "Plus là" }

    var body: some View {
        Form {
            ForEach([Rangement.armoire, .frais, .surgelateur]) { r in
                let l = articles.filter { $0.rangement == r.rawValue }
                    .sorted { (Frejus.alerte($0) == nil ? 1 : 0, $0.nom) < (Frejus.alerte($1) == nil ? 1 : 0, $1.nom) }
                if !l.isEmpty {
                    Section(r == .frais ? "Le frigo" : r == .surgelateur ? "Le congélateur" : "Les armoires") {
                        ForEach(l) { a in ligne(a) }
                    }
                }
            }
            Section {
                TextField("Une chose par ligne : 3 boîtes de thon, pâtes, glaçons au congélateur…", text: $enPlus, axis: .vertical)
                    .lineLimit(3...8)
            } header: { Text("Ce que je trouve en plus") } footer: {
                Text("Chaque ligne est rangée d'après son nom : le frigo pour les produits frais, le congélateur si tu écris « congelé » ou « glace », les armoires sinon.")
            }
        }
        .navigationTitle("L'inventaire")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Plus tard") { fermer() } }
            ToolbarItem(placement: .confirmationAction) { Button("Valider", action: valider) }
        }
        .sheet(item: Binding(get: { rachat.map(ListeNoms.init) }, set: { if $0 == nil { rachat = nil; fermer() } })) { l in
            NavigationStack { ChoixRachat(moi: moi, noms: l.noms, texte: "Ces articles ne sont plus là. Lesquels faut-il racheter ?") }
        }
    }

    private func ligne(_ a: Article) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(a.nom).bold() + Text(a.quantite.isEmpty ? "" : " · \(a.quantite)").foregroundColor(.secondary)
            if let al = Frejus.alerte(a) { Text(al).font(.willys(.footnote, poids: .semibold)).foregroundStyle(Theme.alerte) }
            Picker("État", selection: Binding(get: { choix[a.cle] ?? .la }, set: { choix[a.cle] = $0 })) {
                ForEach(Choix.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            if choix[a.cle] == .entame {
                TextField("Combien il en reste ?", text: Binding(get: { restes[a.cle] ?? a.quantite }, set: { restes[a.cle] = $0 }))
            }
        }
        .padding(.vertical, 2)
    }

    private func valider() {
        var partis: [String] = []
        for a in articles {
            switch choix[a.cle] ?? .la {
            case .parti: partis.append(a.nom); ctx.delete(a)
            case .entame:
                if let q = restes[a.cle], !q.isEmpty { a.quantite = q }
                a.verifie = Jour.aujourdhui
            case .la: a.verifie = Jour.aujourdhui
            }
        }
        for l in enPlus.split(separator: "\n").map({ $0.trimmingCharacters(in: .whitespaces) }) where !l.isEmpty {
            let (r, c) = Frejus.ranger(l)
            let a = Article(foyer: Frejus.cle, rangement: r, nom: l, categorie: c, par: moi)
            a.verifie = Jour.aujourdhui
            if r == .surgelateur { a.tiroir = 6 }
            ctx.insert(a)
        }
        ctx.enregistrer(); Base.rafraichirWidgets(); Retour.succes()
        if partis.isEmpty { fermer() } else { rachat = partis }
    }
}

struct ListeNoms: Identifiable { let noms: [String]; var id: String { noms.joined(separator: "|") } }

/// « À racheter ? » : on coche ce qui doit revenir à Fréjus.
struct ChoixRachat: View {
    let moi: String
    let noms: [String]
    let texte: String
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var fermer
    @State private var coches: Set<String> = []

    var body: some View {
        List {
            Section { ForEach(noms, id: \.self) { n in Toggle(n, isOn: Binding(get: { coches.contains(n) }, set: { if $0 { coches.insert(n) } else { coches.remove(n) } })) } } footer: { Text(texte) }
        }
        .navigationTitle("À racheter ?")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { coches = Set(noms) }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Rien") { fermer() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Ajouter") { Frejus.aRacheter(Array(coches), par: moi, dans: ctx); ctx.enregistrer(); Retour.succes(); fermer() }
            }
        }
    }
}

/// Compter la vaisselle et les objets : s'il en manque, l'objet passe « à remplacer ».
struct ComptageMaison: View {
    let moi: String
    let objets: [ObjetMaison]
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var fermer
    @State private var comptes: [String: Int] = [:]
    @State private var manques: [String]?
    @State private var listeType = false

    var body: some View {
        Form {
            ForEach(pieces, id: \.self) { p in
                Section(p) {
                    ForEach(objets.filter { $0.piece == p }) { o in
                        Stepper(value: Binding(get: { comptes[o.cle] ?? o.quantite }, set: { comptes[o.cle] = max(0, $0) }), in: 0...999) {
                            VStack(alignment: .leading) {
                                Text(o.objet).bold() + Text(" · \(comptes[o.cle] ?? o.quantite)").monospacedDigit()
                                Text("attendu : \(o.quantite)" + (o.vu.map { " · compté le \(Jour.joli($0, .dateTime.day().month()))" } ?? ""))
                                    .font(.willys(.caption)).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            Section { Button("Compléter avec la liste type") { listeType = true } }
        }
        .navigationTitle("La vaisselle et la maison")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Plus tard") { fermer() } }
            ToolbarItem(placement: .confirmationAction) { Button("Enregistrer", action: enregistrer) }
        }
        .sheet(isPresented: $listeType) { NavigationStack { ListeTypeFrejus(moi: moi, deja: objets.map(\.objet)) } }
        .sheet(item: Binding(get: { manques.map(ListeNoms.init) }, set: { if $0 == nil { manques = nil; fermer() } })) { l in
            NavigationStack { ChoixRachat(moi: moi, noms: l.noms, texte: "Il en manque. Que faut-il racheter ou remplacer ?") }
        }
    }

    private var pieces: [String] {
        let toutes = Frejus.pieces + objets.map(\.piece).filter { !Frejus.pieces.contains($0) }
        return Array(NSOrderedSet(array: toutes)).compactMap { $0 as? String }.filter { p in objets.contains { $0.piece == p } }
    }

    private func enregistrer() {
        var m: [String] = []
        for o in objets {
            let n = comptes[o.cle] ?? o.quantite
            o.compte = n; o.vu = Jour.aujourdhui
            if n < o.quantite { o.etat = "remplacer"; m.append("\(o.objet) (il en manque \(o.quantite - n))") }
            else if o.etat == "remplacer" { o.etat = "bon" }
        }
        ctx.enregistrer(); Retour.succes()
        if m.isEmpty { fermer() } else { manques = m }
    }
}

/// La liste type d'une maison de vacances : on coche ce qu'il y a et on corrige les nombres.
struct ListeTypeFrejus: View {
    let moi: String
    let deja: [String]
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var fermer
    @State private var retenus: [String: Int] = [:]     // "piece|objet" → nombre
    @State private var pret = false

    var body: some View {
        Form {
            ForEach(Frejus.listeType, id: \.piece) { p in
                let l = p.objets.filter { o in !deja.contains { Frejus.simple($0) == Frejus.simple(o.0) } }
                if !l.isEmpty {
                    Section(p.piece) {
                        ForEach(l, id: \.0) { o in
                            let k = p.piece + "|" + o.0
                            HStack {
                                Toggle(o.0, isOn: Binding(get: { retenus[k] != nil }, set: { retenus[k] = $0 ? o.1 : nil }))
                                if let n = retenus[k] {
                                    Stepper("\(n)", value: Binding(get: { n }, set: { retenus[k] = max(1, $0) }), in: 1...999).fixedSize()
                                        .monospacedDigit()
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("La liste type")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            guard !pret else { return }; pret = true
            for p in Frejus.listeType { for o in p.objets where !deja.contains(where: { Frejus.simple($0) == Frejus.simple(o.0) }) { retenus[p.piece + "|" + o.0] = o.1 } }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Annuler") { fermer() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Ajouter") {
                    for (k, n) in retenus {
                        let m = k.split(separator: "|", maxSplits: 1).map(String.init)
                        ctx.insert(ObjetMaison(objet: m[1], piece: m[0], quantite: n, par: moi))
                    }
                    ctx.enregistrer(); Retour.succes(); fermer()
                }
            }
        }
    }
}

/// Avant de partir : le frigo se vide, et ce qui périmera avant le prochain séjour est signalé.
struct DepartFrejus: View {
    let moi: String
    let articles: [Article]
    let prochain: Evenement?
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var fermer
    @State private var choix: [String: Choix] = [:]

    enum Choix: String, CaseIterable { case emporte = "Emporté", fini = "Fini", jete = "Jeté", garde = "Gardé" }

    private var limite: String { prochain?.debut ?? Jour.chaine(.now.addingTimeInterval(180 * 86400)) }
    private var frigo: [Article] { articles.filter { $0.rangement == "frais" } }
    private var bientot: [Article] { articles.filter { $0.rangement == "armoire" && ($0.peremption ?? "9999") < limite } }
    private var vieux: [Article] { articles.filter { $0.rangement == "surgelateur" && Jour.joursDepuis($0.depuis) > 240 } }

    var body: some View {
        Form {
            Section {
                Text(prochain.map { "Le prochain séjour commence le \(Jour.joli($0.debut, .dateTime.day().month(.wide)))." }
                     ?? "Pas encore de prochain séjour au calendrier : je regarde les six prochains mois.")
                Text("Ce qu'on emporte passe dans le stock de ton foyer.").foregroundStyle(.secondary)
            }
            groupe("Le frigo · il ne passera pas l'hiver", frigo, .emporte)
            groupe("Les armoires · périmé avant le prochain séjour", bientot, .emporte)
            groupe("Le congélateur · congelé depuis longtemps", vieux, .garde)
            if frigo.isEmpty && bientot.isEmpty && vieux.isEmpty {
                Section { Text("Rien à vider : le frigo est vide et rien ne périme d'ici le prochain séjour.") }
            }
        }
        .navigationTitle("Avant de partir")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Plus tard") { fermer() } }
            ToolbarItem(placement: .confirmationAction) { Button("C'est fait", action: valider) }
        }
    }

    @ViewBuilder private func groupe(_ titre: String, _ l: [Article], _ defaut: Choix) -> some View {
        if !l.isEmpty {
            Section(titre) {
                ForEach(l) { a in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(a.nom).bold() + Text(a.quantite.isEmpty ? "" : " · \(a.quantite)").foregroundColor(.secondary)
                        Picker("Que faire ?", selection: Binding(get: { choix[a.cle] ?? defaut }, set: { choix[a.cle] = $0 })) {
                            ForEach(Choix.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)
                    }
                    .onAppear { if choix[a.cle] == nil { choix[a.cle] = defaut } }
                }
            }
        }
    }

    private func valider() {
        let chez = Famille.foyer(de: moi) ?? ""
        for a in frigo + bientot + vieux {
            switch choix[a.cle] ?? .garde {
            case .emporte: a.foyer = chez
            case .fini: Cuisine.manger(a, par: moi, dans: ctx)
            case .jete: ctx.delete(a)
            case .garde: break
            }
        }
        ctx.enregistrer(); Base.rafraichirWidgets(); Retour.succes(); fermer()
    }
}

import SwiftUI
import SwiftData

/// La cuisine du foyer : ce qu'il faut manger vite, le frais, le surgélateur tiroir par tiroir,
/// les armoires, le carnet de recettes (avec le mode Thermomix) et les produits de saison.
struct CuisineView: View {
    let moi: String
    @Environment(\.modelContext) private var ctx
    @Environment(\.colorScheme) private var scheme
    @Query private var visites: [Visite]
    @Query(sort: \Article.nom) private var stock: [Article]
    @Query(sort: \Recette.cree, order: .reverse) private var recettes: [Recette]
    @State private var partie: Partie = .aManger
    @State private var ajout: Rangement?
    @State private var thermomix: Recette?
    @State private var boni = false
    @State private var recherche = ""
    @State private var aReclasser: Rangement?
    @State private var fermees: Set<String> = []     // les catégories repliées (toutes ouvertes au départ)

    enum Partie: String, CaseIterable, Identifiable {
        case aManger = "À manger", frais = "Le frais", surgelateur = "Surgélateur", armoire = "Armoires", recettes = "Recettes"
        var id: String { rawValue }
    }

    private var foyer: String { Famille.foyer(de: moi) ?? "" }
    private var monStock: [Article] {
        stock.filter { $0.foyer == foyer && (recherche.isEmpty || $0.nom.localizedCaseInsensitiveContains(recherche)) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                IciAussi(onglet: "cuisine", moi: moi, visites: visites)
                barreParties
                switch partie {
                case .aManger: aManger
                case .frais: liste(.frais)
                case .surgelateur: surgelateur
                case .armoire: liste(.armoire)
                case .recettes: carnet
                }
                saison
            }
            .padding(16)
        }
        .searchable(text: $recherche, prompt: "Chercher dans le stock")
        .background(Theme.emaille(scheme))
        .navigationTitle("Cuisine · \(Famille.nomFoyer(foyer))")
        .toolbar {
            ToolbarItem { Button { boni = true } label: { Label("Budget et boni", systemImage: "eurosign.circle") } }
            ToolbarItem { Button { ajout = partie == .surgelateur ? .surgelateur : partie == .armoire ? .armoire : .frais } label: { Label("Ranger quelque chose", systemImage: "plus") } }
        }
        .sheet(item: $ajout) { r in NavigationStack { FormulaireArticle(moi: moi, foyer: foyer, rangement: r) } }
        .sheet(isPresented: $boni) { NavigationStack { BoniView(moi: moi) } }
        .sheet(item: $aReclasser) { r in
            NavigationStack { ReclasserView(articles: monStock.filter { $0.rangement == r.rawValue }, rangement: r) }
        }
        .fullScreenCover(item: $thermomix) { ModeThermomix(recette: $0) }
    }

    /// Les cinq parties de la cuisine, en pastilles qu'on fait défiler (cinq segments tenaient mal sur iPhone).
    private var barreParties: some View {
        ScrollViewReader { lecteur in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Partie.allCases) { p in
                        Button {
                            Retour.selection(); avecAnimation { partie = p }
                        } label: {
                            Text(p.rawValue).font(.willys(.subheadline, poids: .bold))
                                .padding(.horizontal, 16).frame(minHeight: 44)
                                .background(partie == p ? Theme.accent : Theme.porte(scheme), in: Capsule())
                                .foregroundStyle(partie == p ? Color.black.opacity(0.85) : Color.primary)
                                .overlay(Capsule().strokeBorder(.primary.opacity(partie == p ? 0 : 0.1)))
                        }
                        .buttonStyle(StyleAimant())
                        .id(p)
                        .accessibilityAddTraits(partie == p ? .isSelected : [])
                    }
                }
                .padding(.vertical, 2)
            }
            .onChange(of: partie) { _, p in withAnimation(Anim.douce) { lecteur.scrollTo(p, anchor: .center) } }
        }
    }

    // MARK: À manger cette semaine

    private var aManger: some View {
        let urgents = monStock.compactMap { a -> (Article, Int)? in
            guard let j = a.joursRestants else { return nil }
            return j <= (a.rangement == "armoire" ? 14 : 2) ? (a, j) : nil
        }.sorted { $0.1 < $1.1 }.map { $0.0 }
        return Porte(teinte: Theme.accent) {
            Text("À manger cette semaine").font(Theme.titre(22))
            Text("Chaque produit mangé au lieu d'être racheté grossit le boni du foyer.").font(.willys(.subheadline)).foregroundStyle(.secondary)
            if urgents.isEmpty { Text("Rien qui presse. Bravo !").foregroundStyle(.secondary) }
            ForEach(urgents) { LigneArticle(article: $0, moi: moi) }
        }
    }

    /// Le frais et les armoires, rangés par catégorie : on voit ce qu'on a, et les catégories vides disent ce qui manque.
    private func liste(_ r: Rangement) -> some View {
        let articles = monStock.filter { $0.rangement == r.rawValue }
        let attendues = Categorie.attendues(dans: r.rawValue)
        // un article d'une catégorie inattendue (ou inconnue) est rangé dans « Autre »
        func categorie(_ a: Article) -> String { Categorie.toutes.contains { $0.id == a.categorie } ? a.categorie : "autre" }
        let ordre = attendues + Categorie.toutes.map(\.id).filter { !attendues.contains($0) }
        let groupes = ordre.map { id in
            (id: id, items: articles.filter { categorie($0) == id }
                .sorted { ($0.joursRestants ?? 9999, $0.nom) < ($1.joursRestants ?? 9999, $1.nom) })
        }
        let remplis = groupes.filter { !$0.items.isEmpty }
        let vides = groupes.filter { $0.items.isEmpty && attendues.contains($0.id) }
        return VStack(spacing: 12) {
            Porte {
                HStack {
                    Text(r.libelle).font(Theme.titre(22)); Spacer()
                    Text("\(articles.count) article\(articles.count > 1 ? "s" : "")").foregroundStyle(.secondary)
                }
                if articles.isEmpty { Text("Vide pour l'instant.").foregroundStyle(.secondary) }
                Button("Ranger quelque chose") { ajout = r }.buttonStyle(.bordered).frame(minHeight: 44)
            }
            let propositions = articles.filter { propositionPour($0, r) != nil }.count
            if propositions > 0 {
                Porte(teinte: Theme.accent) {
                    Text("\(propositions) article\(propositions > 1 ? "s" : "") à reclasser").font(.willys(.headline))
                    Text("D'après leur nom, ils iraient mieux dans une autre catégorie. Tu vérifies, puis tu appliques d'un coup.")
                        .font(.willys(.footnote)).foregroundStyle(.secondary)
                    Button("Voir les propositions") { aReclasser = r }.buttonStyle(.borderedProminent).frame(minHeight: 44)
                }
            }
            ForEach(remplis, id: \.id) { g in
                let urgents = g.items.filter { ($0.joursRestants ?? 99) <= (r == .armoire ? 14 : 1) }.count
                Porte {
                    DisclosureGroup(isExpanded: Binding(
                        get: { !fermees.contains(r.rawValue + g.id) },
                        set: { ouvert in
                            Retour.selection()
                            avecAnimation { if ouvert { fermees.remove(r.rawValue + g.id) } else { fermees.insert(r.rawValue + g.id) } }
                        })) {
                        ForEach(g.items) { LigneArticle(article: $0, moi: moi) }
                    } label: {
                        HStack(spacing: 10) {
                            Circle().fill(Categorie.couleur(g.id)).frame(width: 12, height: 12)
                            Text(Categorie.nom(g.id)).font(Theme.titre(18))
                            Spacer()
                            if urgents > 0 {
                                Text("\(urgents) à finir").font(.willys(.caption, poids: .bold)).foregroundStyle(Theme.alerte)
                            }
                            Text("\(g.items.count)").font(.willys(.subheadline, poids: .bold)).monospacedDigit().foregroundStyle(.secondary)
                        }
                        .frame(minHeight: 44)
                    }
                }
            }
            if !vides.isEmpty && !articles.isEmpty && recherche.isEmpty {
                Porte(teinte: Theme.alerte) {
                    Text("Il n'y en a pas").font(.willys(.headline))
                    Text("Aucun article dans ces catégories : c'est peut-être ce qui manque.")
                        .font(.willys(.footnote)).foregroundStyle(.secondary)
                    FlowLayout(spacing: 8) {
                        ForEach(vides, id: \.id) { g in
                            Label(Categorie.nom(g.id), systemImage: "exclamationmark.circle")
                                .font(.willys(.subheadline, poids: .semibold))
                                .padding(.horizontal, 12).padding(.vertical, 8)
                                .background(Theme.porte(scheme), in: Capsule())
                        }
                    }
                }
            }
        }
    }

    /// La catégorie proposée pour un article rangé dans « Autre » ou dans une catégorie qui n'existe pas à cet endroit.
    private func propositionPour(_ a: Article, _ r: Rangement) -> String? {
        ReclasserView.proposition(a, r)
    }

    /// Le surgélateur dessiné, tiroir par tiroir.
    private var surgelateur: some View {
        let articles = monStock.filter { $0.rangement == "surgelateur" }
        return VStack(spacing: 8) {
            ForEach(1...6, id: \.self) { t in
                let contenu = articles.filter { ($0.tiroir ?? 6) == t }
                DisclosureGroup {
                    ForEach(contenu) { LigneArticle(article: $0, moi: moi) }
                } label: {
                    HStack {
                        Text("Tiroir \(t)").font(Theme.titre(16))
                        Spacer()
                        Text("\(contenu.count) article\(contenu.count > 1 ? "s" : "")").font(.willys(.footnote)).foregroundStyle(.secondary)
                    }
                }
                .padding(14)
                .background(Theme.porte(scheme), in: RoundedRectangle(cornerRadius: 10))
                .overlay(alignment: .leading) {
                    Rectangle().fill(Categorie.couleur(contenu.first?.categorie ?? "")).frame(width: 7)
                        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 10, bottomLeadingRadius: 10))
                }
            }
        }
        .padding(10)
        .background(LinearGradient(colors: scheme == .dark ? [Color(hex: 0x26353F), Color(hex: 0x1A242C)] : [Color(hex: 0xCFE0E8), Color(hex: 0xAEC6D4)],
                                   startPoint: .top, endPoint: .bottom), in: RoundedRectangle(cornerRadius: 18))
    }

    // MARK: Recettes

    private var carnet: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 14)], spacing: 14) {
            ForEach(recettes.filter { recherche.isEmpty || $0.titre.localizedCaseInsensitiveContains(recherche) }) { r in
                Porte {
                    if let url = URL(string: r.photo), !r.photo.isEmpty {
                        AsyncImage(url: url) { $0.resizable().scaledToFill() } placeholder: { Color.secondary.opacity(0.15) }
                            .frame(height: 140).clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    HStack { Aimant(membre: r.par, taille: 24); Text(r.titre).font(Theme.titre(18)) }
                    if !r.intro.isEmpty { Text(r.intro).font(.willys(.subheadline)).foregroundStyle(.secondary) }
                    HStack {
                        Text(String(repeating: "€", count: max(1, r.cout))).bold().foregroundStyle(Theme.accent)
                        Text("· \(r.personnes) pers.").font(.willys(.footnote)).foregroundStyle(.secondary)
                        if r.envie { Etiquette(texte: "Envie", couleur: Theme.accent) }
                    }
                    if !r.ingredients.isEmpty {
                        DisclosureGroup("Ingrédients") { ForEach(r.ingredients, id: \.self) { Text("• \($0)").font(.willys(.subheadline)) } }
                    }
                    if !r.etapes.isEmpty {
                        Button("Mode Thermomix") { thermomix = r }.buttonStyle(.borderedProminent).tint(Color(hex: 0x2BA67F))
                    }
                }
            }
        }
    }

    private var saison: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("De saison en \(Date.now.formatted(.dateTime.month(.wide).locale(Locale(identifier: "fr_BE"))))").font(.willys(.headline))
            FlowLayout(spacing: 6) {
                ForEach(Saison.duMois, id: \.self) {
                    Text($0).font(.willys(.subheadline, poids: .semibold)).padding(.horizontal, 11).padding(.vertical, 3)
                        .background(Theme.porte(scheme), in: Capsule())
                }
            }
        }
        .padding(16)
        .background(LinearGradient(colors: [Theme.accent.opacity(0.3), Theme.porte(scheme)], startPoint: .leading, endPoint: .trailing),
                    in: RoundedRectangle(cornerRadius: 18))
    }
}

struct LigneArticle: View {
    let article: Article
    let moi: String
    @Environment(\.modelContext) private var ctx
    @Environment(\.horizontalSizeClass) private var largeur

    var body: some View {
        HStack(spacing: 10) {
            Circle().fill(Categorie.couleur(article.categorie)).frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 2) {
                Text(article.nom).bold() + Text(article.quantite.isEmpty ? "" : " · \(article.quantite)").foregroundColor(.secondary)
                Text(etat).font(.willys(.footnote)).foregroundStyle(urgent ? Theme.alerte : .secondary).fontWeight(urgent ? .semibold : .regular)
            }
            Spacer()
            // l'aimant de qui l'a rangé : plein s'il vient d'arriver, estompé sinon
            if largeur != .compact || nouveau { Aimant(membre: article.par, taille: 22).opacity(nouveau ? 1 : 0.55) }
            Button("Mangé", systemImage: "checkmark") {
                Retour.succes()
                avecAnimation { Cuisine.manger(article, par: moi, dans: ctx) }
                Base.rafraichirWidgets()
            }
            .buttonStyle(.borderedProminent).buttonBorderShape(.capsule).tint(Theme.ok)
            .font(.willys(.footnote, poids: .bold))
            .labelStyle(.titleAndIcon)
            .frame(minHeight: 44)
            .accessibilityHint("Retire \(article.nom) du stock et ajoute son prix au boni")
            Menu {
                Button("Jeté", role: .destructive) { jeter() }
                Button("Retirer sans compter", role: .destructive) {
                    avecAnimation { ctx.delete(article); ctx.enregistrer() }; Base.rafraichirWidgets()
                }
            } label: {
                Image(systemName: "ellipsis.circle").font(.title3).frame(width: 44, height: 44)
            }
            .accessibilityLabel("Autres actions")
        }
        .padding(.vertical, 2)
        .padding(.horizontal, nouveau ? 6 : 0)
        .background(nouveau ? Theme.accent.opacity(0.14) : .clear, in: RoundedRectangle(cornerRadius: 10))
        .animation(Anim.douce, value: nouveau)
        .transition(.sort)
    }

    /// Rangé par quelqu'un d'autre il y a moins de 30 minutes : surligné, pour qu'on le remarque.
    private var nouveau: Bool { article.par != moi && Date.now.timeIntervalSince(article.cree) < 30 * 60 }

    private var urgent: Bool { (article.joursRestants ?? 99) <= (article.rangement == "armoire" ? 14 : 1) }

    private var etat: String {
        let prix = article.prix > 0 ? " · \(article.prix.euros)" : ""
        switch article.rangement {
        case "surgelateur": return "congelé il y a \(Jour.joursDepuis(article.depuis)) j\(prix)"
        case "armoire":
            guard let p = article.peremption else { return "sans date\(prix)" }
            let j = Jour.joursJusqua(p)
            return (j < 0 ? "périmé depuis \(-j) j" : j == 0 ? "à consommer aujourd'hui" : "encore \(j) j") + prix
        default:
            let j = article.joursRestants ?? 0
            return (j < 0 ? "dépassé de \(-j) j" : j == 0 ? "à manger aujourd'hui" : "encore \(j) j") + prix
        }
    }

    /// Ce qui est jeté est noté (collection « waste ») : ça compte contre le boni du trimestre.
    private func jeter() {
        let d: [String: Any] = ["home": article.foyer, "name": article.nom, "value": article.prix, "by": moi,
                                "at": Date.now.timeIntervalSince1970 * 1000, "date": Jour.aujourdhui]
        let json = (try? JSONSerialization.data(withJSONObject: d)) ?? Data()
        ctx.insert(DocumentBrut(collection: "waste", cle: UUID().uuidString, json: json, foyer: article.foyer))
        Retour.avertissement()
        avecAnimation { ctx.delete(article); ctx.enregistrer() }
        Base.rafraichirWidgets()
    }
}

/// Le mode Thermomix : une étape à la fois, en grand, avec temps / température / vitesse.
struct ModeThermomix: View {
    let recette: Recette
    @Environment(\.dismiss) private var fermer
    @State private var i = 0

    var body: some View {
        let etapes = recette.etapes
        let e = etapes[min(i, etapes.count - 1)]
        VStack(spacing: 24) {
            HStack {
                Text(recette.titre).font(.willys(.headline))
                Spacer()
                Text("\(i + 1) / \(etapes.count)").monospacedDigit()
                Button("Fermer") { fermer() }.buttonStyle(.bordered)
            }
            ProgressView(value: Double(i + 1), total: Double(etapes.count)).tint(Color(hex: 0x4FD1A1))
            Spacer()
            Text(e.text).font(.willys(.title, poids: .semibold)).frame(maxWidth: 760, alignment: .leading)
                .id(i).transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
            HStack(spacing: 12) {
                cadran(e.time, "Temps"); cadran(e.temp, "Température"); cadran(e.speed + (e.reverse ? " ↺" : ""), "Vitesse")
            }
            Spacer()
            HStack(spacing: 12) {
                Button { Retour.leger(); avecAnimation { i = max(0, i - 1) } } label: { Text("Précédent").frame(maxWidth: .infinity).padding(18) }
                    .background(Color(hex: 0x2B3540), in: RoundedRectangle(cornerRadius: 18)).disabled(i == 0)
                Button { Retour.leger(); if i < etapes.count - 1 { avecAnimation { i += 1 } } else { Retour.succes(); fermer() } } label: {
                    Text(i < etapes.count - 1 ? "Suivant" : "Terminé").frame(maxWidth: .infinity).padding(18)
                }
                .background(Color(hex: 0x4FD1A1), in: RoundedRectangle(cornerRadius: 18)).foregroundStyle(Color(hex: 0x08251A))
            }
            .font(.willys(.title3, poids: .bold))
        }
        .padding(20)
        .foregroundStyle(Color(hex: 0xF2F5F7))
        .background(Color(hex: 0x14191F))
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }   // l'écran reste allumé en cuisinant
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }

    @ViewBuilder private func cadran(_ v: String, _ nom: String) -> some View {
        if !v.trimmingCharacters(in: .whitespaces).isEmpty {
            VStack {
                Text(v).font(Theme.titre(30)).foregroundStyle(Color(hex: 0x4FD1A1))
                Text(nom.uppercased()).font(.willys(.caption)).foregroundStyle(Color(hex: 0x9FB0BD))
            }
            .frame(maxWidth: .infinity).padding(12).background(Color(hex: 0x222B34), in: RoundedRectangle(cornerRadius: 16))
        }
    }
}

/// Une mise en page qui passe à la ligne (pour les pastilles de saison).
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let largeur = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, ligne: CGFloat = 0, maxX: CGFloat = 0
        for s in subviews {
            let t = s.sizeThatFits(.unspecified)
            if x + t.width > largeur, x > 0 { x = 0; y += ligne + spacing; ligne = 0 }
            x += t.width + spacing; ligne = max(ligne, t.height); maxX = max(maxX, x)
        }
        return CGSize(width: min(maxX, largeur), height: y + ligne)
    }
    func placeSubviews(in b: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = b.minX, y = b.minY, ligne: CGFloat = 0
        for s in subviews {
            let t = s.sizeThatFits(.unspecified)
            if x + t.width > b.maxX, x > b.minX { x = b.minX; y += ligne + spacing; ligne = 0 }
            s.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(t))
            x += t.width + spacing; ligne = max(ligne, t.height)
        }
    }
}


/// Reclasser d'un coup les articles mal rangés : une proposition par article, qu'on peut corriger avant d'appliquer.
struct ReclasserView: View {
    let articles: [Article]
    let rangement: Rangement
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var fermer
    @State private var choix: [String: String] = [:]     // cle de l'article → catégorie choisie

    static func proposition(_ a: Article, _ r: Rangement) -> String? {
        let attendues = Categorie.attendues(dans: r.rawValue)
        let mal = a.categorie == "autre" || !attendues.contains(a.categorie)
        guard mal, let g = Categorie.deviner(nom: a.nom, dans: r.rawValue), g != a.categorie else { return nil }
        return g
    }

    private var concernes: [Article] { articles.filter { Self.proposition($0, rangement) != nil } }

    var body: some View {
        Form {
            Section {
                ForEach(concernes) { a in
                    Picker(selection: Binding(
                        get: { choix[a.cle] ?? Self.proposition(a, rangement) ?? a.categorie },
                        set: { choix[a.cle] = $0 })) {
                        ForEach(Categorie.attendues(dans: rangement.rawValue), id: \.self) { Text(Categorie.nom($0)).tag($0) }
                    } label: {
                        VStack(alignment: .leading) {
                            Text(a.nom).bold()
                            Text("Actuellement : \(Categorie.nom(a.categorie))").font(.willys(.caption)).foregroundStyle(.secondary)
                        }
                    }
                }
            } footer: { Text("Les propositions viennent du nom de l'article. Change celle qui ne va pas.") }
        }
        .navigationTitle("Reclasser")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Fermer") { fermer() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Appliquer") {
                    for a in concernes {
                        let c = choix[a.cle] ?? Self.proposition(a, rangement) ?? a.categorie
                        a.categorie = c
                    }
                    ctx.enregistrer(); Retour.succes(); Base.rafraichirWidgets(); fermer()
                }
            }
        }
    }
}

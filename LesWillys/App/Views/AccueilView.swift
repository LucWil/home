import SwiftUI
import SwiftData
import PhotosUI

/// L'accueil : la bannière, « Cette semaine », ce qui est nouveau, qui est passé, les petits mots et le mur des petites.
struct AccueilView: View {
    let moi: String
    @Environment(\.modelContext) private var ctx
    @Environment(\.colorScheme) private var scheme
    @Environment(\.openURL) private var ouvrir
    @Environment(\.horizontalSizeClass) private var largeur
    @Query(sort: \Evenement.debut) private var evenements: [Evenement]
    @Query(sort: \Idee.cree, order: .reverse) private var idees: [Idee]
    @Query(sort: \Recette.cree, order: .reverse) private var recettes: [Recette]
    @Query(sort: \Visite.quand, order: .reverse) private var visites: [Visite]
    @Query(sort: \Activite.quand, order: .reverse) private var activites: [Activite]
    @Query(sort: \Photo.cree, order: .reverse) private var photos: [Photo]
    @Query private var reactions: [Reaction]

    @State private var feuille: Feuille?
    @State private var dernierPassage = Date(timeIntervalSince1970: Base.reglages.double(forKey: "vu"))

    enum Feuille: String, Identifiable { case mot, evenement, photo; var id: String { rawValue } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                // L'ordre de l'accueil : la date et l'agenda du jour, le marché du jour, la maison, puis « À découvrir ».
                aujourdhui
                // toutes les 5 minutes : un marché fini disparaît, celui qui ouvre apparaît
                TimelineView(.periodic(from: .now, by: 300)) { _ in CartePresDeChezNous(moi: moi, partie: .marche) }
                CarteSouper(moi: moi)
                RappelKit72(moi: moi)
                CarteNotifications()
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 16) { semaine; VStack(spacing: 16) { nouveau; passages } }
                    VStack(spacing: 16) { semaine; nouveau; passages }
                }
                CartePresDeChezNous(moi: moi, partie: .decouvrir)
                CarteBonnesAffaires(moi: moi)
                banniere
                filActivite
                petitsMots
                mur
            }
            .padding(16)
        }
        .background(Theme.emaille(scheme))
        .navigationTitle("\(salut), \(Famille.membre(moi)?.nom ?? "")")
        .onDisappear { Base.reglages.set(Date.now.timeIntervalSince1970, forKey: "vu") }
        .sheet(item: $feuille) { f in
            NavigationStack {
                switch f {
                case .mot: FormulaireMot(moi: moi)
                case .evenement: FormulaireEvenement(moi: moi)
                case .photo: FormulairePhoto(moi: moi)
                }
            }
        }
    }

    private var salut: String {
        let h = Calendar.current.component(.hour, from: .now)
        return h < 6 ? "Bonne nuit" : h < 12 ? "Bonjour" : h < 18 ? "Bon après-midi" : "Bonsoir"
    }

    // MARK: Bannière

    /// La date du jour et ce qui est à l'agenda aujourd'hui.
    private var aujourdhui: some View {
        let t = Jour.aujourdhui
        let auj = evenements.filter { $0.debut <= t && $0.fin >= t }
        return VStack(alignment: .leading, spacing: 10) {
            Text("AUJOURD'HUI").font(.willys(.caption, poids: .heavy)).tracking(1.2).opacity(0.8)
            Text({ let t = Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(Locale(identifier: "fr_BE"))); return t.prefix(1).uppercased() + t.dropFirst() }())
                .font(Theme.titre(28))
            if auj.isEmpty {
                Text("Rien à l'agenda aujourd'hui.").font(.willys(.subheadline)).opacity(0.9)
            }
            ForEach(auj) { e in
                HStack(alignment: .top, spacing: 10) {
                    RoundedRectangle(cornerRadius: 2).fill(e.typeEvenement.couleur).frame(width: 4)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(e.titre).font(.willys(.headline))
                        Text(e.typeEvenement.libelle + (e.fin > t ? " · jusqu'au \(Jour.joli(e.fin, .dateTime.weekday(.wide).day().month(.wide)))" : ""))
                            .font(.willys(.caption)).opacity(0.85)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
            }
            LigneMeteo()
            HStack {
                Button("Laisser un mot") { feuille = .mot }.buttonStyle(.borderedProminent).tint(.white).foregroundStyle(Color(hex: 0x1F4F86))
                Button("Ajouter une date") { feuille = .evenement }.buttonStyle(.bordered).tint(.white)
            }
            .buttonBorderShape(.capsule)
            .font(.willys(.subheadline, poids: .bold))
        }
        .foregroundStyle(.white)
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LinearGradient(colors: [Color(hex: 0x2F6FB5), Color(hex: 0x3F8FD0)], startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 24))
    }

    private var banniere: some View {
        let jour = Int(Date.now.timeIntervalSince1970 / 86400)
        let photo = photos.isEmpty ? nil : photos[jour % photos.count]
        let prochain = evenements.first { $0.fin >= Jour.aujourdhui }
        let compact = largeur == .compact
        // sur iPhone la photo passe au-dessus du texte : côte à côte, tout était à l'étroit
        let disposition = compact ? AnyLayout(VStackLayout(alignment: .leading, spacing: 14))
                                  : AnyLayout(HStackLayout(alignment: .center, spacing: 18))
        return disposition {
            if let photo, let data = photo.image, let ui = UIImage(data: data) {
                Image(uiImage: ui).resizable().scaledToFill()
                    .frame(maxWidth: compact ? .infinity : 120).frame(height: compact ? 160 : 120)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white, lineWidth: 5))
                    .rotationEffect(.degrees(-3)).shadow(radius: 6, y: 6)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("CHEZ LES WILLYS").font(.willys(.caption, poids: .semibold)).foregroundStyle(.secondary)
                Text(["Bienvenue à la maison", "La famille au complet", "Toute la famille, une seule maison"][jour % 3])
                    .font(Theme.titre(26))
                HStack(spacing: 4) { ForEach(Famille.membres) { Aimant(membre: $0.id, taille: 24) } }
                if let prochain {
                    Text("Prochain rendez-vous : **\(Jour.joli(prochain.debut))** · \(prochain.titre)").font(.willys(.subheadline))
                } else {
                    Text("Pas de rendez-vous prévu : à vous de lancer la prochaine idée !").font(.willys(.subheadline))
                }
                ViewThatFits(in: .horizontal) {
                    HStack { boutonsBanniere }
                    VStack(alignment: .leading) { boutonsBanniere }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LinearGradient(colors: [Theme.accent.opacity(0.3), Famille.membre("loulou")!.couleur.opacity(0.15)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 22))
    }

    @ViewBuilder private var boutonsBanniere: some View {
        Button("Laisser un mot") { feuille = .mot }.buttonStyle(.borderedProminent)
        Button("Ajouter une photo") { feuille = .photo }.buttonStyle(.bordered)
    }

    // MARK: Cette semaine

    private var semaine: some View {
        let aujourdhui = Jour.aujourdhui, dans7 = Jour.plus(7)
        let liste = evenements.filter { $0.fin >= aujourdhui && $0.debut <= dans7 }
        return Porte {
            HStack {
                Text("Cette semaine").font(Theme.titre(22))
                Spacer()
                Button { feuille = .evenement } label: { Image(systemName: "plus") }
                    .buttonStyle(.bordered).buttonBorderShape(.circle)
                    .accessibilityLabel("Ajouter une date")
            }
            if liste.isEmpty {
                Text("Rien de prévu ces 7 prochains jours.").foregroundStyle(.secondary)
            } else {
                ForEach(liste) { LigneEvenement(e: $0, moi: moi) }
            }
        }
    }

    private var nouveau: some View {
        let frais: [(String, String, String)] =
            (evenements.filter { $0.cree > dernierPassage && $0.par != moi }.map { ("Calendrier", $0.titre, $0.par) }
             + idees.filter { $0.cree > dernierPassage && $0.par != moi && $0.genre != "mot" }
                .map { ($0.genre == "weekend" ? "Week-end" : "Voyage", $0.titre, $0.par) }
             + recettes.filter { $0.cree > dernierPassage && $0.par != moi }.map { ("Recette", $0.titre, $0.par) })
        return Porte(teinte: Theme.accent) {
            Text("Nouveau depuis ta dernière visite").font(.willys(.headline))
            if frais.isEmpty {
                Text("Tu es à jour, rien de neuf à la maison.").foregroundStyle(.secondary)
            } else {
                ForEach(Array(frais.prefix(6).enumerated()), id: \.offset) { _, x in
                    HStack { Aimant(membre: x.2, taille: 24); Etiquette(texte: x.0); Text(x.1).bold().lineLimit(1) }
                }
            }
        }
    }

    /// « En ce moment » : qui a l'app ouverte et où ; puis qui est passé récemment.
    private var passages: some View {
        TimelineView(.periodic(from: .now, by: 30)) { _ in
            let autres = visites.filter { $0.membre != moi }
            let la = autres.filter(Presence.estLa)
            let passes = autres.filter { !Presence.estLa($0) }.prefix(4)
            Porte {
                Text(la.isEmpty ? "Qui est passé" : "En ce moment").font(.willys(.headline))
                ForEach(la) { v in
                    HStack(spacing: 10) {
                        Aimant(membre: v.membre, taille: 30)
                            .overlay(alignment: .bottomTrailing) { PointVert() }
                        Text("**\(Famille.membre(v.membre)?.nom ?? "")** \(Presence.libelle(v.ecran))")
                    }
                    .transition(.colle)
                }
                if !la.isEmpty && !passes.isEmpty { Divider() }
                ForEach(Array(passes)) { v in
                    HStack(spacing: 10) {
                        Aimant(membre: v.membre, taille: 24).opacity(0.85)
                        Text(Famille.membre(v.membre)?.nom ?? "").bold()
                        Text(v.quand, format: .relative(presentation: .named)).foregroundStyle(.secondary)
                    }
                }
                if autres.isEmpty { Text("Personne d'autre pour l'instant.").foregroundStyle(.secondary) }
            }
            .animation(Anim.douce, value: la.map(\.membre))
        }
    }

    /// « Ça bouge à la maison » : le fil de ce que fait la famille, du plus récent au plus ancien.
    private var filActivite: some View {
        let lignes = activites.prefix(8)
        return VStack(alignment: .leading, spacing: 12) {
            TitreSection("Ça bouge à la maison")
            if lignes.isEmpty {
                Text("Ce que chacun range, mange ou prévoit apparaîtra ici.").foregroundStyle(.secondary)
            } else {
                Porte {
                    ForEach(Array(lignes.enumerated()), id: \.element.id) { i, a in
                        if i > 0 { Divider().padding(.leading, 44) }
                        Button { ouvrir(URL(string: "willys://\(a.onglet)")!) } label: {
                            HStack(alignment: .top, spacing: 12) {
                                Aimant(membre: a.membre, taille: 32)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("**\(Famille.membre(a.membre)?.nom ?? "")\(a.membre == moi ? " (toi)" : "")** \(a.phrase)")
                                        .multilineTextAlignment(.leading)
                                    Text(a.quand, format: .relative(presentation: .named))
                                        .font(.willys(.caption)).foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: a.icone).foregroundStyle(Theme.accent)
                            }
                        }
                        .buttonStyle(.plain)
                        .transition(.colle)
                    }
                }
                .animation(Anim.douce, value: lignes.map(\.cle))
            }
        }
    }

    // MARK: Petits mots et mur

    private var petitsMots: some View {
        let mots = idees.filter { $0.genre == "mot" }.prefix(6)
        return VStack(alignment: .leading, spacing: 14) {
            HStack { Text("Les petits mots").font(Theme.titre(22)); Spacer(); Button("Laisser un mot") { feuille = .mot } }
            if mots.isEmpty {
                Text("Un mot pour toute la famille : « Qui vient dimanche ? », « Merci pour le gâteau ! »")
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 22)], spacing: 26) {
                    ForEach(Array(mots.enumerated()), id: \.element.id) { i, m in
                        PostIt(texte: m.titre, auteur: m.par,
                               sousTitre: "\(Famille.membre(m.par)?.nom ?? "") · \(m.cree.formatted(.relative(presentation: .named)))",
                               rose: i % 2 == 1)
                        .transition(.colle)
                        .contextMenu {
                            ShareLink(item: m.titre)
                            if m.par == moi {
                                Button("Retirer", systemImage: "trash", role: .destructive) {
                                    Retour.avertissement()
                                    avecAnimation { ctx.delete(m); ctx.enregistrer() }
                                    Base.rafraichirWidgets()
                                }
                            }
                        }
                    }
                }
                .padding(.top, 12)
                .animation(Anim.douce, value: mots.map(\.cle))
            }
        }
    }

    private var mur: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack { Text("Le mur des petites").font(Theme.titre(22)); Spacer(); Button("Ajouter une photo") { feuille = .photo } }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 20)], spacing: 22) {
                ForEach(Array(photos.prefix(24).enumerated()), id: \.element.id) { i, p in
                    Polaroid(photo: p, moi: moi, reactions: reactions.filter { $0.element == p.cle })
                        .rotationEffect(.degrees([-1.6, 1.4, 0][i % 3]))
                }
            }
        }
    }
}

struct Polaroid: View {
    let photo: Photo
    let moi: String
    let reactions: [Reaction]
    @Environment(\.modelContext) private var ctx

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Group {
                if let d = photo.image, let ui = UIImage(data: d) {
                    Image(uiImage: ui).resizable().scaledToFill()
                } else if let url = URL(string: photo.url), photo.url.hasPrefix("https") {
                    AsyncImage(url: url) { $0.resizable().scaledToFill() } placeholder: { Color.gray.opacity(0.2) }
                } else { Color.gray.opacity(0.2) }
            }
            .frame(minWidth: 0, maxWidth: .infinity).aspectRatio(1, contentMode: .fit).clipped()
            if !photo.legende.isEmpty {
                Text(photo.legende).font(Theme.main(19)).foregroundStyle(Theme.encrePostit)
            }
            HStack(spacing: 6) {
                ForEach([("coeur", "❤️"), ("rire", "😄"), ("waouh", "🤩")], id: \.0) { k, e in
                    let n = reactions.filter { $0.reaction == k }.count
                    let mienne = reactions.first { $0.membre == moi }?.reaction == k
                    Button("\(e)\(n > 0 ? " \(n)" : "")") { Retour.selection(); avecAnimation { reagir(k) } }
                        .buttonStyle(StylePastille(active: mienne))
                        .environment(\.colorScheme, .light)     // le polaroïd reste blanc, même en mode sombre
                        .accessibilityLabel("\(k == "coeur" ? "J'aime" : k == "rire" ? "Ça me fait rire" : "Waouh"), \(n)")
                }
            }
            .padding(.bottom, 10)
        }
        .padding([.horizontal, .top], 10)
        .background(.white, in: RoundedRectangle(cornerRadius: 3))
        .shadow(color: .black.opacity(0.3), radius: 10, y: 8)
        .overlay(alignment: .top) { PileAimants(membres: photo.qui, taille: 22).offset(y: -10) }
    }

    private func reagir(_ k: String) { Reactions.basculer(element: photo.cle, membre: moi, reaction: k, existantes: reactions, ctx: ctx) }
}

enum Reactions {
    /// Une réaction par personne et par élément : toucher la même la retire, toucher une autre la remplace.
    static func basculer(element: String, membre: String, reaction: String, existantes: [Reaction], ctx: ModelContext) {
        let mienne = existantes.first { $0.element == element && $0.membre == membre }
        let identique = mienne?.reaction == reaction
        if let mienne { ctx.delete(mienne) }
        if !identique { ctx.insert(Reaction(element: element, membre: membre, reaction: reaction)) }
        ctx.enregistrer()
    }
}

/// Une ligne de date, comme dans l'app web : tuile de date, étiquette de type, aimants, partage WhatsApp.
struct LigneEvenement: View {
    let e: Evenement
    let moi: String
    @Environment(\.modelContext) private var ctx

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                Text(Jour.date(e.debut).formatted(.dateTime.day())).font(Theme.titre(22))
                Text(Jour.date(e.debut).formatted(.dateTime.month(.abbreviated).locale(Locale(identifier: "fr_BE"))))
                    .font(.willys(.caption2)).textCase(.uppercase).foregroundStyle(.secondary)
            }
            .frame(width: 52).padding(.vertical, 6).background(.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 4) {
                HStack { Etiquette(texte: e.typeEvenement.libelle, couleur: e.typeEvenement.couleur); Text(e.titre).bold() }
                Text(plage + (e.gardeChez.map { " · garde chez \(Famille.membre($0)?.nom ?? "")" } ?? ""))
                    .font(.willys(.subheadline)).foregroundStyle(.secondary)
                HStack {
                    PileAimants(membres: e.personnes)
                    ShareLink(item: "\(e.typeEvenement.libelle) : \(e.titre) — \(plage)") {
                        Label("Partager", systemImage: "square.and.arrow.up").font(.willys(.caption, poids: .bold))
                    }
                }
            }
        }
        .padding(.vertical, 6)
        .contextMenu {
            if e.par == moi || moi == "chouchou" || moi == "loulou" {
                Button("Retirer", systemImage: "trash", role: .destructive) {
                    Retour.avertissement(); avecAnimation { ctx.delete(e); ctx.enregistrer() }; Base.rafraichirWidgets()
                }
            }
        }
    }

    private var plage: String {
        e.fin != e.debut
            ? "\(Jour.joli(e.debut, .dateTime.day().month(.abbreviated))) → \(Jour.joli(e.fin, .dateTime.day().month(.abbreviated)))"
            : Jour.joli(e.debut, .dateTime.weekday(.wide))
    }
}

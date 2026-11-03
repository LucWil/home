import SwiftUI
import SwiftData
import PhotosUI

/// L'accueil : la bannière, « Cette semaine », ce qui est nouveau, qui est passé, les petits mots et le mur des petites.
struct AccueilView: View {
    let moi: String
    @Environment(\.modelContext) private var ctx
    @Environment(\.colorScheme) private var scheme
    @Query(sort: \Evenement.debut) private var evenements: [Evenement]
    @Query(sort: \Idee.cree, order: .reverse) private var idees: [Idee]
    @Query(sort: \Recette.cree, order: .reverse) private var recettes: [Recette]
    @Query(sort: \Visite.quand, order: .reverse) private var visites: [Visite]
    @Query(sort: \Photo.cree, order: .reverse) private var photos: [Photo]
    @Query private var reactions: [Reaction]

    @State private var feuille: Feuille?
    @State private var dernierPassage = Date(timeIntervalSince1970: Base.reglages.double(forKey: "vu"))

    enum Feuille: String, Identifiable { case mot, evenement, photo; var id: String { rawValue } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                banniere
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 16) { semaine; VStack(spacing: 16) { nouveau; passages } }
                    VStack(spacing: 16) { semaine; nouveau; passages }
                }
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

    private var banniere: some View {
        let jour = Int(Date.now.timeIntervalSince1970 / 86400)
        let photo = photos.isEmpty ? nil : photos[jour % photos.count]
        let prochain = evenements.first { $0.fin >= Jour.aujourdhui }
        return HStack(alignment: .center, spacing: 18) {
            if let photo, let data = photo.image, let ui = UIImage(data: data) {
                Image(uiImage: ui).resizable().scaledToFill().frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white, lineWidth: 5))
                    .rotationEffect(.degrees(-3)).shadow(radius: 6, y: 6)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("CHEZ LES WILLYS").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Text(["Bienvenue à la maison", "La famille au complet", "Toute la famille, une seule maison"][jour % 3])
                    .font(Theme.titre(26))
                HStack(spacing: 4) { ForEach(Famille.membres) { Aimant(membre: $0.id, taille: 24) } }
                if let prochain {
                    Text("Prochain rendez-vous : **\(Jour.joli(prochain.debut))** · \(prochain.titre)").font(.subheadline)
                } else {
                    Text("Pas de rendez-vous prévu : à vous de lancer la prochaine idée !").font(.subheadline)
                }
                HStack {
                    Button("Laisser un mot") { feuille = .mot }.buttonStyle(.borderedProminent)
                    Button("Ajouter une photo") { feuille = .photo }.buttonStyle(.bordered)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LinearGradient(colors: [Theme.accent.opacity(0.3), Famille.membre("loulou")!.couleur.opacity(0.15)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 22))
    }

    // MARK: Cette semaine

    private var semaine: some View {
        let aujourdhui = Jour.aujourdhui, dans7 = Jour.plus(7)
        let liste = evenements.filter { $0.fin >= aujourdhui && $0.debut <= dans7 }
        return Porte {
            HStack {
                Text("Cette semaine").font(Theme.titre(22))
                Spacer()
                Button { feuille = .evenement } label: { Image(systemName: "plus") }.buttonStyle(.bordered)
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
            Text("Nouveau depuis ta dernière visite").font(.headline)
            if frais.isEmpty {
                Text("Tu es à jour, rien de neuf à la maison.").foregroundStyle(.secondary)
            } else {
                ForEach(Array(frais.prefix(6).enumerated()), id: \.offset) { _, x in
                    HStack { Aimant(membre: x.2, taille: 24); Etiquette(texte: x.0); Text(x.1).bold().lineLimit(1) }
                }
            }
        }
    }

    private var passages: some View {
        Porte {
            Text("Qui est passé").font(.headline)
            let autres = visites.filter { $0.membre != moi }.prefix(6)
            if autres.isEmpty {
                Text("Personne d'autre pour l'instant.").foregroundStyle(.secondary)
            } else {
                ForEach(Array(autres)) { v in
                    HStack {
                        Aimant(membre: v.membre, taille: 24)
                        Text(Famille.membre(v.membre)?.nom ?? "").bold()
                        Text(v.quand, format: .relative(presentation: .named)).foregroundStyle(.secondary)
                    }
                }
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
                        .contextMenu {
                            if m.par == moi { Button("Retirer", role: .destructive) { ctx.delete(m); ctx.enregistrer(); Base.rafraichirWidgets() } }
                        }
                    }
                }
                .padding(.top, 12)
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
                    Button("\(e)\(n > 0 ? " \(n)" : "")") { reagir(k) }
                        .font(.footnote).padding(.horizontal, 8).padding(.vertical, 3)
                        .background(mienne ? Color.primary.opacity(0.85) : .clear, in: Capsule())
                        .foregroundStyle(mienne ? Color.white : Theme.encrePostit)
                        .overlay(Capsule().stroke(.gray.opacity(0.3)))
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
                    .font(.caption2).textCase(.uppercase).foregroundStyle(.secondary)
            }
            .frame(width: 52).padding(.vertical, 6).background(.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 4) {
                HStack { Etiquette(texte: e.typeEvenement.libelle, couleur: e.typeEvenement.couleur); Text(e.titre).bold() }
                Text(plage + (e.gardeChez.map { " · garde chez \(Famille.membre($0)?.nom ?? "")" } ?? ""))
                    .font(.subheadline).foregroundStyle(.secondary)
                HStack {
                    PileAimants(membres: e.personnes)
                    ShareLink(item: "\(e.typeEvenement.libelle) : \(e.titre) — \(plage)") {
                        Label("Partager", systemImage: "square.and.arrow.up").font(.caption.bold())
                    }
                }
            }
        }
        .padding(.vertical, 6)
        .contextMenu {
            if e.par == moi || moi == "chouchou" || moi == "loulou" {
                Button("Retirer", role: .destructive) { ctx.delete(e); ctx.enregistrer(); Base.rafraichirWidgets() }
            }
        }
    }

    private var plage: String {
        e.fin != e.debut
            ? "\(Jour.joli(e.debut, .dateTime.day().month(.abbreviated))) → \(Jour.joli(e.fin, .dateTime.day().month(.abbreviated)))"
            : Jour.joli(e.debut, .dateTime.weekday(.wide))
    }
}

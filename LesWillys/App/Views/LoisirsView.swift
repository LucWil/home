import SwiftUI
import SwiftData
import PhotosUI

/// L'onglet Loisirs : ce qu'on fait ensemble, dehors. Restaurants, hôtels et le budget des sorties.
struct LoisirsView: View {
    let moi: String
    @Binding var partie: Partie
    @Environment(\.colorScheme) private var scheme
    @Query private var visites: [Visite]

    /// Tout ce qu'on fait ensemble dehors : les idées de voyages et de week-ends, les restaurants,
    /// les hôtels et le budget des sorties (un iPhone n'affiche bien que cinq onglets).
    enum Partie: String, CaseIterable, Identifiable {
        case voyages = "Voyages", weekends = "Week-ends", restaurants = "Restos", hotels = "Hôtels", budget = "Budget"
        var id: String { rawValue }
        /// Le libellé du sélecteur : cinq segments sur un iPhone, « Week-ends » serait coupé.
        var court: String { self == .weekends ? "W-E" : rawValue }
        /// Les liens willys://voyages, willys://weekends, willys://restaurants…
        init?(cle: String) {
            switch cle {
            case "voyages", "voyage": self = .voyages
            case "weekends", "weekend": self = .weekends
            case "restaurants", "restos": self = .restaurants
            case "hotels": self = .hotels
            case "budget": self = .budget
            default: return nil
            }
        }
    }

    var body: some View {
        Group {
            switch partie {
            case .voyages: IdeesView(genre: "voyage", moi: moi).id("voyage")
            case .weekends: IdeesView(genre: "weekend", moi: moi).id("weekend")
            default:
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        IciAussi(onglet: "loisirs", moi: moi, visites: visites)
                        switch partie {
                        case .hotels: HotelsListe(moi: moi)
                        case .budget: BudgetLoisirs(moi: moi)
                        default: RestaurantsListe(moi: moi)
                        }
                    }
                    .padding(16)
                }
                .background(Theme.emaille(scheme))
                .navigationTitle("Loisirs")
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            Picker("Partie des loisirs", selection: $partie) { ForEach(Partie.allCases) { Text($0.court).accessibilityLabel($0.rawValue).tag($0) } }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16).padding(.vertical, 8)
                .background(.bar)
                .sensoryFeedback(.selection, trigger: partie)
        }
    }
}

// MARK: - Restaurants

struct RestaurantsListe: View {
    let moi: String
    @Query(sort: \Restaurant.nom) private var restos: [Restaurant]
    @State private var ajout = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            TitreSection("Les restaurants") {
                Button { ajout = true } label: { Label("Ajouter", systemImage: "plus") }.buttonStyle(.bordered)
            }
            if restos.isEmpty {
                ContentUnavailableView("Pas encore de restaurant", systemImage: "fork.knife",
                                       description: Text("Note le nom et la ville : Claude cherche l'adresse, le menu et les avis clients."))
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 14)], spacing: 14) {
                ForEach(restos) { CarteRestaurant(r: $0, moi: moi) }
            }
        }
        .sheet(isPresented: $ajout) { NavigationStack { FormulaireRestaurant(moi: moi, r: nil) } }
    }
}

struct CarteRestaurant: View {
    let r: Restaurant
    let moi: String
    @Query(sort: \Sortie.date, order: .reverse) private var toutesSorties: [Sortie]
    @Query private var evenements: [Evenement]
    @State private var feuille: Feuille?

    enum Feuille: Identifiable {
        case modifier, sortie(Sortie?), avis(String, Int)
        var id: String {
            switch self { case .modifier: "m"; case .sortie(let s): "s" + (s?.cle ?? "+"); case .avis(let t, _): "a" + t }
        }
    }

    private var sorties: [Sortie] { toutesSorties.filter { $0.type == "resto" && $0.ref == r.cle } }

    var body: some View {
        Porte {
            VStack(alignment: .leading, spacing: 2) {
                Text(r.nom).font(Theme.titre(20))
                if !r.ville.isEmpty { Text(r.ville).font(.willys(.subheadline)).foregroundStyle(.secondary) }
            }
            VStack(alignment: .leading, spacing: 6) {
                if !r.cuisine.isEmpty { Label(r.cuisine, systemImage: "fork.knife") }
                if !r.adresse.isEmpty || !r.ville.isEmpty {
                    if let u = LiensLoisirs.carte(nom: r.nom, lieu: r.adresse.isEmpty ? r.ville : r.adresse) {
                        Link(destination: u) { Label(r.adresse.isEmpty ? r.ville : r.adresse, systemImage: "mappin.and.ellipse") }
                    }
                }
                if let t = LiensLoisirs.tel(r.tel) { Link(destination: t) { Label(r.tel, systemImage: "phone") } }
                if !r.horaires.isEmpty { Label(r.horaires, systemImage: "clock") }
            }
            .font(.willys(.subheadline)).foregroundStyle(.primary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    if let u = LiensLoisirs.sur(r.reserver) ?? LiensLoisirs.sur(r.site) {
                        Link(destination: u) { Text(r.reserver.isEmpty ? "Le site" : "Réserver") }.buttonStyle(.borderedProminent)
                    }
                    if let t = LiensLoisirs.tel(r.tel) { Link("Appeler", destination: t).buttonStyle(.bordered) }
                    if let u = LiensLoisirs.carte(nom: r.nom, lieu: r.adresse.isEmpty ? r.ville : r.adresse) {
                        Link("Carte", destination: u).buttonStyle(.bordered)
                    }
                    if let u = LiensLoisirs.sur(r.menuLien) { Link("Le menu", destination: u).buttonStyle(.bordered) }
                }
                .buttonBorderShape(.capsule).font(.willys(.subheadline, poids: .bold))
            }

            if !r.menu.isEmpty {
                DisclosureGroup("Le menu · \(r.menu.count) plats") {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(r.menu, id: \.self) { p in
                            HStack(alignment: .firstTextBaseline) {
                                Text(p.nom) + Text(p.note.isEmpty ? "" : " · \(p.note)").foregroundColor(.secondary)
                                Spacer()
                                Text(p.prix).monospacedDigit().bold()
                            }
                        }
                        if !r.menuNote.isEmpty { Text(r.menuNote).font(.willys(.caption)).foregroundStyle(.secondary) }
                    }
                    .padding(.top, 6)
                }
                .font(.willys(.subheadline, poids: .semibold))
            }

            if r.avisNote > 0 {
                VStack(alignment: .leading, spacing: 2) {
                    (Text(etoiles(r.avisNote)).foregroundColor(Theme.accent) + Text(" \(r.avisNote.formatted(.number.precision(.fractionLength(0...1))))/5").bold()
                     + Text(" · avis clients \(r.avisSource)\(r.avisNb.isEmpty ? "" : " · \(r.avisNb) avis")").foregroundColor(.secondary))
                    if !r.avisResume.isEmpty { Text(r.avisResume).foregroundStyle(.secondary) }
                }
                .font(.willys(.subheadline))
            }

            if !sorties.isEmpty {
                Divider()
                Text("On y est allés · \(sorties.count) fois").font(.willys(.subheadline, poids: .bold))
                ForEach(sorties.prefix(3)) { s in
                    LigneSortie(s: s, moi: moi, voyage: Vacances.voyage(le: s.date, parmi: evenements)) {
                        feuille = .sortie(s)
                    } avis: {
                        let a = s.avis[moi] ?? AvisMembre()
                        feuille = .avis(a.mot, a.stars)
                    }
                }
            }

            Text(r.infosMaj.isEmpty
                 ? (r.infosStatut == "introuvable" ? "Claude n'a pas trouvé ce restaurant en ligne : complète la fiche à la main."
                    : "Claude cherche l'adresse, le téléphone, le menu et les avis : la fiche se complète d'ici demain.")
                 : "Infos trouvées par Claude le \(Jour.joli(r.infosMaj, .dateTime.day().month(.wide))) — à vérifier avant d'y aller.")
                .font(.willys(.caption)).foregroundStyle(.secondary)

            HStack {
                Button("On y est allés") { feuille = .sortie(nil) }.buttonStyle(.borderedProminent)
                Button("Modifier la fiche") { feuille = .modifier }.buttonStyle(.bordered)
            }
            .buttonBorderShape(.capsule)
        }
        .sheet(item: $feuille) { f in
            NavigationStack {
                switch f {
                case .modifier: FormulaireRestaurant(moi: moi, r: r)
                case .sortie(let s): FormulaireSortie(moi: moi, resto: r, sortie: s)
                case .avis(let texte, let note): LaisserAvis(nom: r.nom, lieu: r.adresse.isEmpty ? r.ville : r.adresse, texte: texte, note: note)
                }
            }
        }
    }
}

func etoiles(_ n: Double) -> String {
    let k = max(0, min(5, Int(n.rounded())))
    return String(repeating: "★", count: k) + String(repeating: "☆", count: 5 - k)
}

/// Une sortie, en quelques lignes : la date, l'addition, les photos, l'impression de chacun.
struct LigneSortie: View {
    let s: Sortie
    let moi: String
    let voyage: Evenement?
    var modifier: () -> Void
    var avis: () -> Void
    @Query private var photos: [PhotoLoisir]

    var body: some View {
        let mesPhotos = photos.filter { $0.parent == s.cle }
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(Jour.joli(s.date, .dateTime.weekday(.abbreviated).day().month(.wide).year())).bold()
                if let voyage { Etiquette(texte: voyage.titre, couleur: TypeEvenement.voyage.couleur) }
                Spacer()
                if s.montant > 0 {
                    VStack(alignment: .trailing, spacing: 0) {
                        Text(s.montant.euros).bold().monospacedDigit()
                        if s.personnes > 0 { Text("\((s.montant / Double(s.personnes)).euros) / pers.").font(.willys(.caption)).foregroundStyle(.secondary) }
                    }
                }
            }
            GaleriePhotos(photos: mesPhotos)
            ForEach(s.avis.sorted { $0.key < $1.key }.filter { $0.value.stars > 0 || !$0.value.mot.isEmpty }, id: \.key) { k, a in
                HStack(alignment: .top, spacing: 8) {
                    Aimant(membre: k, taille: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        if a.stars > 0 { Text(etoiles(Double(a.stars))).foregroundStyle(Theme.accent).font(.willys(.caption)) }
                        if !a.mot.isEmpty { Text("« \(a.mot) »").font(Theme.main(18)) }
                    }
                }
            }
            HStack {
                Button(s.avis[moi] == nil ? "Mon impression, mes photos" : "Modifier", action: modifier)
                Button("Laisser un avis", action: avis)
            }
            .buttonStyle(.bordered).buttonBorderShape(.capsule).font(.willys(.footnote, poids: .semibold))
        }
        .padding(.vertical, 4)
    }
}

struct GaleriePhotos: View {
    let photos: [PhotoLoisir]
    @State private var grande: PhotoLoisir?
    var body: some View {
        if !photos.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(photos) { p in
                        if let d = p.image, let ui = UIImage(data: d) {
                            Button { grande = p } label: {
                                Image(uiImage: ui).resizable().scaledToFill().frame(width: 76, height: 76)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(alignment: .bottomLeading) {
                                        Text(p.quoi).font(.willys(.caption2, poids: .bold)).foregroundStyle(.white)
                                            .padding(.horizontal, 5).background(.black.opacity(0.55), in: Capsule()).padding(4)
                                    }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Photo : \(p.quoi)")
                        }
                    }
                }
            }
            .sheet(item: $grande) { p in
                if let d = p.image, let ui = UIImage(data: d) {
                    Image(uiImage: ui).resizable().scaledToFit().padding().presentationDragIndicator(.visible)
                }
            }
        }
    }
}

struct FormulaireRestaurant: View {
    let moi: String
    let r: Restaurant?
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var fermer
    @State private var nom = ""
    @State private var ville = ""
    @State private var adresse = ""
    @State private var tel = ""
    @State private var cuisine = ""
    @State private var site = ""
    @State private var reserver = ""
    @State private var menuLien = ""
    @State private var horaires = ""
    var body: some View {
        Form {
            Section {
                TextField("Le restaurant — ex. Le Bistro de la Place", text: $nom)
                TextField("Où ? — ex. Wavre", text: $ville)
            } footer: {
                if r == nil { Text("Le nom et la ville suffisent : Claude cherche ensuite l'adresse, le téléphone, le menu et les avis clients.") }
            }
            Section(r == nil ? "La fiche (facultatif)" : "La fiche") {
                TextField("Adresse", text: $adresse)
                TextField("Téléphone", text: $tel).keyboardType(.phonePad)
                TextField("Cuisine — ex. bistro français", text: $cuisine)
                TextField("Horaires", text: $horaires)
                TextField("Site (https://…)", text: $site).keyboardType(.URL).textInputAutocapitalization(.never)
                TextField("Lien pour réserver", text: $reserver).keyboardType(.URL).textInputAutocapitalization(.never)
                TextField("Lien vers le menu", text: $menuLien).keyboardType(.URL).textInputAutocapitalization(.never)
            }
            if let r, r.par == moi {
                Button("Retirer ce restaurant", role: .destructive) {
                    Retour.avertissement(); ctx.delete(r); ctx.enregistrer(); fermer()
                }
            }
        }
        .navigationTitle(r?.nom ?? "Une adresse à retenir")
        .onAppear {
            guard let r else { return }
            nom = r.nom; ville = r.ville; adresse = r.adresse; tel = r.tel; cuisine = r.cuisine
            site = r.site; reserver = r.reserver; menuLien = r.menuLien; horaires = r.horaires
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Annuler") { fermer() } }
            ToolbarItem(placement: .confirmationAction) {
                Button(r == nil ? "Ajouter" : "Enregistrer") {
                    let x = r ?? { let n = Restaurant(nom: nom, ville: ville, par: moi); ctx.insert(n); return n }()
                    x.nom = nom.trimmingCharacters(in: .whitespaces); x.ville = ville; x.adresse = adresse; x.tel = tel
                    x.cuisine = cuisine; x.horaires = horaires
                    x.site = site.hasPrefix("https://") ? site : ""; x.reserver = reserver.hasPrefix("https://") ? reserver : ""
                    x.menuLien = menuLien.hasPrefix("https://") ? menuLien : ""
                    Retour.succes(); ctx.enregistrer(); fermer()
                }.disabled(nom.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }
}

/// « On y est allés » : l'addition, qui était là, les photos du plat et de l'ambiance, mon impression.
struct FormulaireSortie: View {
    let moi: String
    let resto: Restaurant
    let sortie: Sortie?
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var fermer
    @Query private var toutesPhotos: [PhotoLoisir]
    @State private var date = Date.now
    @State private var montant = ""
    @State private var personnes = 2
    @State private var qui: [String] = []
    @State private var etoilesMoi = 0
    @State private var mot = ""
    @State private var nouvelles: [(quoi: String, data: Data)] = []
    @State private var retirees: Set<String> = []
    @State private var choixPlat: PhotosPickerItem?
    @State private var choixAmbiance: PhotosPickerItem?
    @State private var avisApres: (String, Int)?

    private var existantes: [PhotoLoisir] { toutesPhotos.filter { $0.parent == sortie?.cle && !retirees.contains($0.cle) } }

    var body: some View {
        Form {
            Section {
                DatePicker("Le", selection: $date, displayedComponents: .date)
                TextField("L'addition (€) — ex. 86,50", text: $montant).keyboardType(.decimalPad)
                Stepper("Personnes : \(personnes)", value: $personnes, in: 1...30)
            }
            Section("Qui était là ?") { ChoixAimants(membres: Famille.membres, choisis: $qui) }
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(existantes) { p in vignette(p.image, p.quoi) { retirees.insert(p.cle) } }
                        ForEach(Array(nouvelles.enumerated()), id: \.offset) { i, n in vignette(n.data, n.quoi) { nouvelles.remove(at: i) } }
                    }
                }
                HStack {
                    PhotosPicker(selection: $choixPlat, matching: .images) { Label("Le plat", systemImage: "fork.knife") }
                    Spacer()
                    PhotosPicker(selection: $choixAmbiance, matching: .images) { Label("L'ambiance", systemImage: "sparkles") }
                }
                .disabled(existantes.count + nouvelles.count >= 6)
            } header: { Text("Les photos") } footer: { Text("Jusqu'à 6 photos, réduites avant l'envoi.") }
            Section("Mon impression") {
                HStack {
                    ForEach(1...5, id: \.self) { n in
                        Button { Retour.selection(); etoilesMoi = n } label: {
                            Image(systemName: n <= etoilesMoi ? "star.fill" : "star").font(.title2).foregroundStyle(Theme.accent)
                        }
                        .buttonStyle(.plain).accessibilityLabel("\(n) étoile\(n > 1 ? "s" : "")")
                    }
                }
                TextField("Ex. accueil adorable, la côte à l'os était parfaite", text: $mot, axis: .vertical).lineLimit(2...6)
            }
            if let sortie, sortie.par == moi {
                Button("Retirer cette sortie", role: .destructive) {
                    toutesPhotos.filter { $0.parent == sortie.cle }.forEach(ctx.delete)
                    ctx.delete(sortie); ctx.enregistrer(); fermer()
                }
            }
        }
        .environment(\.locale, Locale(identifier: "fr_BE"))
        .navigationTitle(resto.nom)
        .onAppear {
            if let s = sortie {
                date = Jour.date(s.date); montant = s.montant > 0 ? String(s.montant).replacingOccurrences(of: ".", with: ",") : ""
                personnes = s.personnes; qui = s.qui
                let a = s.avis[moi]; etoilesMoi = a?.stars ?? 0; mot = a?.mot ?? ""
            } else { qui = [moi] }
        }
        .onChange(of: choixPlat) { _, i in charger(i, "plat") }
        .onChange(of: choixAmbiance) { _, i in charger(i, "ambiance") }
        .sheet(isPresented: Binding(get: { avisApres != nil }, set: { if !$0 { avisApres = nil; fermer() } })) {
            NavigationStack { LaisserAvis(nom: resto.nom, lieu: resto.adresse.isEmpty ? resto.ville : resto.adresse, texte: avisApres?.0 ?? "", note: avisApres?.1 ?? 0) }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Annuler") { fermer() } }
            ToolbarItem(placement: .confirmationAction) { Button("Enregistrer") { enregistrer() } }
        }
    }

    private func vignette(_ d: Data?, _ quoi: String, retirer: @escaping () -> Void) -> some View {
        ZStack(alignment: .topTrailing) {
            if let d, let ui = UIImage(data: d) {
                Image(uiImage: ui).resizable().scaledToFill().frame(width: 72, height: 72).clipShape(RoundedRectangle(cornerRadius: 10))
            }
            Button(action: retirer) { Image(systemName: "xmark.circle.fill").foregroundStyle(.white, .black.opacity(0.7)) }
                .buttonStyle(.plain).accessibilityLabel("Retirer la photo \(quoi)")
        }
    }

    private func charger(_ item: PhotosPickerItem?, _ quoi: String) {
        Task {
            guard let d = try? await item?.loadTransferable(type: Data.self), let r = Images.reduire(d, max: 1000) else { return }
            nouvelles.append((quoi, r))
            choixPlat = nil; choixAmbiance = nil
        }
    }

    private func enregistrer() {
        let s = sortie ?? {
            let n = Sortie(ref: resto.cle, nom: resto.nom, lieu: resto.ville, foyer: Famille.foyer(de: moi) ?? "", par: moi)
            ctx.insert(n); return n
        }()
        s.date = Jour.chaine(date)
        s.montant = Double(montant.replacingOccurrences(of: ",", with: ".")) ?? 0
        s.personnes = personnes; s.qui = qui
        var a = s.avis; a[moi] = AvisMembre(stars: etoilesMoi, mot: mot.trimmingCharacters(in: .whitespacesAndNewlines)); s.avis = a
        toutesPhotos.filter { retirees.contains($0.cle) }.forEach(ctx.delete)
        nouvelles.forEach { ctx.insert(PhotoLoisir(parent: s.cle, quoi: $0.quoi, image: $0.data, par: moi)) }
        Retour.succes()
        ctx.enregistrer()
        Base.rafraichirWidgets()
        if sortie == nil && (etoilesMoi > 0 || !mot.isEmpty) { avisApres = (mot, etoilesMoi) } else { fermer() }
    }
}

/// Laisser un avis : l'app copie l'impression puis ouvre Google ou Tripadvisor ; on colle et on envoie.
/// (Publier à la place de la personne demanderait son compte : ce n'est pas possible.)
struct LaisserAvis: View {
    let nom: String
    let lieu: String
    @State var texte: String
    let note: Int
    @Environment(\.dismiss) private var fermer
    @Environment(\.openURL) private var ouvrir

    var body: some View {
        Form {
            Section {
                if note > 0 { Text(etoiles(Double(note))).foregroundStyle(Theme.accent) }
                TextField("Ton avis", text: $texte, axis: .vertical).lineLimit(3...10)
            } header: { Text(nom) } footer: {
                Text("Le texte est copié, puis la page s'ouvre : touche « Avis » puis « Écrire un avis », colle et envoie. Il faut être connecté à ton compte Google ou Tripadvisor.")
            }
            Section {
                Button { publier(LiensLoisirs.avisGoogle(nom: nom, lieu: lieu)) } label: { Label("Sur Google", systemImage: "g.circle") }
                Button { publier(LiensLoisirs.avisTripadvisor(nom: nom, lieu: lieu)) } label: { Label("Sur Tripadvisor", systemImage: "globe") }
            }
        }
        .navigationTitle("Laisser un avis")
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fermer") { fermer() } } }
    }

    private func publier(_ u: URL?) {
        UIPasteboard.general.string = texte
        Retour.succes()
        if let u { ouvrir(u) }
    }
}

enum Images {
    /// Réduit une photo pour qu'elle reste légère à synchroniser.
    static func reduire(_ d: Data, max cote: CGFloat) -> Data? {
        guard let ui = UIImage(data: d) else { return nil }
        let k = min(1, cote / Swift.max(ui.size.width, ui.size.height))
        let t = CGSize(width: ui.size.width * k, height: ui.size.height * k)
        return UIGraphicsImageRenderer(size: t).image { _ in ui.draw(in: CGRect(origin: .zero, size: t)) }.jpegData(compressionQuality: 0.75)
    }
}

// MARK: - Hôtels

struct HotelsListe: View {
    let moi: String
    @Query private var hotels: [Hotel]
    @State private var ajout = false

    private var tries: [Hotel] {
        hotels.sorted { a, b in
            let fa = a.etat == .fini, fb = b.etat == .fini
            if fa != fb { return !fa }
            return fa ? a.arrivee > b.arrivee : (a.arrivee.isEmpty ? "9999" : a.arrivee) < (b.arrivee.isEmpty ? "9999" : b.arrivee)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            TitreSection("Les hôtels") {
                Button { ajout = true } label: { Label("Ajouter", systemImage: "plus") }.buttonStyle(.bordered)
            }
            if hotels.isEmpty {
                ContentUnavailableView("Pas encore d'hôtel", systemImage: "bed.double",
                                       description: Text("Note la réservation dès qu'elle est faite : dates, prix, numéro, options et date limite d'annulation gratuite."))
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 14)], spacing: 14) {
                ForEach(tries) { CarteHotel(h: $0, moi: moi) }
            }
        }
        .sheet(isPresented: $ajout) { NavigationStack { FormulaireHotel(moi: moi, h: nil) } }
    }
}

struct CarteHotel: View {
    let h: Hotel
    let moi: String
    @Query private var evenements: [Evenement]
    @Query private var photos: [PhotoLoisir]
    @State private var feuille: Feuille?
    enum Feuille: String, Identifiable { case modifier, sejour, avis; var id: String { rawValue } }

    var body: some View {
        let voyage = Vacances.voyage(le: h.arrivee, parmi: evenements)
        Porte {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(h.nom).font(Theme.titre(20))
                    Text([h.ville, voyage?.titre ?? ""].filter { !$0.isEmpty }.joined(separator: " · "))
                        .font(.willys(.subheadline)).foregroundStyle(.secondary)
                }
                Spacer()
                Etiquette(texte: libelleEtat, couleur: h.etat == .aVenir ? Theme.accent : h.etat == .enCours ? Theme.ok : .secondary)
            }
            VStack(alignment: .leading, spacing: 6) {
                if !h.arrivee.isEmpty {
                    Label("\(Jour.joli(h.arrivee, .dateTime.weekday(.abbreviated).day().month(.abbreviated)))\(h.depart.isEmpty ? "" : " → " + Jour.joli(h.depart, .dateTime.weekday(.abbreviated).day().month(.abbreviated)))\(h.nuits > 0 ? " · \(h.nuits) nuit\(h.nuits > 1 ? "s" : "")" : "") · \(h.personnes) pers.", systemImage: "calendar")
                }
                if let u = LiensLoisirs.carte(nom: h.nom, lieu: h.adresse.isEmpty ? h.ville : h.adresse), !(h.adresse.isEmpty && h.ville.isEmpty) {
                    Link(destination: u) { Label(h.adresse.isEmpty ? h.ville : h.adresse, systemImage: "mappin.and.ellipse") }
                }
                if let t = LiensLoisirs.tel(h.tel) { Link(destination: t) { Label(h.tel, systemImage: "phone") } }
                if h.prixRetenu > 0 {
                    Label("\(h.prixRetenu.euros)\(h.nuits > 0 ? " · \((h.prixRetenu / Double(h.nuits)).euros) la nuit" : "")", systemImage: "eurosign")
                }
                if !h.confirmation.isEmpty { Label("Réservation \(h.confirmation)", systemImage: "number") }
            }
            .font(.willys(.subheadline))
            if !h.options.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(OptionsHotel.toutes.filter { h.options.contains($0.id) }, id: \.id) { Etiquette(texte: $0.nom) }
                }
            }
            if !h.annulation.isEmpty && h.etat == .aVenir {
                let j = Jour.joursJusqua(h.annulation)
                Text(j < 0 ? "Annulation gratuite terminée depuis le \(Jour.joli(h.annulation, .dateTime.day().month(.wide)))"
                     : "Annulation gratuite jusqu'au \(Jour.joli(h.annulation))\(j <= 3 ? " — plus que \(j) jour\(j > 1 ? "s" : "")" : "")")
                    .font(.willys(.footnote, poids: .semibold)).foregroundStyle(j <= 3 ? Theme.alerte : Theme.ok)
            }
            HStack(spacing: 8) {
                if let u = LiensLoisirs.sur(h.lienResa) { Link("Ma réservation", destination: u).buttonStyle(.borderedProminent) }
                if let t = LiensLoisirs.tel(h.tel) { Link("Appeler", destination: t).buttonStyle(.bordered) }
                if let u = LiensLoisirs.sur(h.site) { Link("Le site", destination: u).buttonStyle(.bordered) }
            }
            .buttonBorderShape(.capsule).font(.willys(.subheadline, poids: .bold))
            if h.avisNote > 0 {
                Text("\(etoiles(h.avisNote > 5 ? h.avisNote / 2 : h.avisNote)) \(h.avisNote.formatted(.number.precision(.fractionLength(0...1))))\(h.avisNote > 5 ? "/10" : "/5") · avis clients \(h.avisSource)\(h.avisNb.isEmpty ? "" : " · \(h.avisNb) avis")")
                    .font(.willys(.footnote)).foregroundStyle(.secondary)
            }
            if h.etat == .fini || h.noteFinale > 0 {
                Divider()
                Text("Le séjour\(h.noteFinale > 0 ? " · \(etoiles(h.noteFinale)) \(h.noteFinale.formatted(.number.precision(.fractionLength(0...1))))/5" : "")")
                    .font(.willys(.subheadline, poids: .bold))
                GaleriePhotos(photos: photos.filter { $0.parent == h.cle })
                ForEach(h.avis.sorted { $0.key < $1.key }.filter { !$0.value.mot.isEmpty }, id: \.key) { k, a in
                    HStack(alignment: .top) { Aimant(membre: k, taille: 24); Text("« \(a.mot) »").font(Theme.main(18)) }
                }
            }
            HStack {
                if h.etat == .fini || h.etat == .enCours {
                    Button(h.noteFinale > 0 ? "Modifier le séjour" : "Noter le séjour") { feuille = .sejour }.buttonStyle(.borderedProminent)
                    Button("Laisser un avis") { feuille = .avis }.buttonStyle(.bordered)
                }
                Button("Modifier") { feuille = .modifier }.buttonStyle(.bordered)
            }
            .buttonBorderShape(.capsule)
        }
        .sheet(item: $feuille) { f in
            NavigationStack {
                switch f {
                case .modifier: FormulaireHotel(moi: moi, h: h)
                case .sejour: FormulaireSejour(moi: moi, h: h)
                case .avis: LaisserAvis(nom: h.nom, lieu: h.adresse.isEmpty ? h.ville : h.adresse, texte: h.avis[moi]?.mot ?? "", note: h.avis[moi]?.stars ?? 0)
                }
            }
        }
    }

    private var libelleEtat: String {
        switch h.etat { case .aDater: "À dater"; case .aVenir: "À venir"; case .enCours: "En cours"; case .fini: "Séjour fini" }
    }
}

struct FormulaireHotel: View {
    let moi: String
    let h: Hotel?
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var fermer
    @Environment(\.openURL) private var ouvrir
    @Query private var evenements: [Evenement]
    @State private var nom = ""
    @State private var ville = ""
    @State private var prix = ""
    @State private var confirmation = ""
    @State private var lienResa = ""
    @State private var adresse = ""
    @State private var tel = ""
    @State private var site = ""
    @State private var note = ""
    @State private var arrivee = Date.now
    @State private var depart = Date.now.addingTimeInterval(86400)
    @State private var personnes = 2
    @State private var options: Set<String> = []
    @State private var avecAnnulation = false
    @State private var annulation = Date.now

    var body: some View {
        Form {
            Section {
                TextField("L'hôtel — ex. Campanile PRIME Chaponost", text: $nom)
                TextField("Où ?", text: $ville)
            }
            Section {
                DatePicker("Arrivée", selection: $arrivee, displayedComponents: .date)
                DatePicker("Départ", selection: $depart, in: arrivee..., displayedComponents: .date)
                Stepper("Personnes : \(personnes)", value: $personnes, in: 1...20)
                Button { if let u = LiensLoisirs.booking([nom, ville].filter { !$0.isEmpty }.joined(separator: ", "), arrivee: Jour.chaine(arrivee), depart: Jour.chaine(depart), personnes: personnes) { ouvrir(u) } } label: {
                    Label("Chercher sur Booking avec ces dates", systemImage: "magnifyingglass")
                }
            }
            Section("La réservation") {
                TextField("Prix total réservé (€)", text: $prix).keyboardType(.decimalPad)
                TextField("N° de réservation", text: $confirmation)
                TextField("Lien de la réservation (https://…)", text: $lienResa).keyboardType(.URL).textInputAutocapitalization(.never)
            }
            Section {
                ForEach(OptionsHotel.toutes, id: \.id) { o in
                    Toggle(o.nom, isOn: Binding(get: { options.contains(o.id) }, set: { if $0 { options.insert(o.id) } else { options.remove(o.id) } }))
                }
                Toggle("Annulation gratuite", isOn: $avecAnnulation)
                if avecAnnulation { DatePicker("jusqu'au", selection: $annulation, displayedComponents: .date) }
            } header: { Text("Les options") } footer: { Text("Un rappel « Annuler gratuitement ? » est mis au calendrier à la date limite.") }
            Section(h == nil ? "Coordonnées (facultatif : Claude les cherche)" : "Coordonnées") {
                TextField("Adresse", text: $adresse)
                TextField("Téléphone", text: $tel).keyboardType(.phonePad)
                TextField("Site (https://…)", text: $site).keyboardType(.URL).textInputAutocapitalization(.never)
                TextField("Un mot — ex. chambre côté jardin demandée", text: $note)
            }
            if let h, h.par == moi {
                Button("Retirer cet hôtel", role: .destructive) { ctx.delete(h); ctx.enregistrer(); fermer() }
            }
        }
        .environment(\.locale, Locale(identifier: "fr_BE"))
        .navigationTitle(h?.nom ?? "Un hôtel")
        .onAppear {
            guard let h else { return }
            nom = h.nom; ville = h.ville; prix = h.prix > 0 ? String(h.prix) : ""; confirmation = h.confirmation; lienResa = h.lienResa
            adresse = h.adresse; tel = h.tel; site = h.site; note = h.note; personnes = h.personnes; options = Set(h.options)
            if !h.arrivee.isEmpty { arrivee = Jour.date(h.arrivee) }
            if !h.depart.isEmpty { depart = Jour.date(h.depart) }
            if !h.annulation.isEmpty { avecAnnulation = true; annulation = Jour.date(h.annulation) }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Annuler") { fermer() } }
            ToolbarItem(placement: .confirmationAction) { Button("Enregistrer") { enregistrer() }.disabled(nom.trimmingCharacters(in: .whitespaces).isEmpty) }
        }
    }

    private func enregistrer() {
        let x = h ?? { let n = Hotel(nom: nom, ville: ville, foyer: Famille.foyer(de: moi) ?? "", par: moi); ctx.insert(n); return n }()
        let ancienneAnnulation = x.annulation
        x.nom = nom.trimmingCharacters(in: .whitespaces); x.ville = ville; x.arrivee = Jour.chaine(arrivee); x.depart = Jour.chaine(max(depart, arrivee))
        x.personnes = personnes; x.prix = Double(prix.replacingOccurrences(of: ",", with: ".")) ?? 0; x.confirmation = confirmation
        x.lienResa = lienResa.hasPrefix("https://") ? lienResa : ""; x.options = OptionsHotel.toutes.map(\.id).filter { options.contains($0) }
        x.adresse = adresse; x.tel = tel; x.site = site.hasPrefix("https://") ? site : ""; x.note = note
        if h == nil && adresse.isEmpty { x.infosStatut = "a_chercher" }
        x.annulation = avecAnnulation ? Jour.chaine(annulation) : ""
        // le rappel d'annulation au calendrier
        if !x.annulation.isEmpty && x.annulation != ancienneAnnulation && x.annulation >= Jour.aujourdhui {
            let titre = "Annuler gratuitement ? \(x.nom) (dernier jour)"
            if let e = evenements.first(where: { $0.cle == x.rappel }) {
                e.debut = x.annulation; e.fin = x.annulation; e.titre = titre
            } else {
                let e = Evenement(type: "voyage", titre: titre, debut: x.annulation, fin: x.annulation, personnes: [moi], par: moi)
                ctx.insert(e); x.rappel = e.cle
            }
        }
        Retour.succes(); ctx.enregistrer(); Base.rafraichirWidgets(); fermer()
    }
}

struct FormulaireSejour: View {
    let moi: String
    let h: Hotel
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var fermer
    @State private var note = 0
    @State private var mot = ""
    @State private var prixFinal = ""
    @State private var choixChambre: PhotosPickerItem?
    @State private var choixAmbiance: PhotosPickerItem?
    @State private var nouvelles: [(quoi: String, data: Data)] = []

    var body: some View {
        Form {
            Section("La note finale") {
                HStack {
                    ForEach(1...5, id: \.self) { n in
                        Button { Retour.selection(); note = n } label: {
                            Image(systemName: n <= note ? "star.fill" : "star").font(.title).foregroundStyle(Theme.accent)
                        }.buttonStyle(.plain).accessibilityLabel("\(n) étoile\(n > 1 ? "s" : "")")
                    }
                }
                TextField("Ex. literie parfaite, petit-déjeuner copieux", text: $mot, axis: .vertical).lineLimit(2...6)
            }
            Section {
                TextField("Prix payé au final (€)", text: $prixFinal).keyboardType(.decimalPad)
            } footer: { Text("Avec la taxe de séjour, les extras…") }
            Section("Les photos") {
                HStack {
                    PhotosPicker(selection: $choixChambre, matching: .images) { Label("La chambre", systemImage: "bed.double") }
                    Spacer()
                    PhotosPicker(selection: $choixAmbiance, matching: .images) { Label("L'ambiance", systemImage: "sparkles") }
                }
                if !nouvelles.isEmpty { Text("\(nouvelles.count) photo\(nouvelles.count > 1 ? "s" : "") à ajouter").foregroundStyle(.secondary) }
            }
        }
        .navigationTitle(h.nom)
        .onAppear { note = h.avis[moi]?.stars ?? Int(h.noteFinale.rounded()); mot = h.avis[moi]?.mot ?? ""
            prixFinal = h.prixRetenu > 0 ? String(h.prixRetenu) : "" }
        .onChange(of: choixChambre) { _, i in charger(i, "chambre") }
        .onChange(of: choixAmbiance) { _, i in charger(i, "ambiance") }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Annuler") { fermer() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Enregistrer") {
                    var a = h.avis; a[moi] = AvisMembre(stars: note, mot: mot); h.avis = a
                    let notes = a.values.map(\.stars).filter { $0 > 0 }
                    h.noteFinale = notes.isEmpty ? 0 : (Double(notes.reduce(0, +)) / Double(notes.count) * 10).rounded() / 10
                    h.prixFinal = Double(prixFinal.replacingOccurrences(of: ",", with: ".")) ?? 0
                    nouvelles.forEach { ctx.insert(PhotoLoisir(parent: h.cle, quoi: $0.quoi, image: $0.data, par: moi)) }
                    Retour.succes(); ctx.enregistrer(); fermer()
                }
            }
        }
    }

    private func charger(_ item: PhotosPickerItem?, _ quoi: String) {
        Task {
            guard let d = try? await item?.loadTransferable(type: Data.self), let r = Images.reduire(d, max: 1000) else { return }
            nouvelles.append((quoi, r)); choixChambre = nil; choixAmbiance = nil
        }
    }
}

// MARK: - Le budget loisirs (visible seulement par le foyer)

struct BudgetLoisirs: View {
    let moi: String
    @Query private var sorties: [Sortie]
    @Query private var hotels: [Hotel]
    @Query private var evenements: [Evenement]
    @State private var annee = Calendar.current.component(.year, from: .now)

    struct Ligne: Identifiable { let id = UUID(); let hotel: Bool; let nom: String; let date: String; let v: Double; let voyage: String? }

    private var foyer: String { Famille.foyer(de: moi) ?? "" }
    private var lignes: [Ligne] {
        let an = String(annee)
        let s = sorties.filter { $0.foyer == foyer && $0.montant > 0 && $0.date.hasPrefix(an) }
            .map { Ligne(hotel: false, nom: $0.nom, date: $0.date, v: $0.montant, voyage: Vacances.voyage(le: $0.date, parmi: evenements)?.titre) }
        let h = hotels.filter { $0.foyer == foyer && $0.prixRetenu > 0 && $0.arrivee.hasPrefix(an) }
            .map { Ligne(hotel: true, nom: $0.nom, date: $0.arrivee, v: $0.prixRetenu, voyage: Vacances.voyage(le: $0.arrivee, parmi: evenements)?.titre) }
        return (s + h).sorted { $0.date > $1.date }
    }

    var body: some View {
        let toutes = lignes, hors = toutes.filter { $0.voyage == nil }, vac = toutes.filter { $0.voyage != nil }
        let somme: ([Ligne]) -> Double = { $0.reduce(0) { $0 + $1.v } }
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("LES LOISIRS \(Famille.nomFoyer(foyer).uppercased())").font(.willys(.caption, poids: .semibold))
                Text(somme(toutes).euros).font(Theme.titre(48)).monospacedDigit()
                    .contentTransition(.numericText(value: somme(toutes)))
                Stepper("Année \(String(annee))", value: $annee, in: 2020...2100).font(.willys(.subheadline))
                Text("Visible seulement par votre foyer. Une sortie pendant un voyage du calendrier compte dans « Vacances ».")
                    .font(.willys(.footnote)).foregroundStyle(.secondary)
            }
            .padding(18)
            .background(Theme.ok.opacity(0.16), in: RoundedRectangle(cornerRadius: 20, style: .continuous))

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                tuile(somme(hors.filter { !$0.hotel }), "restaurants hors vacances")
                tuile(somme(hors.filter { $0.hotel }), "hôtels hors vacances")
                tuile(somme(vac), "pendant les vacances")
                tuile(somme(hors) / Double(max(1, annee == Calendar.current.component(.year, from: .now) ? Calendar.current.component(.month, from: .now) : 12)), "par mois, hors vacances")
            }

            Porte {
                Text("Les vacances").font(Theme.titre(20))
                let groupes = Dictionary(grouping: vac, by: { $0.voyage ?? "" })
                if groupes.isEmpty { Text("Les restaurants et hôtels datés pendant un voyage du calendrier apparaîtront ici.").foregroundStyle(.secondary) }
                ForEach(groupes.keys.sorted(), id: \.self) { t in
                    HStack { Text(t).bold(); Spacer(); Text(somme(groupes[t] ?? []).euros).bold().monospacedDigit() }
                    ForEach(groupes[t] ?? []) { ligne($0) }
                }
            }
            Porte {
                Text("Le reste de l'année").font(Theme.titre(20))
                if hors.isEmpty { Text("Note l'addition avec « On y est allés » sur un restaurant.").foregroundStyle(.secondary) }
                ForEach(hors.prefix(20)) { ligne($0) }
            }
        }
    }

    private func tuile(_ v: Double, _ libelle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(v.euros).font(Theme.titre(22)).monospacedDigit()
            Text(libelle).font(.willys(.footnote)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(14)
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
    }

    private func ligne(_ l: Ligne) -> some View {
        HStack {
            Image(systemName: l.hotel ? "bed.double" : "fork.knife").foregroundStyle(.secondary).frame(width: 22)
            VStack(alignment: .leading) {
                Text(l.nom).bold()
                Text(Jour.joli(l.date, .dateTime.day().month(.abbreviated))).font(.willys(.caption)).foregroundStyle(.secondary)
            }
            Spacer()
            Text(l.v.euros).monospacedDigit()
        }
    }
}

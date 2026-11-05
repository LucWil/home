import SwiftUI
import SwiftData

// « Près de chez nous » : marchés de Noël, marchés de la semaine, activités, bons plans et pharmacie de garde.
// Les données sont publiques : la recherche automatique les publie dans donnees/agenda.json du dépôt GitHub,
// l'app les lit là (et garde la dernière copie pour être utilisable hors connexion).

struct ActiviteCoin: Codable, Identifiable, Hashable {
    var id: String
    var titre: String
    var debut: String
    var fin: String?
    var heure: String?
    var commune: String?
    var lieu: String?
    var zone: String?
    var cat: String?
    var resume: String?
    var prix: String?
    var enfants: Bool?
    var lien: String?
    var source: String?

    var finReelle: String { (fin ?? "").isEmpty || (fin ?? "") < debut ? debut : fin! }
    var estNoel: Bool { cat == "marche" && titre.range(of: "Noël", options: [.caseInsensitive, .diacriticInsensitive]) != nil }
    var icone: String {
        switch cat {
        case "marche": "basket"
        case "brocante": "chair.lounge"
        case "fete": "party.popper"
        case "concert": "music.note"
        case "spectacle": "theatermasks"
        case "expo": "photo.artframe"
        case "enfants": "teddybear"
        case "sport", "nature": "figure.walk"
        case "gastronomie": "wineglass"
        case "atelier": "scissors"
        default: "mappin"
        }
    }
}

struct BonPlan: Codable, Identifiable, Hashable {
    var id: String
    var titre: String
    var enseigne: String?
    var cat: String?
    var remise: String?
    var prix: String?
    var prixAvant: String?
    var du: String?
    var au: String?
    var lien: String?
    var source: String?
    var resume: String?
    var pourQui: String?
}

struct MarcheHebdo: Codable, Hashable {
    var commune: String
    var jours: [Int]           // lundi = 1 … dimanche = 7
    var jour: String
    var heure: String
    var lieu: String
    var note: String?
    var source: String?
    var lien: String?
    var voisine: Bool?

    /// Dans combien de jours (0 = aujourd'hui).
    var dans: Int {
        let auj = (Calendar.current.component(.weekday, from: .now) + 5) % 7 + 1
        return jours.map { ($0 - auj + 7) % 7 }.min() ?? 9
    }
}

struct PharmacieGarde: Codable, Hashable {
    var zone: String?
    var commune: String?
    var nom: String
    var adresse: String?
    var tel: String?
    var du: String?
    var au: String?
    var source: String?
    var lien: String?
}

struct DonneesCoin: Codable {
    var maj: String
    var agenda: [ActiviteCoin]
    var bonsplans: [BonPlan]
    var marches: [MarcheHebdo]
    var pharmacies: [PharmacieGarde]
}

@MainActor
final class Coin: ObservableObject {
    static let partage = Coin()
    static let adresse = URL(string: "https://raw.githubusercontent.com/LucWil/home/claude/willys-application-t5ll8c/donnees/agenda.json")!
    @Published var donnees: DonneesCoin?
    @Published var charge = false

    init() {
        if let d = Base.reglages.data(forKey: "coin.cache") { donnees = try? JSONDecoder().decode(DonneesCoin.self, from: d) }
    }

    func rafraichir() async {
        var r = URLRequest(url: Self.adresse); r.cachePolicy = .reloadIgnoringLocalCacheData
        if let (d, _) = try? await URLSession.shared.data(for: r), let v = try? JSONDecoder().decode(DonneesCoin.self, from: d) {
            donnees = v; Base.reglages.set(d, forKey: "coin.cache")
        }
        charge = true
    }

    var aVenir: [ActiviteCoin] { (donnees?.agenda ?? []).filter { $0.finReelle >= Jour.aujourdhui }.sorted { $0.debut < $1.debut } }
    var noels: [ActiviteCoin] { aVenir.filter { $0.estNoel && ($0.zone ?? "maison") == "maison" } }
    var bonsPlans: [BonPlan] { (donnees?.bonsplans ?? []).filter { ($0.au ?? "9999") >= Jour.aujourdhui }.sorted { ($0.au ?? "9999") < ($1.au ?? "9999") } }
    var marches: [MarcheHebdo] { (donnees?.marches ?? []).sorted { ($0.dans, $0.voisine == true ? 1 : 0) < ($1.dans, $1.voisine == true ? 1 : 0) } }
}

/// La carte de l'accueil.
struct CartePresDeChezNous: View {
    let moi: String
    @ObservedObject private var coin = Coin.partage

    var body: some View {
        NavigationLink { PresDeChezNousView(moi: moi) } label: {
            Porte(teinte: Color(hex: 0x2C9A8A)) {
                HStack {
                    Label("Près de chez nous", systemImage: "location.north.circle").font(.willys(.headline))
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(.secondary)
                }
                let auj = coin.marches.filter { $0.dans == 0 }
                if !auj.isEmpty {
                    Text("🧺 Aujourd'hui : marché à \(auj.map(\.commune).joined(separator: ", "))").font(.willys(.subheadline))
                }
                if mois >= 11 || mois == 1, let n = coin.noels.first {
                    Text("🎄 \(coin.noels.count) marché\(coin.noels.count > 1 ? "s" : "") de Noël · le premier : \(n.commune ?? ""), \(Jour.joli(n.debut, .dateTime.day().month(.wide)))")
                        .font(.willys(.subheadline))
                }
                if let a = coin.aVenir.first(where: { !$0.estNoel && ($0.zone ?? "maison") == "maison" }) {
                    Text("📍 \(a.titre) · \(Jour.joli(a.debut, .dateTime.weekday(.abbreviated).day().month(.abbreviated)))").font(.willys(.subheadline)).lineLimit(2)
                }
                if !coin.bonsPlans.isEmpty {
                    Text("🛍 \(coin.bonsPlans.count) bon\(coin.bonsPlans.count > 1 ? "s" : "") plan\(coin.bonsPlans.count > 1 ? "s" : "")").font(.willys(.subheadline))
                }
                if coin.donnees == nil { Text("Marchés, fêtes, concerts, pharmacie de garde").font(.willys(.subheadline)).foregroundStyle(.secondary) }
            }
            .foregroundStyle(.primary)
        }
        .buttonStyle(.plain)
        .task { if !coin.charge { await coin.rafraichir() } }
    }
    private var mois: Int { Calendar.current.component(.month, from: .now) }
}

struct PresDeChezNousView: View {
    let moi: String
    @Environment(\.modelContext) private var ctx
    @Environment(\.openURL) private var ouvrir
    @ObservedObject private var coin = Coin.partage
    @Query private var evenements: [Evenement]
    @State private var commune = ""
    @State private var ajoute: Set<String> = []

    private let communes = ["Chaumont-Gistoux", "Perwez", "Jodoigne", "Ramillies", "Wavre"]
    private var mois: Int { Calendar.current.component(.month, from: .now) }
    private var saisonNoel: Bool { mois >= 11 || mois == 1 }

    var body: some View {
        List {
            pharmacie
            if saisonNoel && !coin.noels.isEmpty {
                Section("🎄 Les marchés de Noël") { ForEach(coin.noels) { ligne($0) } }
            }
            if !coin.marches.isEmpty {
                Section {
                    ForEach(coin.marches, id: \.self) { m in
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text(m.commune).bold()
                                if m.dans == 0 { Etiquette(texte: "aujourd'hui", couleur: Theme.ok) }
                                else if m.dans == 1 { Etiquette(texte: "demain") }
                                if m.voisine == true { Etiquette(texte: "dans les environs") }
                            }
                            Text("\(m.jour) · \(m.heure)").font(.willys(.subheadline))
                            Button { carte(m.lieu + ", " + m.commune) } label: { Label(m.lieu, systemImage: "mappin.and.ellipse").font(.willys(.footnote)) }
                                .buttonStyle(.borderless)
                            if let n = m.note, !n.isEmpty { Text(n).font(.willys(.caption)).foregroundStyle(.secondary) }
                        }
                    }
                } header: { Text("🧺 Les marchés de la semaine") } footer: { Text("Les jours fériés et en été, les horaires peuvent changer.") }
            }
            Section {
                Picker("Commune", selection: $commune) {
                    Text("Toutes").tag("")
                    ForEach(communes, id: \.self) { Text($0).tag($0) }
                }
                let l = coin.aVenir.filter { ($0.zone ?? "maison") == "maison" && !(saisonNoel && $0.estNoel) && (commune.isEmpty || $0.commune == commune) }
                if l.isEmpty { Text("Rien pour l'instant. La recherche passe le lundi et le jeudi soir.").foregroundStyle(.secondary) }
                ForEach(l) { ligne($0) }
            } header: { Text("Les activités") }
            let fj = coin.aVenir.filter { $0.zone == "frejus" }
            if !fj.isEmpty { Section("☀️ Fréjus et environs") { ForEach(fj) { ligne($0) } } }
            if !coin.bonsPlans.isEmpty {
                Section {
                    ForEach(coin.bonsPlans) { b in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(b.titre).bold()
                                if let r = b.remise, !r.isEmpty { Etiquette(texte: r, couleur: Theme.ok) }
                            }
                            Text([b.enseigne, b.prix, b.pourQui.map { "pour " + $0 }].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                                .font(.willys(.subheadline))
                            Text(periode(b)).font(.willys(.caption)).foregroundStyle(.secondary)
                            if let r = b.resume, !r.isEmpty { Text(r).font(.willys(.footnote)).foregroundStyle(.secondary) }
                            HStack {
                                if let u = sure(b.lien) { Link("Voir l'offre", destination: u).buttonStyle(.bordered) }
                                ShareLink(item: "Bon plan : \(b.titre)" + (b.enseigne.map { " chez \($0)" } ?? "") + (b.lien.map { "\n\($0)" } ?? "")) { Image(systemName: "square.and.arrow.up") }
                                    .buttonStyle(.bordered)
                            }
                            .buttonBorderShape(.capsule)
                        }
                    }
                } header: { Text("🛍 Black Friday et bons plans") } footer: {
                    Text("Compare le prix sur deux sites avant d'acheter : certaines « remises » partent d'un prix gonflé.")
                }
            }
            Section {
                Text("Trouvé par Claude dans les agendas des communes, des offices du tourisme et des journaux, et sur les pages Facebook et Instagram publiques" + (coin.donnees.map { " · mis à jour le \(Jour.joli($0.maj, .dateTime.day().month(.wide)))" } ?? "") + ". Vérifie la date et l'heure à la source avant de partir.")
                    .font(.willys(.footnote)).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Près de chez nous")
        .refreshable { await coin.rafraichir() }
        .task { await coin.rafraichir() }
        .overlay { if coin.donnees == nil && coin.charge { ContentUnavailableView("Pas de connexion", systemImage: "wifi.slash", description: Text("L'agenda arrivera à la prochaine connexion.")) } }
    }

    private var pharmacie: some View {
        Section {
            let l = (coin.donnees?.pharmacies ?? []).filter { ($0.zone ?? "maison") == "maison" && ($0.au ?? "9999") >= Jour.aujourdhui }
            ForEach(l, id: \.self) { p in
                VStack(alignment: .leading, spacing: 2) {
                    Text(p.nom).bold()
                    Text([p.commune, p.adresse].compactMap { $0 }.joined(separator: " · ")).font(.willys(.footnote)).foregroundStyle(.secondary)
                    if let t = p.tel, let u = URL(string: "tel:" + t.filter { $0.isNumber || $0 == "+" }) { Link("Appeler \(t)", destination: u) }
                }
            }
            if l.isEmpty { Text("La garde de la semaine n'est pas encore trouvée : le service officiel la donne d'après ton code postal.").font(.willys(.footnote)).foregroundStyle(.secondary) }
            Link(destination: URL(string: "tel:090399000")!) { Label("0903 99 000 · service officiel (1,50 €/min)", systemImage: "phone") }
            Link(destination: URL(string: "https://www.pharmacie.be")!) { Label("pharmacie.be", systemImage: "safari") }
            Link(destination: URL(string: "tel:3237")!) { Label("En France (Fréjus) : 3237", systemImage: "phone") }
        } header: { Text("💊 La pharmacie de garde") }
    }

    private func ligne(_ a: ActiviteCoin) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label { Text(a.titre).bold() } icon: { Image(systemName: a.icone).foregroundStyle(Theme.accent) }
            Text(quand(a) + ((a.heure ?? "").isEmpty ? "" : " · \(a.heure!)")).font(.willys(.subheadline))
            if !(a.lieu ?? "").isEmpty || !(a.commune ?? "").isEmpty {
                Button { carte([a.lieu, a.commune].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")) } label: {
                    Label([a.lieu, a.commune].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", "), systemImage: "mappin.and.ellipse").font(.willys(.footnote))
                }
                .buttonStyle(.borderless)
            }
            if let r = a.resume, !r.isEmpty { Text(r).font(.willys(.footnote)).foregroundStyle(.secondary) }
            HStack {
                if a.enfants == true { Etiquette(texte: "avec les petites") }
                if let p = a.prix, !p.isEmpty { Etiquette(texte: p) }
                Spacer()
                if let u = sure(a.lien) { Link(destination: u) { Image(systemName: "safari") }.buttonStyle(.borderless).accessibilityLabel("Source : \(a.source ?? "")") }
                if deja(a) || ajoute.contains(a.id) {
                    Image(systemName: "calendar.badge.checkmark").foregroundStyle(Theme.ok).accessibilityLabel("Au calendrier")
                } else {
                    Button { auCalendrier(a) } label: { Image(systemName: "calendar.badge.plus") }.buttonStyle(.borderless).accessibilityLabel("Ajouter au calendrier")
                }
                ShareLink(item: "\(a.titre) — \(quand(a)) à \(a.commune ?? "")" + (a.lien.map { "\n\($0)" } ?? "")) { Image(systemName: "square.and.arrow.up") }
                    .buttonStyle(.borderless)
            }
            .font(.title3)
        }
        .padding(.vertical, 2)
    }

    private func quand(_ a: ActiviteCoin) -> String {
        a.finReelle > a.debut
            ? "\(Jour.joli(a.debut, .dateTime.day().month(.abbreviated))) → \(Jour.joli(a.finReelle, .dateTime.day().month(.abbreviated)))"
            : Jour.joli(a.debut, .dateTime.weekday(.wide).day().month(.wide))
    }
    private func periode(_ b: BonPlan) -> String {
        if let d = b.du, !d.isEmpty, d > Jour.aujourdhui { return "dès le \(Jour.joli(d, .dateTime.day().month(.wide)))" }
        if let a = b.au, !a.isEmpty { return "jusqu'au \(Jour.joli(a, .dateTime.day().month(.wide)))" }
        return "en cours"
    }
    private func sure(_ s: String?) -> URL? { s.flatMap { $0.hasPrefix("https://") ? URL(string: $0) : nil } }
    private func carte(_ lieu: String) {
        var c = URLComponents(string: "https://maps.apple.com/")!; c.queryItems = [URLQueryItem(name: "q", value: lieu + ", Belgique")]
        if let u = c.url { ouvrir(u) }
    }
    private func titreCalendrier(_ a: ActiviteCoin) -> String { a.titre + ((a.commune ?? "").isEmpty ? "" : " · \(a.commune!)") }
    private func deja(_ a: ActiviteCoin) -> Bool { evenements.contains { $0.debut == a.debut && $0.titre == titreCalendrier(a) } }
    private func auCalendrier(_ a: ActiviteCoin) {
        ctx.insert(Evenement(type: "ensemble", titre: titreCalendrier(a), debut: a.debut, fin: a.finReelle, personnes: [moi], par: moi))
        ctx.enregistrer(); ajoute.insert(a.id); Retour.succes()
    }
}

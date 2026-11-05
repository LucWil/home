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

/// La une de l'accueil : le marché du jour en grand, puis « À découvrir ».
struct CartePresDeChezNous: View {
    let moi: String
    @ObservedObject private var coin = Coin.partage
    @Environment(\.openURL) private var ouvrir

    private struct Decouverte: Identifiable { let a: ActiviteCoin; let badge: String; var id: String { a.id } }
    private struct Gros: Identifiable { let id: String; let icone: String; let titre: String; let heure: String; let lieu: String; let commune: String; let voisine: Bool }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            let auj = aujourdhui
            if !auj.isEmpty {
                carteVerte(titre: "Aujourd'hui près de chez nous", lignes: auj, plein: true)
            } else if !demain.isEmpty {
                carteVerte(titre: "Demain", lignes: demain, plein: false)
            }
            let d = decouvertes
            if !d.isEmpty || !coin.bonsPlans.isEmpty {
                HStack {
                    Text("À découvrir").font(Theme.titre(20))
                    Spacer()
                    NavigationLink("Tout voir") { PresDeChezNousView(moi: moi) }.font(.willys(.subheadline, poids: .semibold))
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 10) {
                        ForEach(d) { x in
                            NavigationLink { PresDeChezNousView(moi: moi) } label: { vignette(badge: x.badge, icone: x.a.icone, titre: x.a.titre, l1: quand(x.a), l2: [x.a.commune, x.a.heure].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")) }
                                .buttonStyle(.plain)
                        }
                        ForEach(coin.bonsPlans.prefix(3)) { b in
                            NavigationLink { PresDeChezNousView(moi: moi) } label: { vignette(badge: "bon plan", icone: "tag", titre: b.titre, l1: [b.enseigne, b.remise].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "), l2: b.au.map { "jusqu'au \(Jour.joli($0, .dateTime.day().month(.abbreviated)))" } ?? "") }
                                .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
            if coin.donnees == nil {
                NavigationLink { PresDeChezNousView(moi: moi) } label: {
                    Porte(teinte: Color(hex: 0x2C9A8A)) { Label("Près de chez nous : marchés, fêtes, concerts, pharmacie de garde", systemImage: "location.north.circle") }
                }
                .buttonStyle(.plain)
            }
        }
        .task { if !coin.charge { await coin.rafraichir() } }
    }

    private var jourISO: Int { (Calendar.current.component(.weekday, from: .now) + 5) % 7 + 1 }
    private var aujourdhui: [Gros] {
        let t = Jour.aujourdhui
        let ev = coin.aVenir.filter { ($0.zone ?? "maison") == "maison" && $0.debut <= t && $0.finReelle >= t }
            .map { Gros(id: $0.id, icone: $0.icone, titre: $0.titre, heure: $0.heure ?? "", lieu: [$0.lieu, $0.commune].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", "), commune: $0.commune ?? "", voisine: false) }
        let m = coin.marches.filter { $0.jours.contains(jourISO) }
            .map { Gros(id: $0.commune + $0.jour, icone: "basket", titre: "Marché à \($0.commune)", heure: $0.heure, lieu: $0.lieu, commune: $0.commune, voisine: $0.voisine == true) }
        return ev + m
    }
    private var demain: [Gros] {
        let j = jourISO % 7 + 1
        return coin.marches.filter { $0.jours.contains(j) }
            .map { Gros(id: $0.commune + $0.jour, icone: "basket", titre: "Marché à \($0.commune)", heure: $0.heure, lieu: $0.lieu, commune: $0.commune, voisine: $0.voisine == true) }
    }
    private var decouvertes: [Decouverte] {
        let t = Jour.aujourdhui
        let l = coin.aVenir.filter { ($0.zone ?? "maison") == "maison" && !($0.debut <= t && $0.finReelle >= t) }
        let cal = Calendar.current
        let samedi = cal.nextDate(after: .now.addingTimeInterval(-86400), matching: DateComponents(weekday: 7), matchingPolicy: .nextTime) ?? .now
        let w0 = Jour.chaine(samedi.addingTimeInterval(-86400)), w1 = Jour.chaine(samedi.addingTimeInterval(86400))
        var vus = Set<String>(), r: [Decouverte] = []
        func pousser(_ a: ActiviteCoin, _ b: String) { if !vus.contains(a.id) { vus.insert(a.id); r.append(Decouverte(a: a, badge: b)) } }
        l.filter { $0.debut <= w1 && $0.finReelle >= w0 }.prefix(4).forEach { pousser($0, "ce week-end") }
        if cal.component(.month, from: .now) >= 11 { l.filter(\.estNoel).prefix(4).forEach { pousser($0, "Noël") } }
        l.filter { $0.enfants == true }.prefix(3).forEach { pousser($0, "avec les petites") }
        l.prefix(8).forEach { pousser($0, "") }
        return Array(r.prefix(8))
    }

    private func carteVerte(titre: String, lignes: [Gros], plein: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(titre.uppercased()).font(.willys(.caption, poids: .heavy)).tracking(1.2).opacity(0.85)
            ForEach(lignes) { g in
                Button {
                    var c = URLComponents(string: "https://maps.apple.com/")!; c.queryItems = [URLQueryItem(name: "q", value: g.lieu + ", " + g.commune + ", Belgique")]
                    if let u = c.url { ouvrir(u) }
                } label: {
                    HStack(alignment: .center, spacing: 12) {
                        Image(systemName: g.icone).font(.title).frame(width: 54, height: 54)
                            .background(.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 16))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(g.titre).font(Theme.titre(plein ? 28 : 22)).multilineTextAlignment(.leading)
                            if !g.heure.isEmpty { Text(g.heure).font(.willys(.title3, poids: .bold)) }
                            Label(g.lieu + (g.voisine ? " · dans les environs" : ""), systemImage: "mappin.and.ellipse").font(.willys(.subheadline)).underline()
                        }
                        Spacer(minLength: 0)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityHint("Ouvre le lieu dans Plans")
            }
        }
        .foregroundStyle(plein ? Color.white : Color.primary)
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LinearGradient(colors: plein ? [Color(hex: 0x2C9A8A), Color(hex: 0x1F7A6C)] : [Color(hex: 0x2C9A8A).opacity(0.35), Color(hex: 0x2C9A8A).opacity(0.18)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 24))
    }

    private func vignette(badge: String, icone: String, titre: String, l1: String, l2: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if !badge.isEmpty { Etiquette(texte: badge, couleur: Color(hex: 0x2C9A8A)) }
            Image(systemName: icone).font(.title2).foregroundStyle(Theme.accent)
            Text(titre).font(.willys(.subheadline, poids: .bold)).lineLimit(3).multilineTextAlignment(.leading)
            if !l1.isEmpty { Text(l1).font(.willys(.caption)).foregroundStyle(.secondary) }
            if !l2.isEmpty { Text(l2).font(.willys(.caption)).foregroundStyle(.secondary).lineLimit(2) }
        }
        .padding(12)
        .frame(width: 200, alignment: .topLeading)
        .frame(minHeight: 150, alignment: .topLeading)
        .background(.background, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(.primary.opacity(0.08)))
    }

    private func quand(_ a: ActiviteCoin) -> String {
        a.finReelle > a.debut
            ? "\(Jour.joli(a.debut, .dateTime.day().month(.abbreviated))) → \(Jour.joli(a.finReelle, .dateTime.day().month(.abbreviated)))"
            : Jour.joli(a.debut, .dateTime.weekday(.abbreviated).day().month(.abbreviated))
    }
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

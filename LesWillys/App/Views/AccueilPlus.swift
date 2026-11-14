import SwiftUI
import SwiftData

// Trois cartes de l'accueil venues de l'app web :
// la météo du jour et la tenue des petites, « Ce soir à la maison ? » et les bonnes affaires voyage.

// MARK: - Météo

struct JourMeteo: Identifiable, Hashable {
    let date: String
    let tmin: Double, tmax: Double
    let code: Int
    let pluieProba: Double, pluieMm: Double, vent: Double
    var id: String { date }

    var icone: String {
        switch code {
        case 0: "☀️"
        case 1...2: "🌤️"
        case 3: "☁️"
        case 4...48: "🌫️"
        case 49...67, 80...82: "🌧️"
        case 68...77, 85...86: "❄️"
        default: "⛈️"
        }
    }
    /// En deux ou trois mots, comme la tâche du matin de l'app web.
    var resume: String {
        if code >= 95 { return "orages" }
        if (71...77).contains(code) || (85...86).contains(code) { return "neige" }
        if pluieMm >= 5 { return "pluie soutenue" }
        if pluieProba >= 50 { return "pluie" }
        if code <= 1 { return "ensoleillé" }
        if code <= 3 { return "nuageux" }
        return "couvert"
    }
    /// Comment habiller les petites (mêmes règles que l'app web).
    var tenue: (petites: String, extra: String) {
        var t: [String] = []
        t.append(tmax <= 5 ? "manteau chaud, bonnet et gants" : tmax <= 12 ? "manteau et écharpe" : tmax <= 18 ? "une veste" : tmax >= 25 ? "t-shirt, casquette et crème solaire" : "un gilet suffit")
        if pluieProba >= 50 || pluieMm >= 2 { t.append("bottes et K-way") }
        if vent >= 50 { t.append("capuche plutôt que parapluie") }
        return (t.joined(separator: ", "), tmin <= 0 ? "gel : gratter le pare-brise, rentrer les pots" : "")
    }
}

/// La prévision de Chaumont-Gistoux, lue directement chez Open-Meteo (gratuit, sans clé), gardée pour hors connexion.
@MainActor
final class Meteo: ObservableObject {
    static let partage = Meteo()
    static let adresse = URL(string: "https://api.open-meteo.com/v1/forecast?latitude=50.68&longitude=4.72&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max,precipitation_sum,wind_speed_10m_max&forecast_days=3&timezone=Europe%2FBrussels")!
    @Published var jours: [JourMeteo] = []
    private var dernier = Date.distantPast

    private struct Reponse: Decodable {
        struct Daily: Decodable {
            let time: [String]
            let weather_code: [Int?]
            let temperature_2m_max: [Double?], temperature_2m_min: [Double?]
            let precipitation_probability_max: [Double?], precipitation_sum: [Double?], wind_speed_10m_max: [Double?]
        }
        let daily: Daily
    }

    init() { if let d = Base.reglages.data(forKey: "meteo.cache") { jours = Self.lire(d) } }

    private static func lire(_ d: Data) -> [JourMeteo] {
        guard let r = try? JSONDecoder().decode(Reponse.self, from: d) else { return [] }
        let x = r.daily
        return x.time.indices.compactMap { i in
            guard i < x.temperature_2m_min.count, i < x.temperature_2m_max.count,
                  let mn = x.temperature_2m_min[i], let mx = x.temperature_2m_max[i] else { return nil }
            func v(_ l: [Double?]) -> Double { i < l.count ? (l[i] ?? 0) : 0 }
            return JourMeteo(date: x.time[i], tmin: mn, tmax: mx, code: i < x.weather_code.count ? (x.weather_code[i] ?? -1) : -1,
                             pluieProba: v(x.precipitation_probability_max), pluieMm: v(x.precipitation_sum), vent: v(x.wind_speed_10m_max))
        }
    }

    func rafraichir() async {
        guard Date.now.timeIntervalSince(dernier) > 1800 else { return }
        if let (d, _) = try? await URLSession.shared.data(from: Self.adresse) {
            let l = Self.lire(d)
            if !l.isEmpty { jours = l; Base.reglages.set(d, forKey: "meteo.cache"); dernier = .now }
        }
    }

    /// Le jour à montrer : aujourd'hui, ou demain après 18 h.
    var aMontrer: (jour: JourMeteo, demain: Bool)? {
        let t = Jour.aujourdhui
        if Calendar.current.component(.hour, from: .now) >= 18, let d = jours.first(where: { $0.date == Jour.plus(1) }) { return (d, true) }
        return jours.first { $0.date == t }.map { ($0, false) }
    }
}

/// La ligne météo, posée dans le bandeau bleu « Aujourd'hui ».
struct LigneMeteo: View {
    @ObservedObject private var meteo = Meteo.partage
    var body: some View {
        // un VStack et pas un Group : un Group vide ne lance jamais son .task
        VStack(alignment: .leading, spacing: 0) {
            if let m = meteo.aMontrer {
                let j = m.jour, demain = m.demain, te = j.tenue
                HStack(alignment: .top, spacing: 10) {
                    RoundedRectangle(cornerRadius: 2).fill(Color(hex: 0xFFD75E)).frame(width: 4)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(j.icone) \(demain ? "Demain : " : "")\(Int(j.tmin.rounded()))° → \(Int(j.tmax.rounded()))° · \(j.resume)")
                            .font(.willys(.headline))
                        Text("👧 Pour les petites : \(te.petites)\(te.extra.isEmpty ? "" : " · ❄️ " + te.extra)")
                            .font(.willys(.caption)).opacity(0.9)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityElement(children: .combine)
            }
        }
        .task { await meteo.rafraichir() }
    }
}

// MARK: - Ce soir à la maison ?

struct CarteSouper: View {
    let moi: String
    @Environment(\.modelContext) private var ctx
    @Query(sort: \Evenement.debut) private var evenements: [Evenement]
    @Query private var reponses: [ReponseSouper]

    var body: some View {
        let t = Jour.aujourdhui
        if let f = Famille.foyer(de: moi), Calendar.current.component(.hour, from: .now) < 21 {
            let mb = Souper.membres(foyer: f, evenements: evenements)
            let rep = Dictionary(reponses.filter { $0.date == t && mb.contains($0.membre) }.map { ($0.membre, $0.etat) }, uniquingKeysWith: { a, _ in a })
            let aTable = mb.filter { ["oui", "tard"].contains(rep[$0] ?? "") }
            let tard = mb.filter { rep[$0] == "tard" }
            let sans = mb.filter { (rep[$0] ?? "").isEmpty }
            Porte {
                HStack {
                    Text("🍽 Ce soir à la maison ?").font(Theme.titre(19))
                    Spacer()
                    Text(aTable.isEmpty ? "touchez votre aimant" : "\(aTable.count) à table").font(.willys(.caption, poids: .semibold)).foregroundStyle(.secondary)
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(mb, id: \.self) { k in
                            let e = rep[k] ?? ""
                            Button { basculer(k, foyer: f, actuel: e) } label: {
                                VStack(spacing: 4) {
                                    Aimant(membre: k, taille: 42)
                                        .opacity(e == "non" ? 0.4 : 1)
                                        .overlay(alignment: .bottomTrailing) {
                                            Text(Souper.signe(e)).font(.system(size: 13, weight: .heavy))
                                                .frame(width: 22, height: 22)
                                                .background(pastille(e), in: Circle())
                                                .foregroundStyle(e.isEmpty ? Color.primary : Color.white)
                                        }
                                    Text(Famille.membre(k)?.nom ?? k).font(.willys(.caption, poids: .semibold))
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(Famille.membre(k)?.nom ?? k) : \(Souper.libelle(e))")
                            .accessibilityHint("Touchez pour changer")
                        }
                    }
                    .padding(.vertical, 2)
                }
                Text(note(tard: tard, sans: sans, aTable: aTable))
                    .font(.willys(.caption)).foregroundStyle(.secondary)
            }
        }
    }

    private func note(tard: [String], sans: [String], aTable: [String]) -> String {
        func noms(_ l: [String]) -> String { l.compactMap { Famille.membre($0)?.nom }.joined(separator: ", ") }
        var l: [String] = []
        if !tard.isEmpty { l.append(noms(tard) + (tard.count > 1 ? " rentrent plus tard" : " rentre plus tard")) }
        if !sans.isEmpty && !aTable.isEmpty { l.append("pas encore répondu : " + noms(sans)) }
        return l.isEmpty ? "Touchez un aimant : à table, plus tard, pas ce soir." : l.joined(separator: " · ")
    }

    private func pastille(_ e: String) -> Color {
        switch e { case "oui": Theme.ok; case "non": .gray; case "tard": Theme.accent; default: Color(.systemBackground) }
    }

    private func basculer(_ k: String, foyer: String, actuel: String) {
        let t = Jour.aujourdhui
        let i = Souper.ordre.firstIndex(of: actuel) ?? 0
        let nv = Souper.ordre[(i + 1) % Souper.ordre.count]
        if let r = reponses.first(where: { $0.cle == t + "_" + k }) {
            if nv.isEmpty { ctx.delete(r) } else { r.etat = nv; r.par = moi; r.quand = .now }
        } else if !nv.isEmpty {
            ctx.insert(ReponseSouper(date: t, foyer: foyer, membre: k, etat: nv, par: moi))
        }
        ctx.enregistrer(); Retour.leger()
    }
}

// MARK: - Les bonnes affaires voyage

struct OffreVoyage: Codable, Identifiable, Hashable {
    var id: String
    var type: String?
    var titre: String
    var detail: String?
    var format: String?
    var depart: String
    var retour: String?
    var prix: Double?
    var personnes: Int?
    var prixPers: Double?
    var baisse: Double?
    var depuisDebut: Double?
    var plusBas: Bool?
    var etoiles: Int?
    var note: Double?
    var temp: Double?
    var pluie: Double?
    var lien: String?
    var photo: String?
    var depuis: String?
    var pourquoi: String?
    var releve: String?
    var score: Double?

    var nb: Int { personnes ?? 2 }
    var badge: (texte: String, couleur: Color) {
        if type == "pepite" { return ("pépite de la semaine", Theme.accent) }
        if (baisse ?? 0) >= 20 { return ("prix en baisse : −\(OffreVoyage.euros(baisse ?? 0))", Theme.ok) }
        if plusBas == true { return ("prix le plus bas suivi", Color(hex: 0x2C9A8A)) }
        if type == "neige" { return ("ski à \(nb)", Color(hex: 0x2F6FB5)) }
        return ("à suivre", .secondary)
    }
    var icone: String { type == "neige" ? "⛷️" : type == "pepite" ? "🌴" : "✈️" }
    var lienSur: URL? {
        if let l = lien, l.hasPrefix("https://"), let u = URL(string: l) { return u }
        var c = URLComponents(string: "https://www.booking.com/searchresults.fr.html")!
        c.queryItems = [URLQueryItem(name: "ss", value: [detail, titre].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")),
                        URLQueryItem(name: "checkin", value: depart), URLQueryItem(name: "checkout", value: retour ?? ""),
                        URLQueryItem(name: "group_adults", value: String(nb))]
        return c.url
    }
    var photoURL: URL? { photo.flatMap { $0.hasPrefix("https://") ? URL(string: $0) : nil } }
    static func euros(_ v: Double) -> String { v.formatted(.currency(code: "EUR").precision(.fractionLength(0)).locale(Locale(identifier: "fr_BE"))) }
}

struct DonneesVoyages: Codable { var maj: String?; var offres: [OffreVoyage] }

/// Les offres copiées chaque jour de « Veille voyages », publiées dans donnees/voyages.json du dépôt.
@MainActor
final class BonnesAffaires: ObservableObject {
    static let partage = BonnesAffaires()
    static let adresse = URL(string: "https://raw.githubusercontent.com/LucWil/home/claude/willys-application-t5ll8c/donnees/voyages.json")!
    @Published var donnees: DonneesVoyages?
    @Published var charge = false

    init() { if let d = Base.reglages.data(forKey: "voyages.cache") { donnees = try? JSONDecoder().decode(DonneesVoyages.self, from: d) } }

    func rafraichir() async {
        var r = URLRequest(url: Self.adresse); r.cachePolicy = .reloadIgnoringLocalCacheData
        if let (d, _) = try? await URLSession.shared.data(for: r), let v = try? JSONDecoder().decode(DonneesVoyages.self, from: d) {
            donnees = v; Base.reglages.set(d, forKey: "voyages.cache")
        }
        charge = true
    }

    var aVenir: [OffreVoyage] {
        (donnees?.offres ?? []).filter { $0.depart > Jour.aujourdhui }.sorted { ($0.score ?? 0) > ($1.score ?? 0) }.prefix(12).map { $0 }
    }
}

struct CarteBonnesAffaires: View {
    let moi: String
    @ObservedObject private var vv = BonnesAffaires.partage
    @State private var choisie: OffreVoyage?
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let l = vv.aVenir
        VStack(alignment: .leading, spacing: 8) {
            if !l.isEmpty {
                Text("✈️ Les bonnes affaires voyage").font(Theme.titre(20))
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 10) {
                        ForEach(l) { x in
                            Button { choisie = x } label: { vignette(x) }.buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }
                Text("Prix suivis au départ de Bruxelles\(vv.donnees?.maj.map { " · mis à jour le \(Jour.joli($0, .dateTime.day().month(.wide)))" } ?? ""). Touchez une offre pour la proposer à la famille.")
                    .font(.willys(.caption)).foregroundStyle(.secondary)
            }
        }
        .task { if !vv.charge { await vv.rafraichir() } }
        .sheet(item: $choisie) { x in NavigationStack { FicheOffreVoyage(offre: x, moi: moi) } }
    }

    private func vignette(_ x: OffreVoyage) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if let u = x.photoURL {
                AsyncImage(url: u) { $0.resizable().scaledToFill() } placeholder: { Color.secondary.opacity(0.15) }
                    .frame(width: 196, height: 96).clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                Text(x.icone).font(.system(size: 26))
            }
            let b = x.badge
            Text(b.texte.uppercased()).font(.willys(.caption2, poids: .heavy)).tracking(0.6)
                .padding(.horizontal, 8).padding(.vertical, 1)
                .background(b.couleur.opacity(0.18), in: Capsule()).foregroundStyle(b.couleur)
            Text(x.titre).font(.willys(.headline)).lineLimit(2)
            Text("\(Jour.joli(x.depart, .dateTime.day().month(.abbreviated))) → \(Jour.joli(x.retour ?? x.depart, .dateTime.day().month(.abbreviated)))\(x.format.map { " · " + $0 } ?? "")")
                .font(.willys(.caption)).foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(OffreVoyage.euros(x.prix ?? 0)).font(Theme.titre(20))
                Text("pour \(x.nb)").font(.willys(.caption)).foregroundStyle(.secondary)
            }
            Text([x.temp.map { "☀️ \(Int($0)) °C" }, x.note.map { "Booking \(String(format: "%.1f", $0).replacingOccurrences(of: ".", with: ","))" }].compactMap { $0 }.joined(separator: " · "))
                .font(.willys(.caption)).foregroundStyle(.secondary)
        }
        .frame(width: 196, alignment: .leading)
        .padding(12)
        .background(Theme.porte(scheme), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(.primary.opacity(0.07)))
    }
}

struct FicheOffreVoyage: View {
    let offre: OffreVoyage
    let moi: String
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var fermer
    @Environment(\.openURL) private var ouvrir
    @Query private var idees: [Idee]

    private var dejaProposee: Bool { idees.contains { $0.genre == "voyage" && $0.note.contains("[\(offre.id)]") } }

    var body: some View {
        let x = offre
        List {
            if let u = x.photoURL {
                AsyncImage(url: u) { $0.resizable().scaledToFill() } placeholder: { Color.secondary.opacity(0.15) }
                    .frame(height: 200).clipShape(RoundedRectangle(cornerRadius: 16)).listRowInsets(EdgeInsets())
            }
            Section {
                Text(x.titre).font(Theme.titre(26))
                if let d = x.detail, !d.isEmpty {
                    Text(d + (x.etoiles.map { " · " + String(repeating: "★", count: $0) } ?? "")).foregroundStyle(.secondary)
                }
                LabeledContent("Dates", value: "\(Jour.joli(x.depart, .dateTime.weekday(.abbreviated).day().month(.wide))) → \(Jour.joli(x.retour ?? x.depart, .dateTime.weekday(.abbreviated).day().month(.wide).year()))")
                LabeledContent("Prix \(x.type == "neige" ? "du logement" : "vol + hôtel") pour \(x.nb)", value: OffreVoyage.euros(x.prix ?? 0))
                if x.nb > 2, let p = x.prixPers { LabeledContent("Par personne", value: OffreVoyage.euros(p)) }
                if let b = x.baisse, b > 0 { LabeledContent("Depuis le relevé précédent") { Text("−" + OffreVoyage.euros(b)).foregroundStyle(Theme.ok) } }
                if let b = x.depuisDebut, b > 0 { LabeledContent("Depuis le début du suivi") { Text("−" + OffreVoyage.euros(b)).foregroundStyle(Theme.ok) } }
                if let t = x.temp { LabeledContent("Météo moyenne", value: "\(Int(t)) °C" + (x.pluie.map { " · pluie \(Int($0)) % des jours" } ?? "")) }
                if let n = x.note { LabeledContent("Note Booking", value: String(format: "%.1f", n).replacingOccurrences(of: ".", with: ",") + " / 10") }
                if let d = x.depuis, !d.isEmpty { LabeledContent("Départ", value: d) }
            } footer: {
                Text(x.badge.texte + (x.pourquoi.map { $0.isEmpty ? "" : " · " + $0 } ?? "") + ". Les prix bougent tous les jours : vérifiez avant de réserver.")
            }
            Section {
                Button { proposer() } label: {
                    Label(dejaProposee ? "Déjà proposé à la famille" : "Proposer à la famille", systemImage: "hand.raised.fill")
                }
                .disabled(dejaProposee)
                if let u = x.lienSur {
                    Button { ouvrir(u) } label: { Label(x.lien?.hasPrefix("https://") == true ? "Voir l'offre" : "Voir l'hôtel sur Booking", systemImage: "arrow.up.right.square") }
                }
            }
        }
        .navigationTitle("Bonne affaire")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Fermer") { fermer() } } }
    }

    /// Devient une idée de voyage : toute la famille la voit dans Idées et peut réagir.
    private func proposer() {
        let x = offre
        let i = Idee(genre: "voyage", titre: x.titre + (x.detail.map { $0.isEmpty ? "" : " · " + $0 } ?? ""), par: moi)
        i.quand = "\(Jour.joli(x.depart, .dateTime.day().month(.abbreviated))) → \(Jour.joli(x.retour ?? x.depart, .dateTime.day().month(.abbreviated).year()))"
        i.prix = OffreVoyage.euros(x.prix ?? 0) + " pour \(x.nb)"
        i.lien = x.lienSur?.absoluteString ?? ""
        i.photo = x.photoURL?.absoluteString ?? ""
        i.note = "Bonne affaire repérée par la veille voyages (\(x.badge.texte)). [\(x.id)]"
        ctx.insert(i)
        ctx.enregistrer(); Retour.succes(); fermer()
    }
}

// MARK: - Kit 72 heures : un rappel seulement quand quelque chose périme

struct RappelKit72: View {
    let moi: String
    @Query private var elements: [ElementKit]

    var body: some View {
        if let f = Famille.foyer(de: moi) {
            let l = Kit72.aRenouveler(elements, foyer: f)
            if !l.isEmpty {
                NavigationLink { Kit72View(moi: moi) } label: {
                    Porte(teinte: .orange) {
                        Label("Kit 72 heures : \(l.count) chose\(l.count > 1 ? "s" : "") à renouveler", systemImage: "cross.case.fill")
                            .font(.willys(.headline)).foregroundStyle(.orange)
                        Text(l.prefix(3).map { "\(Kit72.libelle($0.element)) (\($0.exp < Jour.aujourdhui ? "périmé" : "avant le " + Jour.joli($0.exp, .dateTime.day().month(.abbreviated))))" }.joined(separator: " · "))
                            .font(.willys(.caption)).foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}

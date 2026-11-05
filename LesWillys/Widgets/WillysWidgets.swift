import WidgetKit
import SwiftUI
import SwiftData
import AppIntents

// Les cinq widgets du dossier de portage. Ils lisent la base locale partagée avec l'app (App Group) :
// pas de réseau, et ils se rafraîchissent dès que l'app enregistre un changement.

@main
struct WillysWidgets: WidgetBundle {
    var body: some Widget {
        AMangerWidget()
        PetitsMotsWidget()
        QuiEstOuWidget()
        CetteSemaineWidget()
        BoniWidget()
    }
}

// MARK: - Les données lues par les widgets

struct Instantane: TimelineEntry {
    let date: Date
    var moi: String?
    var aManger: [ArticleW] = []
    var mot: MotW?
    var semaine: [EvenementW] = []
    var prochainVoyage: String?
    var foyers: [FoyerW] = []
    var boniTrimestre: Double = 0
    var boniTotal: Double = 0
    var objectif: Double = 0

    static let exemple: Instantane = {
        var i = Instantane(date: .now, moi: "loulou")
        i.aManger = [ArticleW(cle: "1", nom: "Haché porc et bœuf", categorie: "viandes", jours: 0),
                     ArticleW(cle: "2", nom: "Chicons", categorie: "legumes", jours: 1),
                     ArticleW(cle: "3", nom: "Yaourts", categorie: "cremerie", jours: 2)]
        i.mot = MotW(texte: "Qui vient dimanche ?", auteur: "loulou")
        i.semaine = [EvenementW(debut: Jour.aujourdhui, titre: "Amalia chez Grany", type: "garde", personnes: ["amalia"]),
                     EvenementW(debut: Jour.plus(2), titre: "Barbecue au ponton", type: "weekend", personnes: ["chouchou", "loulou"])]
        i.prochainVoyage = "Crète — vacances de Pâques"
        i.foyers = Famille.foyers.map { FoyerW(nom: $0.nom, membres: $0.membres, lieu: "be") }
        i.boniTrimestre = 86.4; i.boniTotal = 312.5; i.objectif = 900
        return i
    }()
}

struct ArticleW: Hashable { let cle: String, nom: String, categorie: String; let jours: Int }
struct MotW: Hashable { let texte: String, auteur: String }
struct EvenementW: Hashable { let debut: String, titre: String, type: String; let personnes: [String] }
struct FoyerW: Hashable { let nom: String; let membres: [String]; let lieu: String }

struct Fournisseur: TimelineProvider {
    func placeholder(in context: Context) -> Instantane { .exemple }
    func getSnapshot(in context: Context, completion: @escaping (Instantane) -> Void) {
        if context.isPreview { completion(.exemple); return }
        Task { @MainActor in completion(lire()) }
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<Instantane>) -> Void) {
        // Recalcul à minuit au plus tard (les « encore 2 jours » changent chaque jour).
        let minuit = Calendar.current.startOfDay(for: .now.addingTimeInterval(86400))
        Task { @MainActor in completion(Timeline(entries: [lire()], policy: .after(minuit))) }
    }

    @MainActor private func lire() -> Instantane {
        let ctx = ModelContext(Base.conteneur())
        let moi = Base.moi
        let foyer = Famille.foyer(de: moi) ?? ""
        var i = Instantane(date: .now, moi: moi)

        i.aManger = Cuisine.aManger(foyer: foyer, dans: ctx).map { ArticleW(cle: $0.cle, nom: $0.nom, categorie: $0.categorie, jours: $0.joursRestants ?? 0) }

        var mots = FetchDescriptor<Idee>(predicate: #Predicate { $0.genre == "mot" }, sortBy: [SortDescriptor(\.cree, order: .reverse)])
        mots.fetchLimit = 1
        if let m = try? ctx.fetch(mots).first { i.mot = MotW(texte: m.titre, auteur: m.par) }

        let auj = Jour.aujourdhui, dans7 = Jour.plus(7)
        let evs = (try? ctx.fetch(FetchDescriptor<Evenement>(sortBy: [SortDescriptor(\.debut)]))) ?? []
        i.semaine = evs.filter { $0.fin >= auj && $0.debut <= dans7 }.map { EvenementW(debut: $0.debut, titre: $0.titre, type: $0.type, personnes: $0.personnes) }
        if let v = evs.first(where: { $0.type == "voyage" && $0.debut >= auj }) {
            i.prochainVoyage = "\(v.titre) — \(Jour.joli(v.debut, .dateTime.day().month(.wide)))"
        }

        // Qui est où ce week-end : Fréjus si un événement Fréjus couvre samedi avec un membre du foyer,
        // sinon Luxembourg pour Ambre, Belgique pour les autres (réglable plus tard).
        let samedi = Jour.chaine(Calendar.current.nextDate(after: .now.addingTimeInterval(-86400),
                                                            matching: DateComponents(weekday: 7), matchingPolicy: .nextTime) ?? .now)
        i.foyers = Famille.foyers.map { f in
            let aFrejus = evs.contains { $0.type == "frejus" && $0.debut <= samedi && $0.fin >= samedi
                && ($0.personnes.contains { f.membres.contains($0) } || $0.titre.localizedCaseInsensitiveContains(f.nom)) }
            return FoyerW(nom: f.nom, membres: f.membres, lieu: aFrejus ? "fj" : LieuHabituel.de(f.id))
        }

        let bonis = (try? ctx.fetch(FetchDescriptor<Boni>(predicate: #Predicate { $0.foyer == foyer }))) ?? []
        let c = Calendar.current
        let debutTrim = c.date(from: DateComponents(year: c.component(.year, from: .now),
                                                    month: ((c.component(.month, from: .now) - 1) / 3) * 3 + 1, day: 1)) ?? .now
        i.boniTotal = bonis.reduce(0) { $0 + $1.valeur }
        i.boniTrimestre = bonis.filter { $0.cree >= debutTrim }.reduce(0) { $0 + $1.valeur }
        i.objectif = ((try? ctx.fetch(FetchDescriptor<Foyer>(predicate: #Predicate { $0.cle == foyer })))?.first?.objectifMontant) ?? 0
        return i
    }

}

/// Où vit chaque foyer d'habitude (pastille du widget « Qui est où »). À ajuster si besoin.
enum LieuHabituel {
    static func de(_ foyer: String) -> String { Base.reglages.string(forKey: "lieu.\(foyer)") ?? "be" }
}

// MARK: - Habillage commun

struct FondFrigo: View {
    @Environment(\.colorScheme) private var scheme
    var body: some View { Theme.porte(scheme) }
}

struct Pastille: View {
    let lieu: String
    var body: some View {
        let (t, c): (String, Color) = switch lieu {
        case "fj": ("Fréjus", Color(hex: 0x2A7FA8))
        case "lu": ("Luxembourg", Color(hex: 0x93A3AD))
        default: ("Belgique", Color(hex: 0xC0392B))
        }
        Text(t).font(.willys(.caption2, poids: .bold)).padding(.horizontal, 7).padding(.vertical, 2)
            .background(c.opacity(lieu == "fj" ? 1 : 0.2), in: Capsule())
            .foregroundStyle(lieu == "fj" ? .white : .primary)
    }
}

// MARK: - 1. À manger cette semaine (moyen, interactif)

struct AMangerWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "aManger", provider: Fournisseur()) { e in
            VStack(alignment: .leading, spacing: 6) {
                HStack { Text("À manger cette semaine").font(.willys(.headline)); Spacer(); Image(systemName: "refrigerator") }
                if e.aManger.isEmpty {
                    Spacer(); Text("Rien qui presse. Bravo !").foregroundStyle(.secondary); Spacer()
                }
                ForEach(e.aManger.prefix(4), id: \.self) { a in
                    HStack(spacing: 8) {
                        Circle().fill(Categorie.couleur(a.categorie)).frame(width: 9, height: 9)
                        Text(a.nom).font(.willys(.subheadline, poids: .bold)).lineLimit(1)
                        Spacer()
                        Text(a.jours < 0 ? "dépassé" : a.jours == 0 ? "auj." : "\(a.jours) j")
                            .font(.willys(.caption)).foregroundStyle(a.jours <= 0 ? Theme.alerte : .secondary)
                        Button(intent: MangerIntent(cle: a.cle)) { Text("Mangé").font(.willys(.caption, poids: .bold)) }
                            .tint(Theme.ok)
                    }
                }
            }
            .containerBackground(for: .widget) { FondFrigo() }
            .widgetURL(URL(string: "willys://cuisine"))
        }
        .configurationDisplayName("À manger cette semaine")
        .description("Les produits du stock qui arrivent à date. « Mangé » les retire et grossit le boni.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

// MARK: - 2. Les petits mots (petit)

struct PetitsMotsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "petitsMots", provider: Fournisseur()) { e in
            ZStack(alignment: .topLeading) {
                if let mot = e.mot {
                    VStack(alignment: .leading, spacing: 6) {
                        Aimant(membre: mot.auteur, taille: 26)
                        Text(mot.texte).font(Theme.main(19)).foregroundStyle(Theme.encrePostit).minimumScaleFactor(0.6)
                        Spacer(minLength: 0)
                        Text(Famille.membre(mot.auteur)?.nom ?? "").font(.willys(.caption2)).foregroundStyle(Theme.encrePostit.opacity(0.7))
                    }
                } else {
                    Text("Pas encore de petit mot.").font(Theme.main(18)).foregroundStyle(Theme.encrePostit)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .containerBackground(for: .widget) { Theme.postit }
            .widgetURL(URL(string: "willys://accueil"))
        }
        .configurationDisplayName("Les petits mots")
        .description("Le dernier mot laissé à la famille.")
        .supportedFamilies([.systemSmall])
    }
}

// MARK: - 3. Qui est où ce week-end (moyen)

struct QuiEstOuWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "quiEstOu", provider: Fournisseur()) { e in
            VStack(alignment: .leading, spacing: 6) {
                Text("Qui est où ce week-end").font(.willys(.headline))
                ForEach(e.foyers, id: \.self) { f in
                    HStack {
                        PileAimants(membres: f.membres, taille: 20)
                        Text(f.nom).font(.willys(.subheadline)).lineLimit(1)
                        Spacer()
                        Pastille(lieu: f.lieu)
                    }
                }
            }
            .containerBackground(for: .widget) { FondFrigo() }
            .widgetURL(URL(string: "willys://calendrier"))
        }
        .configurationDisplayName("Qui est où")
        .description("Chaque foyer, en Belgique, à Luxembourg ou à Fréjus ce week-end.")
        .supportedFamilies([.systemMedium])
    }
}

// MARK: - 4. Cette semaine (grand)

struct CetteSemaineWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "cetteSemaine", provider: Fournisseur()) { e in
            VStack(alignment: .leading, spacing: 8) {
                Text("Cette semaine").font(Theme.titre(20))
                if e.semaine.isEmpty { Text("Rien de prévu ces 7 prochains jours.").foregroundStyle(.secondary) }
                ForEach(Array(e.semaine.prefix(5).enumerated()), id: \.offset) { _, ev in
                    Link(destination: URL(string: "willys://calendrier")!) {
                        HStack(spacing: 10) {
                            VStack(spacing: 0) {
                                Text(Jour.date(ev.debut).formatted(.dateTime.day())).font(.willys(.headline))
                                Text(Jour.joli(ev.debut, .dateTime.weekday(.abbreviated))).font(.willys(.caption2)).textCase(.uppercase)
                            }
                            .frame(width: 40).padding(.vertical, 3)
                            .background((TypeEvenement(rawValue: ev.type)?.couleur ?? .gray).opacity(0.2), in: RoundedRectangle(cornerRadius: 8))
                            Text(ev.titre).font(.willys(.subheadline, poids: .bold)).lineLimit(1)
                            Spacer()
                            PileAimants(membres: ev.personnes, taille: 18)
                        }
                    }
                }
                Spacer(minLength: 0)
                if let v = e.prochainVoyage { Label(v, systemImage: "airplane").font(.willys(.footnote)).lineLimit(1) }
                if let m = e.mot {
                    HStack { Aimant(membre: m.auteur, taille: 18); Text(m.texte).font(Theme.main(16)).lineLimit(1) }
                }
            }
            .containerBackground(for: .widget) { FondFrigo() }
            .widgetURL(URL(string: "willys://accueil"))
        }
        .configurationDisplayName("Cette semaine")
        .description("Les dates des 7 prochains jours, le prochain voyage et le dernier mot.")
        .supportedFamilies([.systemLarge])
    }
}

// MARK: - 5. Le boni du foyer (écran verrouillé)

struct BoniWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "boni", provider: Fournisseur()) { e in
            Group {
                if e.objectif > 0 {
                    Gauge(value: min(e.boniTotal, e.objectif), in: 0...e.objectif) {
                        Image(systemName: "eurosign")
                    } currentValueLabel: {
                        Text("\(Int(e.boniTrimestre))")
                    }
                    .gaugeStyle(.accessoryCircular)
                } else {
                    VStack(alignment: .leading) {
                        Text("Boni du trimestre").font(.willys(.caption2))
                        Text(e.boniTrimestre.euros).font(.willys(.headline))
                    }
                }
            }
            .containerBackground(for: .widget) { Color.clear }
            .widgetURL(URL(string: "willys://boni"))
        }
        .configurationDisplayName("Le boni du foyer")
        .description("Ce que le foyer a gagné ce trimestre, et la progression vers l'objectif.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular])
    }
}

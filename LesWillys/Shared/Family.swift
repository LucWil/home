import SwiftUI

/// La famille, telle qu'elle est sur la porte du frigo : un aimant de couleur par personne.
struct Membre: Identifiable, Hashable {
    let id: String      // clé utilisée dans les données ("chouchou", "loulou"…)
    let nom: String
    let couleur: Color
    var enfant = false

    var initiale: String { String(nom.prefix(1)) }
}

enum Famille {
    static let membres: [Membre] = [
        Membre(id: "chouchou",  nom: "Chouchou",  couleur: Color(hex: 0x2F6FB5)),
        Membre(id: "loulou",    nom: "Loulou",    couleur: Color(hex: 0x8A5CC2)),
        Membre(id: "manhattan", nom: "Manhattan", couleur: Color(hex: 0xC8456B)),
        Membre(id: "julien",    nom: "Julien",    couleur: Color(hex: 0x2C9A8A)),
        Membre(id: "ambre",     nom: "Ambre",     couleur: Color(hex: 0xD98A1F)),
        Membre(id: "robin",     nom: "Robin",     couleur: Color(hex: 0x5F8A2E)),
        Membre(id: "leonor",    nom: "Léonor",    couleur: Color(hex: 0xE07AA0), enfant: true),
        Membre(id: "amalia",    nom: "Amalia",    couleur: Color(hex: 0xE5B437), enfant: true),
    ]
    static let adultes = membres.filter { !$0.enfant }
    static let enfants = membres.filter { $0.enfant }
    static func membre(_ id: String?) -> Membre? { membres.first { $0.id == id } }

    /// Les quatre foyers ; chaque foyer a son stock, ses tickets et son boni.
    static let foyers: [(id: String, nom: String, membres: [String])] = [
        ("luc",   "Luc et Loulou",       ["chouchou", "loulou"]),
        ("mj",    "Manhattan et Julien", ["manhattan", "julien"]),
        ("ambre", "Ambre",               ["ambre"]),
        ("robin", "Robin",               ["robin"]),
    ]
    static func foyer(de membre: String?) -> String? {
        foyers.first { $0.membres.contains(membre ?? "") }?.id
    }
    static func nomFoyer(_ id: String?) -> String { foyers.first { $0.id == id }?.nom ?? "" }
}

/// Types de dates du calendrier, avec la même étiquette que l'app web.
enum TypeEvenement: String, CaseIterable, Identifiable {
    case garde, weekend, voyage, ensemble, frejus
    var id: String { rawValue }
    var libelle: String {
        switch self {
        case .garde: "Garde"
        case .weekend: "Week-end"
        case .voyage: "Voyage"
        case .ensemble: "Moment ensemble"
        case .frejus: "Maison de Fréjus"
        }
    }
    var couleur: Color {
        switch self {
        case .garde: Color(hex: 0xE07AA0)
        case .weekend: Color(hex: 0x5F8A2E)
        case .voyage: Color(hex: 0x2F6FB5)
        case .ensemble: Color(hex: 0xE2973A)
        case .frejus: Color(hex: 0x2A7FA8)
        }
    }
}

/// Lieux de rangement et catégories du stock.
enum Rangement: String, CaseIterable, Identifiable {
    case frais, surgelateur, armoire
    var id: String { rawValue }
    var libelle: String {
        switch self {
        case .frais: "Le frais"
        case .surgelateur: "Surgélateur"
        case .armoire: "Armoires"
        }
    }
}

enum Categorie {
    /// Nombre de jours pendant lesquels un produit frais reste bon, par catégorie.
    static let joursFrais: [String: Int] = [
        "legumes": 5, "fruits": 7, "viandes": 2, "poissons": 1,
        "cremerie": 7, "pains": 3, "autre": 4,
    ]
    static let toutes: [(id: String, nom: String)] = [
        ("legumes", "Légumes"), ("fruits", "Fruits"), ("viandes", "Viandes"),
        ("poissons", "Poissons"), ("cremerie", "Crèmerie"), ("pains", "Pains et pâtes"),
        ("plats", "Plats préparés"), ("epices", "Épices"),
        ("conserves", "Conserves"), ("epicerie", "Épicerie sèche"), ("petitdej", "Petit-déjeuner"),
        ("boissons", "Boissons"), ("autre", "Autre"),
    ]
    /// Les catégories qu'on s'attend à trouver à chaque endroit, dans l'ordre où on les cherche :
    /// ce qui n'a aucun article apparaît comme « il n'y en a pas », pour voir d'un coup d'œil ce qui manque.
    static func attendues(dans rangement: String) -> [String] {
        switch rangement {
        case "armoire": ["pains", "epicerie", "conserves", "petitdej", "epices", "boissons", "plats", "autre"]
        case "frais": ["legumes", "fruits", "cremerie", "viandes", "poissons", "pains", "plats", "autre"]
        default: toutes.map(\.id)
        }
    }
    static func nom(_ id: String) -> String { toutes.first { $0.id == id }?.nom ?? "Autre" }
    static func couleur(_ id: String) -> Color {
        switch id {
        case "viandes": Color(hex: 0xC8456B)
        case "poissons": Color(hex: 0x2F6FB5)
        case "plats": Color(hex: 0xE2973A)
        case "legumes": Color(hex: 0x5F8A2E)
        case "pains": Color(hex: 0xD98A1F)
        case "fruits": Color(hex: 0xE07AA0)
        case "conserves": Color(hex: 0x8A5CC2)
        case "epicerie": Color(hex: 0xB8742A)
        case "petitdej": Color(hex: 0xC99A1B)
        case "boissons": Color(hex: 0x2A7FA8)
        case "epices": Color(hex: 0xC0582F)
        case "cremerie": Color(hex: 0x2C9A8A)
        default: Color(hex: 0x5D6B78)
        }
    }
}

/// Fruits et légumes de saison en Belgique, mois par mois (0 = janvier).
enum Saison {
    static let parMois: [[String]] = [
        ["chou", "poireau", "chicon", "céleri-rave", "panais", "pomme", "poire", "orange"],
        ["chicon", "poireau", "chou rouge", "topinambour", "pomme", "poire", "pamplemousse"],
        ["poireau", "épinard", "radis", "chicon", "rhubarbe (fin du mois)", "pomme"],
        ["asperge", "radis", "épinard", "rhubarbe", "ail des ours", "laitue"],
        ["asperge", "fraise", "petits pois", "rhubarbe", "laitue", "radis"],
        ["fraise", "cerise", "courgette", "petits pois", "fèves", "haricot"],
        ["tomate", "courgette", "haricot", "framboise", "cerise", "concombre"],
        ["tomate", "aubergine", "poivron", "prune", "mûre", "maïs"],
        ["tomate", "courge", "pomme", "poire", "raisin", "champignons"],
        ["courge", "potiron", "chou de Bruxelles", "champignons", "pomme", "poire", "coing"],
        ["chou de Bruxelles", "chicon", "poireau", "courge", "panais", "pomme", "poire"],
        ["chou", "chicon", "céleri-rave", "mâche", "clémentine", "pomme", "poire"],
    ]
    static var duMois: [String] { parMois[Calendar.current.component(.month, from: .now) - 1] }
}

/// Vacances scolaires belges et luxembourgeoises : qui est en congé, où.
enum VacancesScolaires {
    typealias Periode = (debut: String, fin: String, nom: String)
    static let belgique: [Periode] = [
        ("2025-12-20", "2026-01-03", "Vacances d'hiver"), ("2026-02-14", "2026-03-01", "Congé de détente"),
        ("2026-04-25", "2026-05-10", "Vacances de printemps"), ("2026-07-04", "2026-08-23", "Vacances d'été"),
        ("2026-10-17", "2026-11-01", "Congé d'automne"), ("2026-12-19", "2027-01-03", "Vacances d'hiver"),
        ("2027-02-20", "2027-03-07", "Congé de détente"), ("2027-04-24", "2027-05-09", "Vacances de printemps"),
        ("2027-07-03", "2027-08-29", "Vacances d'été"), ("2027-10-23", "2027-11-07", "Congé d'automne"),
        ("2027-12-25", "2028-01-09", "Vacances d'hiver"),
    ]
    static let luxembourg: [Periode] = [
        ("2025-12-20", "2026-01-04", "Vacances de Noël"), ("2026-02-14", "2026-02-22", "Vacances de Carnaval"),
        ("2026-03-28", "2026-04-12", "Vacances de Pâques"), ("2026-05-23", "2026-05-31", "Vacances de Pentecôte"),
        ("2026-07-16", "2026-09-14", "Vacances d'été"), ("2026-10-31", "2026-11-08", "Vacances de la Toussaint"),
        ("2026-12-19", "2027-01-03", "Vacances de Noël"), ("2027-02-06", "2027-02-14", "Vacances de Carnaval"),
        ("2027-03-27", "2027-04-11", "Vacances de Pâques"), ("2027-05-29", "2027-06-06", "Vacances de Pentecôte"),
        ("2027-07-16", "2027-09-14", "Vacances d'été"), ("2027-10-30", "2027-11-07", "Vacances de la Toussaint"),
        ("2027-12-18", "2028-01-02", "Vacances de Noël"),
    ]
    static func le(_ jour: String) -> (be: String?, lu: String?) {
        (belgique.first { jour >= $0.debut && jour <= $0.fin }?.nom,
         luxembourg.first { jour >= $0.debut && jour <= $0.fin }?.nom)
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}

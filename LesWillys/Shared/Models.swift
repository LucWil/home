import Foundation
import SwiftData

// Les modèles SwiftData de l'app. Règles pour que la synchronisation iCloud (CloudKit) fonctionne :
// chaque propriété a une valeur par défaut, pas de contrainte d'unicité, pas de relation obligatoire.
// Les dates « jour » restent des chaînes "aaaa-mm-jj", comme dans l'app web, pour que l'import soit fidèle.
// `cle` garde l'identifiant d'origine du document de l'app web (utile pour réimporter sans doublon).

@Model final class Evenement {
    var cle: String = UUID().uuidString
    var type: String = "ensemble"
    var titre: String = ""
    var debut: String = Jour.aujourdhui
    var fin: String = Jour.aujourdhui
    var personnes: [String] = []
    var gardeChez: String? = nil
    var par: String = ""
    var cree: Date = Date.now

    init(type: String, titre: String, debut: String, fin: String, personnes: [String], gardeChez: String? = nil, par: String) {
        self.type = type; self.titre = titre; self.debut = debut; self.fin = max(fin, debut)
        self.personnes = personnes; self.gardeChez = gardeChez; self.par = par
    }
    var typeEvenement: TypeEvenement { TypeEvenement(rawValue: type) ?? .ensemble }
}

/// Voyages, week-ends et petits mots partagent la même forme (collection « ideas » de l'app web).
@Model final class Idee {
    var cle: String = UUID().uuidString
    var genre: String = "mot"           // "voyage", "weekend" ou "mot"
    var titre: String = ""
    var quand: String = ""
    var prix: String = ""
    var lien: String = ""
    var photo: String = ""
    var note: String = ""
    var par: String = ""
    var cree: Date = Date.now

    init(genre: String, titre: String, par: String) { self.genre = genre; self.titre = titre; self.par = par }
}

/// La réaction d'un membre à une idée ou à une photo : "adore", "partant", "bof", "coeur", "rire", "waouh".
@Model final class Reaction {
    var cle: String = UUID().uuidString   // "<élément>__<membre>", comme dans l'app web
    var element: String = ""
    var membre: String = ""
    var reaction: String = ""
    var cree: Date = Date.now

    init(element: String, membre: String, reaction: String) {
        self.cle = element + "__" + membre; self.element = element; self.membre = membre; self.reaction = reaction
    }
}

/// Un article rangé au frais, au surgélateur ou dans les armoires d'un foyer.
@Model final class Article {
    var cle: String = UUID().uuidString
    var foyer: String = ""
    var rangement: String = "frais"
    var nom: String = ""
    var quantite: String = ""
    var categorie: String = "autre"
    var depuis: String = Jour.aujourdhui    // acheté ou congelé le
    var bonJours: Int? = nil                // au frais : bon pendant… (sinon selon la catégorie)
    var peremption: String? = nil           // armoires : à consommer avant le
    var prix: Double = 0
    var tiroir: Int? = nil
    var par: String = ""
    var cree: Date = Date.now

    init(foyer: String, rangement: Rangement, nom: String, categorie: String, par: String) {
        self.foyer = foyer; self.rangement = rangement.rawValue; self.nom = nom; self.categorie = categorie; self.par = par
    }

    /// Jours restants avant d'être à manger (nil = pas de limite connue).
    var joursRestants: Int? {
        switch rangement {
        case "frais":
            let limite = bonJours.map { max(0, $0) } ?? Categorie.joursFrais[categorie] ?? 4
            return limite - Jour.joursDepuis(depuis)
        case "armoire":
            return peremption.map { Jour.joursJusqua($0) }
        default:
            return nil
        }
    }
}

/// Un article mangé au lieu d'être racheté : son prix grossit le boni du foyer.
@Model final class Boni {
    var cle: String = UUID().uuidString
    var foyer: String = ""
    var nom: String = ""
    var valeur: Double = 0
    var par: String = ""
    var cree: Date = Date.now

    init(foyer: String, nom: String, valeur: Double, par: String) {
        self.foyer = foyer; self.nom = nom; self.valeur = valeur; self.par = par
    }
}

@Model final class Foyer {
    var cle: String = ""                 // "luc", "mj", "ambre", "robin"
    var nom: String = ""
    var objectifLibelle: String = ""
    var objectifMontant: Double = 0

    init(cle: String, nom: String) { self.cle = cle; self.nom = nom }
}

@Model final class Recette {
    var cle: String = UUID().uuidString
    var titre: String = ""
    var intro: String = ""
    var personnes: Int = 4
    var cout: Int = 1
    var extra: Bool = false
    var photo: String = ""
    var ingredients: [String] = []
    var etapesJSON: Data? = nil          // [EtapeThermomix] encodées
    var envie: Bool = false
    var par: String = ""
    var cree: Date = Date.now

    init(titre: String, par: String) { self.titre = titre; self.par = par }

    var etapes: [EtapeThermomix] {
        get { etapesJSON.flatMap { try? JSONDecoder().decode([EtapeThermomix].self, from: $0) } ?? [] }
        set { etapesJSON = try? JSONEncoder().encode(newValue) }
    }
}

struct EtapeThermomix: Codable, Hashable {
    var text: String
    var time: String = ""
    var temp: String = ""
    var speed: String = ""
    var reverse: Bool = false
}

@Model final class Photo {
    var cle: String = UUID().uuidString
    var url: String = ""
    @Attribute(.externalStorage) var image: Data? = nil
    var legende: String = ""
    var qui: [String] = []
    var par: String = ""
    var cree: Date = Date.now

    init(legende: String, qui: [String], par: String) { self.legende = legende; self.qui = qui; self.par = par }
}

/// Visite : qui est passé dans l'app, et quand.
@Model final class Visite {
    var cle: String = ""                 // = le membre : une seule visite gardée par personne
    var membre: String = ""
    var quand: Date = Date.now
    var ecran: String = "accueil"        // l'onglet ouvert : « Manhattan regarde le calendrier »
    init(membre: String) { self.cle = membre; self.membre = membre }
}

/// Toutes les autres collections de l'app web (jardin, récoltes, restos, entretien, papiers…)
/// sont gardées telles quelles : rien n'est perdu à l'import, et chaque écran peut les relire.
@Model final class DocumentBrut {
    var collection: String = ""
    var cle: String = ""
    var json: Data = Data()
    var foyer: String = ""
    var cree: Date = Date.now

    init(collection: String, cle: String, json: Data, foyer: String) {
        self.collection = collection; self.cle = cle; self.json = json; self.foyer = foyer
    }
    var valeurs: [String: Any] { (try? JSONSerialization.jsonObject(with: json)) as? [String: Any] ?? [:] }
}

/// Tous les modèles natifs gardent l'identifiant d'origine dans `cle`.
protocol AvecCle: AnyObject { var cle: String { get } }
extension Evenement: AvecCle {}
extension Idee: AvecCle {}
extension Reaction: AvecCle {}
extension Article: AvecCle {}
extension Boni: AvecCle {}
extension Foyer: AvecCle {}
extension Recette: AvecCle {}
extension Photo: AvecCle {}
extension Visite: AvecCle {}
extension DocumentBrut: AvecCle {}

enum Schema_ {
    static let modeles: [any PersistentModel.Type] = [
        Evenement.self, Idee.self, Reaction.self, Article.self, Boni.self, Foyer.self,
        Recette.self, Photo.self, Visite.self, DocumentBrut.self, Activite.self,
    ]
}

/// Petits outils de dates « aaaa-mm-jj », dans le fuseau de l'appareil.
enum Jour {
    static let format: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
    static var aujourdhui: String { format.string(from: .now) }
    static func chaine(_ d: Date) -> String { format.string(from: d) }
    static func date(_ s: String) -> Date { format.date(from: s).map { $0.addingTimeInterval(12 * 3600) } ?? .now }
    static func plus(_ jours: Int, _ depuis: Date = .now) -> String {
        chaine(Calendar.current.date(byAdding: .day, value: jours, to: depuis) ?? depuis)
    }
    static func joursJusqua(_ s: String) -> Int {
        Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: .now),
                                        to: Calendar.current.startOfDay(for: date(s))).day ?? 0
    }
    static func joursDepuis(_ s: String) -> Int { -joursJusqua(s) }

    static func joli(_ s: String, _ style: Date.FormatStyle = .dateTime.weekday(.wide).day().month(.wide)) -> String {
        date(s).formatted(style.locale(Locale(identifier: "fr_BE")))
    }
}

extension Double {
    var euros: String {
        formatted(.currency(code: "EUR").locale(Locale(identifier: "fr_BE")))
    }
}

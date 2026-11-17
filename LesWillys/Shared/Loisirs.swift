import Foundation
import SwiftData
import CloudKit

// L'onglet Loisirs : les restaurants (fiche, menu, avis clients, sorties), les hôtels (réservation,
// options, annulation, note finale) et le budget des sorties. Mêmes champs que l'app web
// (collections « restos », « sorties » et « hotels »), pour que l'import d'une sauvegarde soit fidèle.

struct PlatMenu: Codable, Hashable { var nom: String; var prix: String = ""; var note: String = "" }
struct AvisMembre: Codable, Hashable { var stars: Int = 0; var mot: String = "" }

private func decoder<T: Decodable>(_ d: Data?, _ t: T.Type) -> T? { d.flatMap { try? JSONDecoder().decode(T.self, from: $0) } }
private func encoder<T: Encodable>(_ v: T) -> Data? { try? JSONEncoder().encode(v) }

/// Un restaurant noté par la famille. La fiche (adresse, menu, avis clients) est complétée
/// chaque soir par Claude, ou à la main.
@Model final class Restaurant {
    var cle: String = UUID().uuidString
    var nom: String = ""
    var ville: String = ""
    var adresse: String = ""
    var tel: String = ""
    var cuisine: String = ""
    var horaires: String = ""
    var site: String = ""
    var reserver: String = ""
    var menuLien: String = ""
    var menuJSON: Data? = nil
    var menuNote: String = ""
    var avisNote: Double = 0
    var avisNb: String = ""
    var avisSource: String = ""
    var avisResume: String = ""
    var infosStatut: String = "a_chercher"
    var infosMaj: String = ""
    var par: String = ""
    var cree: Date = Date.now

    init(nom: String, ville: String, par: String) { self.nom = nom; self.ville = ville; self.par = par }

    var menu: [PlatMenu] {
        get { decoder(menuJSON, [PlatMenu].self) ?? [] }
        set { menuJSON = encoder(newValue) }
    }
}

/// « On y est allés » : une sortie au restaurant, avec l'addition, qui était là et l'impression de chacun.
@Model final class Sortie {
    var cle: String = UUID().uuidString
    var type: String = "resto"
    var ref: String = ""            // la clé du restaurant
    var nom: String = ""
    var lieu: String = ""
    var foyer: String = ""
    var date: String = Jour.aujourdhui
    var montant: Double = 0
    var personnes: Int = 2
    var qui: [String] = []
    var avisJSON: Data? = nil
    var par: String = ""
    var cree: Date = Date.now

    init(ref: String, nom: String, lieu: String, foyer: String, par: String) {
        self.ref = ref; self.nom = nom; self.lieu = lieu; self.foyer = foyer; self.par = par
    }
    var avis: [String: AvisMembre] {
        get { decoder(avisJSON, [String: AvisMembre].self) ?? [:] }
        set { avisJSON = encoder(newValue) }
    }
}

/// Un hôtel : la réservation avant, le séjour après.
@Model final class Hotel {
    var cle: String = UUID().uuidString
    var nom: String = ""
    var ville: String = ""
    var adresse: String = ""
    var tel: String = ""
    var site: String = ""
    var arrivee: String = ""
    var depart: String = ""
    var personnes: Int = 2
    var prix: Double = 0
    var prixFinal: Double = 0
    var confirmation: String = ""
    var lienResa: String = ""
    var options: [String] = []
    var annulation: String = ""
    var rappel: String = ""         // la clé de l'événement « annuler gratuitement ? » au calendrier
    var note: String = ""
    var noteFinale: Double = 0
    var avisJSON: Data? = nil
    var avisNote: Double = 0
    var avisNb: String = ""
    var avisSource: String = ""
    var avisResume: String = ""
    var infosStatut: String = "a_chercher"
    var foyer: String = ""
    var par: String = ""
    var cree: Date = Date.now

    init(nom: String, ville: String, foyer: String, par: String) {
        self.nom = nom; self.ville = ville; self.foyer = foyer; self.par = par
    }
    var avis: [String: AvisMembre] {
        get { decoder(avisJSON, [String: AvisMembre].self) ?? [:] }
        set { avisJSON = encoder(newValue) }
    }
    var nuits: Int {
        guard !arrivee.isEmpty, !depart.isEmpty else { return 0 }
        return max(1, Jour.joursJusqua(depart) - Jour.joursJusqua(arrivee))
    }
    enum Etat { case aDater, aVenir, enCours, fini }
    var etat: Etat {
        let a = Jour.aujourdhui
        if arrivee.isEmpty { return .aDater }
        if a < arrivee { return .aVenir }
        if a <= (depart.isEmpty ? arrivee : depart) { return .enCours }
        return .fini
    }
    var prixRetenu: Double { prixFinal > 0 ? prixFinal : prix }
}

/// Une photo d'une sortie ou d'un séjour : le plat, l'ambiance, la chambre.
@Model final class PhotoLoisir {
    var cle: String = UUID().uuidString
    var parent: String = ""         // la clé de la sortie ou de l'hôtel
    var quoi: String = "plat"
    @Attribute(.externalStorage) var image: Data? = nil
    var par: String = ""
    var cree: Date = Date.now

    init(parent: String, quoi: String, image: Data?, par: String) {
        self.parent = parent; self.quoi = quoi; self.image = image; self.par = par
    }
}

enum OptionsHotel {
    static let toutes: [(id: String, nom: String)] = [
        ("petitdej", "Petit-déjeuner inclus"), ("parking", "Parking"), ("borne", "Borne de recharge"),
        ("piscine", "Piscine"), ("animaux", "Animaux acceptés"), ("clim", "Climatisation"),
    ]
}

/// Liens utiles : la carte (Plans), l'appel, la page où laisser un avis.
enum LiensLoisirs {
    static func carte(nom: String, lieu: String) -> URL? {
        URL(string: "https://maps.apple.com/?q=" + [nom, lieu].filter { !$0.isEmpty }.joined(separator: ", ")
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)
    }
    static func tel(_ t: String) -> URL? {
        var n = t.filter { $0.isNumber || $0 == "+" }
        if n.hasPrefix("0") { n = "+32" + n.dropFirst() }
        return n.isEmpty ? nil : URL(string: "tel:" + n)
    }
    static func avisGoogle(nom: String, lieu: String) -> URL? {
        URL(string: "https://www.google.com/maps/search/?api=1&query="
            + ([nom, lieu].filter { !$0.isEmpty }.joined(separator: ", ").addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""))
    }
    static func avisTripadvisor(nom: String, lieu: String) -> URL? {
        URL(string: "https://www.tripadvisor.fr/Search?q="
            + ([nom, lieu].filter { !$0.isEmpty }.joined(separator: " ").addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""))
    }
    static func booking(_ quoi: String, arrivee: String, depart: String, personnes: Int) -> URL? {
        URL(string: "https://www.booking.com/searchresults.fr.html?ss=\(quoi.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&checkin=\(arrivee)&checkout=\(depart)&group_adults=\(personnes)&no_rooms=1&selected_currency=EUR")
    }
    static func sur(_ s: String) -> URL? { s.hasPrefix("https://") ? URL(string: s) : nil }
}

/// Une sortie ou un hôtel daté pendant un voyage du calendrier (ou un séjour à Fréjus) compte dans « Vacances ».
enum Vacances {
    static func voyage(le date: String, parmi evenements: [Evenement]) -> Evenement? {
        guard !date.isEmpty else { return nil }
        return evenements.first { ($0.type == "voyage" || $0.type == "frejus") && $0.debut <= date && $0.fin >= date && $0.fin > $0.debut }
            ?? evenements.first { ($0.type == "voyage" || $0.type == "frejus") && $0.debut <= date && $0.fin >= date }
    }
}

// MARK: - Synchronisation iCloud

extension Restaurant: AvecCle {}
extension Sortie: AvecCle {}
extension Hotel: AvecCle {}
extension PhotoLoisir: AvecCle {}

extension Restaurant: Synchronisable {
    static let typeEnregistrement = "Restaurant"
    var idSynchro: String { cle }
    var aPartager: Bool { true }
    func remplir(_ r: CKRecord) {
        r["nom"] = nom; r["ville"] = ville; r["adresse"] = adresse; r["tel"] = tel; r["cuisine"] = cuisine
        r["horaires"] = horaires; r["site"] = site; r["reserver"] = reserver; r["menuLien"] = menuLien
        r["menu"] = menuJSON; r["menuNote"] = menuNote; r["avisNote"] = avisNote; r["avisNb"] = avisNb
        r["avisSource"] = avisSource; r["avisResume"] = avisResume; r["infosStatut"] = infosStatut
        r["infosMaj"] = infosMaj; r["par"] = par; r["cree"] = cree
    }
    func lire(_ r: CKRecord) {
        nom = r.s("nom"); ville = r.s("ville"); adresse = r.s("adresse"); tel = r.s("tel"); cuisine = r.s("cuisine")
        horaires = r.s("horaires"); site = r.s("site"); reserver = r.s("reserver"); menuLien = r.s("menuLien")
        menuJSON = r["menu"] as? Data; menuNote = r.s("menuNote"); avisNote = r.nombre("avisNote"); avisNb = r.s("avisNb")
        avisSource = r.s("avisSource"); avisResume = r.s("avisResume"); infosStatut = r.s("infosStatut")
        infosMaj = r.s("infosMaj"); par = r.s("par"); cree = r.date("cree")
    }
}

extension Sortie: Synchronisable {
    static let typeEnregistrement = "Sortie"
    var idSynchro: String { cle }
    var aPartager: Bool { true }
    func remplir(_ r: CKRecord) {
        r["type"] = type; r["ref"] = ref; r["nom"] = nom; r["lieu"] = lieu; r["foyer"] = foyer; r["date"] = date
        r["montant"] = montant; r["personnes"] = personnes; r["qui"] = qui; r["avis"] = avisJSON; r["par"] = par; r["cree"] = cree
    }
    func lire(_ r: CKRecord) {
        type = r.s("type"); ref = r.s("ref"); nom = r.s("nom"); lieu = r.s("lieu"); foyer = r.s("foyer"); date = r.s("date")
        montant = r.nombre("montant"); personnes = r.entier("personnes") ?? 2; qui = r.liste("qui")
        avisJSON = r["avis"] as? Data; par = r.s("par"); cree = r.date("cree")
    }
}

extension Hotel: Synchronisable {
    static let typeEnregistrement = "Hotel"
    var idSynchro: String { cle }
    var aPartager: Bool { true }
    func remplir(_ r: CKRecord) {
        r["nom"] = nom; r["ville"] = ville; r["adresse"] = adresse; r["tel"] = tel; r["site"] = site
        r["arrivee"] = arrivee; r["depart"] = depart; r["personnes"] = personnes; r["prix"] = prix; r["prixFinal"] = prixFinal
        r["confirmation"] = confirmation; r["lienResa"] = lienResa; r["options"] = options; r["annulation"] = annulation
        r["rappel"] = rappel; r["note"] = note; r["noteFinale"] = noteFinale; r["avis"] = avisJSON
        r["avisNote"] = avisNote; r["avisNb"] = avisNb; r["avisSource"] = avisSource; r["avisResume"] = avisResume
        r["infosStatut"] = infosStatut; r["foyer"] = foyer; r["par"] = par; r["cree"] = cree
    }
    func lire(_ r: CKRecord) {
        nom = r.s("nom"); ville = r.s("ville"); adresse = r.s("adresse"); tel = r.s("tel"); site = r.s("site")
        arrivee = r.s("arrivee"); depart = r.s("depart"); personnes = r.entier("personnes") ?? 2; prix = r.nombre("prix")
        prixFinal = r.nombre("prixFinal"); confirmation = r.s("confirmation"); lienResa = r.s("lienResa"); options = r.liste("options")
        annulation = r.s("annulation"); rappel = r.s("rappel"); note = r.s("note"); noteFinale = r.nombre("noteFinale")
        avisJSON = r["avis"] as? Data; avisNote = r.nombre("avisNote"); avisNb = r.s("avisNb"); avisSource = r.s("avisSource")
        avisResume = r.s("avisResume"); infosStatut = r.s("infosStatut"); foyer = r.s("foyer"); par = r.s("par"); cree = r.date("cree")
    }
}

extension PhotoLoisir: Synchronisable {
    static let typeEnregistrement = "PhotoLoisir"
    var idSynchro: String { cle }
    var aPartager: Bool { true }
    func remplir(_ r: CKRecord) {
        r["parent"] = parent; r["quoi"] = quoi; r["par"] = par; r["cree"] = cree
        if let image {
            let f = FileManager.default.temporaryDirectory.appendingPathComponent(cle + ".jpg")
            if (try? image.write(to: f)) != nil { r["image"] = CKAsset(fileURL: f) }
        }
    }
    func lire(_ r: CKRecord) {
        parent = r.s("parent"); quoi = r.s("quoi"); par = r.s("par"); cree = r.date("cree")
        if let a = r["image"] as? CKAsset, let f = a.fileURL { image = try? Data(contentsOf: f) }
    }
}

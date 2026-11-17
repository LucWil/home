import Foundation
import SwiftData
import CloudKit

// Les placards de la petite maison de Fréjus. Le stock de Fréjus, ce sont des `Article`
// avec foyer = "frejus" : la cuisine les montre telle quelle. La maison est à toute la famille.
// À l'arrivée on fait l'inventaire, pendant le séjour ce qu'on mange sort du stock de Fréjus,
// au départ on vide le frigo. Ce qui est fini ou manque part dans la liste « à racheter ».

/// Un objet de la maison de Fréjus (vaisselle, linge, terrasse…), avec le nombre attendu.
@Model final class ObjetMaison {
    var cle: String = UUID().uuidString
    var objet: String = ""
    var piece: String = "Cuisine"
    var quantite: Int = 1
    var etat: String = "bon"            // "bon", "use", "remplacer" (comme l'app web)
    var compte: Int? = nil              // le dernier comptage
    var vu: String? = nil               // compté le
    var par: String = ""
    var cree: Date = Date.now

    init(objet: String, piece: String, quantite: Int, par: String) {
        self.objet = objet; self.piece = piece; self.quantite = quantite; self.par = par
    }
}

/// Une chose à racheter pour la maison de Fréjus.
@Model final class ARacheter {
    var cle: String = UUID().uuidString
    var nom: String = ""
    var par: String = ""
    var cree: Date = Date.now

    init(nom: String, par: String) { self.nom = nom; self.par = par }
}

extension ObjetMaison: Synchronisable {
    static let typeEnregistrement = "ObjetMaison"
    var idSynchro: String { cle }
    var aPartager: Bool { true }
    func remplir(_ r: CKRecord) {
        r["objet"] = objet; r["piece"] = piece; r["quantite"] = quantite; r["etat"] = etat
        r["compte"] = compte; r["vu"] = vu; r["par"] = par; r["cree"] = cree
    }
    func lire(_ r: CKRecord) {
        objet = r.s("objet"); piece = r.s("piece"); quantite = r.entier("quantite") ?? 1; etat = r.s("etat")
        compte = r.entier("compte"); vu = r["vu"] as? String; par = r.s("par"); cree = r.date("cree")
    }
}

extension ARacheter: Synchronisable {
    static let typeEnregistrement = "ARacheter"
    var idSynchro: String { cle }
    var aPartager: Bool { true }
    func remplir(_ r: CKRecord) { r["nom"] = nom; r["par"] = par; r["cree"] = cree }
    func lire(_ r: CKRecord) { nom = r.s("nom"); par = r.s("par"); cree = r.date("cree") }
}

enum Frejus {
    static let cle = "frejus"
    static let nom = "Fréjus"
    /// Le choix « Fréjus ou mon foyer » de l'onglet Cuisine (vide = mon foyer).
    static let cleLieu = "cuisine.lieu"

    /// Le séjour à Fréjus qui couvre ce jour, si j'en suis (ou si personne n'est précisé).
    static func sejour(_ evenements: [Evenement], moi: String, le jour: String = Jour.aujourdhui) -> Evenement? {
        let miens = Famille.foyers.first { $0.membres.contains(moi) }?.membres ?? [moi]
        return evenements.first {
            $0.type == "frejus" && $0.debut <= jour && $0.fin >= jour
                && ($0.personnes.isEmpty || $0.personnes.contains { miens.contains($0) })
        }
    }
    static func prochain(_ evenements: [Evenement]) -> Evenement? {
        evenements.filter { $0.type == "frejus" && $0.debut > Jour.aujourdhui }.min { $0.debut < $1.debut }
    }

    /// Ce qui demande un coup d'œil à l'inventaire (nil = rien à signaler).
    static func alerte(_ a: Article) -> String? {
        if a.rangement == "armoire", let p = a.peremption, Jour.joursJusqua(p) < 0 {
            return "périmé depuis le \(Jour.joli(p, .dateTime.day().month(.abbreviated).year()))"
        }
        if a.rangement == "frais", let j = a.joursRestants, j < 0 { return "au frigo depuis \(Jour.joursDepuis(a.depuis)) jours" }
        if a.rangement == "surgelateur", Jour.joursDepuis(a.depuis) > 300 { return "congelé il y a \(Jour.joursDepuis(a.depuis) / 30) mois" }
        let vu = a.verifie ?? a.depuis
        if Jour.joursDepuis(vu) > 300 { return "pas revu depuis \(Jour.joursDepuis(vu) / 30) mois" }
        return nil
    }

    /// Note des choses à racheter pour Fréjus (sans doublon).
    static func aRacheter(_ noms: [String], par: String, dans ctx: ModelContext) {
        let deja = Set(((try? ctx.fetch(FetchDescriptor<ARacheter>())) ?? []).map { simple($0.nom) })
        for n in Set(noms.map { $0.trimmingCharacters(in: .whitespaces) }) where !n.isEmpty && !deja.contains(simple(n)) {
            ctx.insert(ARacheter(nom: n, par: par))
        }
    }

    static func simple(_ s: String) -> String {
        s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "fr_BE")).trimmingCharacters(in: .whitespaces)
    }

    /// Où ranger une ligne écrite à la va-vite (« 3 boîtes de thon », « glaçons au congélateur »).
    static func ranger(_ ligne: String) -> (Rangement, String) {
        let s = simple(ligne)
        if ["surgel", "congel", "glace", "glacon"].contains(where: { s.contains($0) }) {
            return (.surgelateur, Categorie.deviner(nom: ligne, dans: "surgelateur").flatMap { ["viandes", "poissons", "plats", "legumes", "pains"].contains($0) ? $0 : nil } ?? "plats")
        }
        if let c = Categorie.deviner(nom: ligne, dans: "frais"), ["legumes", "fruits", "viandes", "poissons", "cremerie"].contains(c) {
            return (.frais, c)
        }
        return (.armoire, Categorie.deviner(nom: ligne, dans: "armoire") ?? "autre")
    }

    static let pieces = ["Cuisine", "Chambre", "Salle de bain", "Séjour", "Terrasse", "Rangement"]

    /// La liste type d'une maison de vacances, pour démarrer l'inventaire.
    static let listeType: [(piece: String, objets: [(String, Int)])] = [
        ("Cuisine", [("Assiettes plates", 8), ("Assiettes creuses", 8), ("Assiettes à dessert", 8), ("Verres à eau", 8), ("Verres à vin", 6),
                     ("Tasses", 6), ("Bols", 6), ("Fourchettes", 8), ("Couteaux", 8), ("Cuillères à soupe", 8), ("Petites cuillères", 8),
                     ("Casseroles", 3), ("Poêles", 2), ("Faitout", 1), ("Plat à four", 2), ("Saladier", 2), ("Planche à découper", 2),
                     ("Couteaux de cuisine", 3), ("Passoire", 1), ("Louche et spatule", 1), ("Ouvre-boîte", 1), ("Tire-bouchon", 1),
                     ("Cafetière", 1), ("Bouilloire", 1), ("Grille-pain", 1), ("Torchons", 6), ("Éponges", 2)]),
        ("Chambre", [("Draps housse", 4), ("Housses de couette", 4), ("Taies d'oreiller", 8), ("Oreillers", 4), ("Couvertures", 4), ("Cintres", 20)]),
        ("Salle de bain", [("Serviettes de bain", 6), ("Serviettes de toilette", 6), ("Tapis de bain", 1), ("Sèche-cheveux", 1)]),
        ("Séjour", [("Télécommande", 1), ("Jeux de société", 3), ("Ampoules de rechange", 4)]),
        ("Terrasse", [("Chaises", 6), ("Table", 1), ("Parasol", 1), ("Transats", 2), ("Coussins", 6), ("Barbecue", 1)]),
        ("Rangement", [("Aspirateur", 1), ("Balai et serpillière", 1), ("Seau", 1), ("Fer à repasser", 1), ("Planche à repasser", 1),
                       ("Étendoir", 1), ("Pinces à linge", 30), ("Trousse de secours", 1), ("Lampe de poche", 1), ("Piles", 8)]),
    ]
}

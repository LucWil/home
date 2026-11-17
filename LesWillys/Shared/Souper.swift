import Foundation
import SwiftData
import CloudKit

// « Ce soir à la maison ? » : chacun touche son aimant pour dire s'il mange à la maison ce soir.
// Une réponse par personne et par jour (cle "<aaaa-mm-jj>_<membre>"), pour que deux téléphones
// qui répondent en même temps pour deux personnes différentes ne s'écrasent pas.

@Model final class ReponseSouper {
    var cle: String = ""
    var date: String = ""
    var foyer: String = ""
    var membre: String = ""
    var etat: String = ""          // "oui", "tard" ou "non"
    var par: String = ""
    var quand: Date = Date.now

    init(date: String, foyer: String, membre: String, etat: String, par: String) {
        self.cle = date + "_" + membre
        self.date = date; self.foyer = foyer; self.membre = membre; self.etat = etat; self.par = par
    }
}

extension ReponseSouper: Synchronisable {
    static let typeEnregistrement = "ReponseSouper"
    var idSynchro: String { cle }
    var aPartager: Bool { true }
    func remplir(_ r: CKRecord) {
        r["date"] = date; r["foyer"] = foyer; r["membre"] = membre; r["etat"] = etat; r["par"] = par; r["quand"] = quand
    }
    func lire(_ r: CKRecord) {
        date = r.s("date"); foyer = r.s("foyer"); membre = r.s("membre"); etat = r.s("etat"); par = r.s("par"); quand = r.date("quand")
    }
}

enum Souper {
    /// Les états dans l'ordre où on les fait défiler en touchant l'aimant (vide = pas encore répondu).
    static let ordre = ["", "oui", "tard", "non"]
    static func libelle(_ e: String) -> String {
        switch e { case "oui": "à table"; case "tard": "plus tard"; case "non": "pas ce soir"; default: "pas encore répondu" }
    }
    static func signe(_ e: String) -> String {
        switch e { case "oui": "✓"; case "tard": "🕗"; case "non": "✗"; default: "?" }
    }

    /// Qui peut manger dans ce foyer ce soir : ses adultes, et les petites si elles sont en garde chez eux aujourd'hui.
    static func membres(foyer: String, evenements: [Evenement], le jour: String = Jour.aujourdhui) -> [String] {
        let adultes = Famille.foyers.first { $0.id == foyer }?.membres ?? []
        let gardes = evenements.filter { $0.type == "garde" && $0.debut <= jour && $0.fin >= jour && adultes.contains($0.gardeChez ?? "") }
        let petites = Famille.enfants.map(\.id).filter { k in gardes.contains { $0.personnes.isEmpty || $0.personnes.contains(k) } }
        return adultes + petites
    }
}

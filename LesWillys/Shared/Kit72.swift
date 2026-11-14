import Foundation
import SwiftData
import CloudKit

// Le kit 72 heures : tenir trois jours sans électricité, sans eau courante ni chauffage
// (Centre national de crise, « Préparés ensemble »). Comme l'app web : un kit par foyer,
// le plan familial, l'essai « sans courant » et les retours d'expérience partagés.
// Chaque ligne cochée est son propre enregistrement ("<foyer>_<clé>") : deux personnes qui cochent
// en même temps deux choses différentes ne s'écrasent pas.

@Model final class KitFoyer {
    var cle: String = ""                 // le foyer
    var personnes: Int = 2
    var rdv: String = ""
    var rdv2: String = ""
    var petites: String = ""
    var contacts: String = ""
    var radio: String = ""
    var essaiDate: String = ""
    var essaiDuree: String = ""
    var essaiBilan: String = ""
    var par: String = ""
    var quand: Date = Date.now

    init(foyer: String, personnes: Int) { cle = foyer; self.personnes = personnes }
}

@Model final class ElementKit {
    var cle: String = ""                 // "<foyer>_<clé de la liste>"
    var foyer: String = ""
    var element: String = ""
    var ok: Bool = false
    var qte: String = ""
    var exp: String = ""                 // à consommer avant (aaaa-mm-jj), vide si rien
    var par: String = ""
    var quand: Date = Date.now

    init(foyer: String, element: String) { self.foyer = foyer; self.element = element; cle = foyer + "_" + element }
}

@Model final class NoteKit {
    var cle: String = UUID().uuidString
    var texte: String = ""
    var foyer: String = ""
    var par: String = ""
    var cree: Date = Date.now

    init(texte: String, foyer: String, par: String) { self.texte = texte; self.foyer = foyer; self.par = par }
}

extension KitFoyer: Synchronisable {
    static let typeEnregistrement = "KitFoyer"
    var idSynchro: String { cle }
    var aPartager: Bool { true }
    func remplir(_ r: CKRecord) {
        r["personnes"] = personnes; r["rdv"] = rdv; r["rdv2"] = rdv2; r["petites"] = petites; r["contacts"] = contacts; r["radio"] = radio
        r["essaiDate"] = essaiDate; r["essaiDuree"] = essaiDuree; r["essaiBilan"] = essaiBilan; r["par"] = par; r["quand"] = quand
    }
    func lire(_ r: CKRecord) {
        personnes = r.entier("personnes") ?? 2; rdv = r.s("rdv"); rdv2 = r.s("rdv2"); petites = r.s("petites"); contacts = r.s("contacts"); radio = r.s("radio")
        essaiDate = r.s("essaiDate"); essaiDuree = r.s("essaiDuree"); essaiBilan = r.s("essaiBilan"); par = r.s("par"); quand = r.date("quand")
    }
}

extension ElementKit: Synchronisable {
    static let typeEnregistrement = "ElementKit"
    var idSynchro: String { cle }
    var aPartager: Bool { true }
    func remplir(_ r: CKRecord) {
        r["foyer"] = foyer; r["element"] = element; r["ok"] = ok; r["qte"] = qte; r["exp"] = exp; r["par"] = par; r["quand"] = quand
    }
    func lire(_ r: CKRecord) {
        foyer = r.s("foyer"); element = r.s("element"); ok = r.vrai("ok"); qte = r.s("qte"); exp = r.s("exp"); par = r.s("par"); quand = r.date("quand")
    }
}

extension NoteKit: Synchronisable {
    static let typeEnregistrement = "NoteKit"
    var idSynchro: String { cle }
    var aPartager: Bool { true }
    func remplir(_ r: CKRecord) { r["texte"] = texte; r["foyer"] = foyer; r["par"] = par; r["cree"] = cree }
    func lire(_ r: CKRecord) { texte = r.s("texte"); foyer = r.s("foyer"); par = r.s("par"); cree = r.date("cree") }
}

/// Une chose à avoir : clé, libellé, quantité conseillée pour P personnes, date à surveiller, conseil.
struct ChoseKit: Identifiable {
    let id: String
    let libelle: String
    let quantite: (Int) -> String
    let date: Bool
    let conseil: String
}

enum Kit72 {
    static let groupes: [(titre: String, choses: [ChoseKit])] = [
        ("L'eau", [
            ChoseKit(id: "eau", libelle: "Eau potable en bouteilles", quantite: { "\(9 * $0) L (3 L par personne et par jour)" }, date: true,
                     conseil: "Le Centre de crise conseille 3 L par jour et par personne pour boire et cuisiner. Fais tourner les packs : on boit le plus ancien, on rachète."),
            ChoseKit(id: "eau2", libelle: "Eau pour se laver et la toilette", quantite: { "\(6 * $0) L (bidons, baignoire remplie au début)" }, date: false,
                     conseil: "Si une coupure est annoncée, remplis la baignoire et des seaux."),
            ChoseKit(id: "pastilles", libelle: "Pastilles ou filtre pour purifier l'eau", quantite: { _ in "1 boîte" }, date: true, conseil: ""),
        ]),
        ("Manger sans cuisiner", [
            ChoseKit(id: "conserves", libelle: "Conserves prêtes à manger (plats, poisson, légumes)", quantite: { "\(6 * $0) boîtes" }, date: true,
                     conseil: "Choisis ce que la famille mange déjà, à ouverture facile."),
            ChoseKit(id: "sec", libelle: "Biscuits, crackers, barres énergétiques, fruits secs", quantite: { "\(3 * $0) paquets" }, date: true, conseil: ""),
            ChoseKit(id: "lait", libelle: "Lait UHT, compotes, céréales pour les petites", quantite: { _ in "pour 3 jours" }, date: true, conseil: ""),
            ChoseKit(id: "ouvre", libelle: "Ouvre-boîte manuel, couverts, assiettes et gobelets jetables", quantite: { _ in "1 kit" }, date: false, conseil: ""),
            ChoseKit(id: "rechaud", libelle: "Réchaud de camping et cartouches de gaz", quantite: { _ in "1 réchaud + 2 cartouches" }, date: false,
                     conseil: "Toujours dehors ou fenêtre ouverte : jamais en pièce fermée (monoxyde de carbone)."),
        ]),
        ("Lumière, énergie, nouvelles", [
            ChoseKit(id: "radio", libelle: "Radio à piles ou à manivelle (FM)", quantite: { _ in "1" }, date: false,
                     conseil: "Sans internet, la radio reste la source d'information officielle (RTBF, VRT)."),
            ChoseKit(id: "lampes", libelle: "Lampes de poche ou frontales", quantite: { "\($0)" }, date: false, conseil: ""),
            ChoseKit(id: "piles", libelle: "Piles de rechange", quantite: { _ in "2 jeux par appareil" }, date: true, conseil: ""),
            ChoseKit(id: "powerbank", libelle: "Batteries externes chargées", quantite: { "\(max(2, ($0 + 1) / 2))" }, date: false, conseil: "Recharge-les tous les 3 mois."),
            ChoseKit(id: "bougies", libelle: "Bougies, allumettes, briquet", quantite: { _ in "1 boîte" }, date: false, conseil: "Jamais sans surveillance, loin des rideaux."),
            ChoseKit(id: "voiture", libelle: "Voiture chargée ou réservoir à moitié plein au moins", quantite: { _ in "≥ 50 %" }, date: false,
                     conseil: "La voiture recharge aussi les téléphones."),
        ]),
        ("Rester au chaud", [
            ChoseKit(id: "couvertures", libelle: "Couvertures ou sacs de couchage", quantite: { "\($0)" }, date: false,
                     conseil: "Regroupez-vous dans une seule pièce, porte fermée."),
            ChoseKit(id: "survie", libelle: "Couvertures de survie", quantite: { "\($0)" }, date: false, conseil: ""),
            ChoseKit(id: "vetements", libelle: "Vêtements chauds, bonnets, chaussettes", quantite: { _ in "pour chacun" }, date: false, conseil: ""),
        ]),
        ("Santé et hygiène", [
            ChoseKit(id: "trousse", libelle: "Trousse de premiers secours", quantite: { _ in "1" }, date: true, conseil: ""),
            ChoseKit(id: "medocs", libelle: "Médicaments personnels et ordonnances", quantite: { _ in "7 jours d'avance" }, date: true,
                     conseil: "Pense aux traitements de chacun et au paracétamol pour les petites."),
            ChoseKit(id: "hygiene", libelle: "Papier toilette, lingettes, gel hydroalcoolique", quantite: { "\($0) rouleaux, 2 paquets" }, date: false, conseil: ""),
            ChoseKit(id: "sacs", libelle: "Sacs poubelle solides et un seau", quantite: { _ in "1 rouleau" }, date: false,
                     conseil: "Sans eau, ils servent aussi de toilette de secours."),
            ChoseKit(id: "masques", libelle: "Masques", quantite: { "\(2 * $0)" }, date: false, conseil: ""),
        ]),
        ("Papiers, argent, contacts", [
            ChoseKit(id: "cash", libelle: "Argent liquide en petites coupures", quantite: { _ in "≥ 200 €" }, date: false, conseil: "Sans électricité, ni carte ni Payconiq."),
            ChoseKit(id: "papiers", libelle: "Copies des papiers (identité, assurances, banque) sur papier et clé USB", quantite: { _ in "1 pochette" }, date: false, conseil: ""),
            ChoseKit(id: "numeros", libelle: "Les numéros importants écrits sur papier", quantite: { _ in "1 feuille" }, date: false,
                     conseil: "112, médecin, voisins, la famille : sans téléphone chargé, on ne s'en souvient plus."),
            ChoseKit(id: "cles", libelle: "Double des clés (maison, voiture)", quantite: { _ in "1 jeu" }, date: false, conseil: ""),
        ]),
        ("Outils", [
            ChoseKit(id: "couteau", libelle: "Couteau multifonction, ruban adhésif, gants", quantite: { _ in "1 kit" }, date: false, conseil: ""),
            ChoseKit(id: "sifflet", libelle: "Sifflet", quantite: { _ in "1" }, date: false, conseil: ""),
            ChoseKit(id: "sac", libelle: "Un sac à dos prêt à partir (eau, barres, copies, lampe, médicaments)", quantite: { "\(max(1, ($0 + 1) / 2))" }, date: false,
                     conseil: "Si on doit quitter la maison, on prend ce sac et on part."),
        ]),
        ("Les petites", [
            ChoseKit(id: "jeux", libelle: "Jeux, livres, crayons (sans écran)", quantite: { _ in "de quoi occuper 3 jours" }, date: false, conseil: ""),
            ChoseKit(id: "doudous", libelle: "Doudous et petit nécessaire de nuit", quantite: { _ in "chacune" }, date: false, conseil: ""),
        ]),
    ]
    static let toutes = groupes.flatMap(\.choses)

    static func score(_ elements: [ElementKit], foyer: String) -> Int {
        let ok = Set(elements.filter { $0.foyer == foyer && $0.ok }.map(\.element))
        return Int((Double(toutes.filter { ok.contains($0.id) }.count) / Double(toutes.count) * 100).rounded())
    }

    /// Ce qui est coché, daté, et périme dans les 30 jours (ou est déjà périmé).
    static func aRenouveler(_ elements: [ElementKit], foyer: String) -> [ElementKit] {
        let limite = Jour.plus(30)
        let dates = Set(toutes.filter(\.date).map(\.id))
        return elements.filter { $0.foyer == foyer && $0.ok && dates.contains($0.element) && !$0.exp.isEmpty && $0.exp <= limite }
    }
    static func libelle(_ id: String) -> String { toutes.first { $0.id == id }?.libelle ?? id }
}

import Foundation
import SwiftData
import CloudKit

// Le pont entre la base locale (SwiftData) et la maison commune iCloud (CloudKit).
// Chaque objet devient un enregistrement CloudKit nommé "<Type>/<identifiant>".

protocol Synchronisable: PersistentModel {
    static var typeEnregistrement: String { get }
    /// Identifiant unique dans son type (la `cle` d'origine de l'app web).
    var idSynchro: String { get }
    /// Faux pour ce qui ne doit jamais quitter l'appareil (les IBAN).
    var aPartager: Bool { get }
    func remplir(_ r: CKRecord)
    func lire(_ r: CKRecord)
}

extension Synchronisable {
    var nomEnregistrement: String { Self.typeEnregistrement + "/" + idSynchro }
}

// MARK: - File d'envoi
// L'app et les widgets notent ici ce qui a changé ; l'app l'envoie ensuite à iCloud.
// (Un widget ne peut pas parler à iCloud lui-même : son « Mangé » attend la prochaine ouverture de l'app.)

enum FileSynchro {
    private static let cleAttente = "synchro.attente"

    static func ajouter(_ elements: [String]) {
        guard !elements.isEmpty else { return }
        var liste = Base.reglages.stringArray(forKey: cleAttente) ?? []
        liste.append(contentsOf: elements)
        Base.reglages.set(liste, forKey: cleAttente)
    }

    /// Retire et rend tout ce qui attend, dans l'ordre : "save:Type/id" ou "delete:Type/id".
    static func vider() -> [String] {
        let liste = Base.reglages.stringArray(forKey: cleAttente) ?? []
        Base.reglages.removeObject(forKey: cleAttente)
        return liste
    }
}

extension Notification.Name {
    static let willysModifie = Notification.Name("willys.modifie")
}

extension ModelContext {
    /// À utiliser à la place de `save()` pour tout changement fait par quelqu'un de la famille :
    /// enregistre, puis met le changement dans la file d'envoi vers la maison commune.
    func enregistrer() {
        Journal.noter(dans: self)
        // Les suppressions d'abord : un objet remplacé (même nom, ex. la visite du jour) doit finir « enregistré ».
        var elements: [String] = []
        for m in deletedModelsArray {
            if let s = m as? any Synchronisable, s.aPartager { elements.append("delete:" + s.nomEnregistrement) }
        }
        for m in insertedModelsArray + changedModelsArray {
            if let s = m as? any Synchronisable, s.aPartager { elements.append("save:" + s.nomEnregistrement) }
        }
        do { try save() } catch { return }
        FileSynchro.ajouter(elements)
        NotificationCenter.default.post(name: .willysModifie, object: nil)
    }
}

// MARK: - Lecture tolérante d'un enregistrement

extension CKRecord {
    func s(_ k: String) -> String { self[k] as? String ?? "" }
    func liste(_ k: String) -> [String] { self[k] as? [String] ?? [] }
    func date(_ k: String) -> Date { self[k] as? Date ?? .now }
    func nombre(_ k: String) -> Double { (self[k] as? NSNumber)?.doubleValue ?? 0 }
    func entier(_ k: String) -> Int? { (self[k] as? NSNumber)?.intValue }
    func vrai(_ k: String) -> Bool { (self[k] as? NSNumber)?.boolValue ?? false }
}

// MARK: - Chaque modèle

extension Evenement: Synchronisable {
    static let typeEnregistrement = "Evenement"
    var idSynchro: String { cle }
    var aPartager: Bool { true }
    func remplir(_ r: CKRecord) {
        r["type"] = type; r["titre"] = titre; r["debut"] = debut; r["fin"] = fin
        r["personnes"] = personnes; r["gardeChez"] = gardeChez; r["par"] = par; r["cree"] = cree
    }
    func lire(_ r: CKRecord) {
        type = r.s("type"); titre = r.s("titre"); debut = r.s("debut"); fin = r.s("fin")
        personnes = r.liste("personnes"); gardeChez = r["gardeChez"] as? String; par = r.s("par"); cree = r.date("cree")
    }
}

extension Idee: Synchronisable {
    static let typeEnregistrement = "Idee"
    var idSynchro: String { cle }
    var aPartager: Bool { true }
    func remplir(_ r: CKRecord) {
        r["genre"] = genre; r["titre"] = titre; r["quand"] = quand; r["prix"] = prix; r["lien"] = lien
        r["photo"] = photo; r["note"] = note; r["par"] = par; r["cree"] = cree
    }
    func lire(_ r: CKRecord) {
        genre = r.s("genre"); titre = r.s("titre"); quand = r.s("quand"); prix = r.s("prix"); lien = r.s("lien")
        photo = r.s("photo"); note = r.s("note"); par = r.s("par"); cree = r.date("cree")
    }
}

extension Reaction: Synchronisable {
    static let typeEnregistrement = "Reaction"
    var idSynchro: String { cle }
    var aPartager: Bool { true }
    func remplir(_ r: CKRecord) { r["element"] = element; r["membre"] = membre; r["reaction"] = reaction; r["cree"] = cree }
    func lire(_ r: CKRecord) { element = r.s("element"); membre = r.s("membre"); reaction = r.s("reaction"); cree = r.date("cree") }
}

extension Article: Synchronisable {
    static let typeEnregistrement = "Article"
    var idSynchro: String { cle }
    var aPartager: Bool { true }
    func remplir(_ r: CKRecord) {
        r["foyer"] = foyer; r["rangement"] = rangement; r["nom"] = nom; r["quantite"] = quantite
        r["categorie"] = categorie; r["depuis"] = depuis; r["bonJours"] = bonJours; r["peremption"] = peremption
        r["prix"] = prix; r["tiroir"] = tiroir; r["par"] = par; r["cree"] = cree
    }
    func lire(_ r: CKRecord) {
        foyer = r.s("foyer"); rangement = r.s("rangement"); nom = r.s("nom"); quantite = r.s("quantite")
        categorie = r.s("categorie"); depuis = r.s("depuis"); bonJours = r.entier("bonJours")
        peremption = r["peremption"] as? String; prix = r.nombre("prix"); tiroir = r.entier("tiroir")
        par = r.s("par"); cree = r.date("cree")
    }
}

extension Boni: Synchronisable {
    static let typeEnregistrement = "Boni"
    var idSynchro: String { cle }
    var aPartager: Bool { true }
    func remplir(_ r: CKRecord) { r["foyer"] = foyer; r["nom"] = nom; r["valeur"] = valeur; r["par"] = par; r["cree"] = cree }
    func lire(_ r: CKRecord) { foyer = r.s("foyer"); nom = r.s("nom"); valeur = r.nombre("valeur"); par = r.s("par"); cree = r.date("cree") }
}

extension Foyer: Synchronisable {
    static let typeEnregistrement = "Foyer"
    var idSynchro: String { cle }
    var aPartager: Bool { true }
    func remplir(_ r: CKRecord) { r["nom"] = nom; r["objectifLibelle"] = objectifLibelle; r["objectifMontant"] = objectifMontant }
    func lire(_ r: CKRecord) { nom = r.s("nom"); objectifLibelle = r.s("objectifLibelle"); objectifMontant = r.nombre("objectifMontant") }
}

extension Recette: Synchronisable {
    static let typeEnregistrement = "Recette"
    var idSynchro: String { cle }
    var aPartager: Bool { true }
    func remplir(_ r: CKRecord) {
        r["titre"] = titre; r["intro"] = intro; r["personnes"] = personnes; r["cout"] = cout; r["extra"] = extra
        r["photo"] = photo; r["ingredients"] = ingredients; r["etapes"] = etapesJSON; r["envie"] = envie
        r["par"] = par; r["cree"] = cree
    }
    func lire(_ r: CKRecord) {
        titre = r.s("titre"); intro = r.s("intro"); personnes = r.entier("personnes") ?? 4; cout = r.entier("cout") ?? 1
        extra = r.vrai("extra"); photo = r.s("photo"); ingredients = r.liste("ingredients")
        etapesJSON = r["etapes"] as? Data; envie = r.vrai("envie"); par = r.s("par"); cree = r.date("cree")
    }
}

extension Photo: Synchronisable {
    static let typeEnregistrement = "Photo"
    var idSynchro: String { cle }
    var aPartager: Bool { true }
    func remplir(_ r: CKRecord) {
        r["url"] = url.hasPrefix("data:") ? "" : url   // l'image elle-même voyage en pièce jointe
        r["legende"] = legende; r["qui"] = qui; r["par"] = par; r["cree"] = cree
        if let image {
            let fichier = FileManager.default.temporaryDirectory.appendingPathComponent(cle + ".jpg")
            if (try? image.write(to: fichier)) != nil { r["image"] = CKAsset(fileURL: fichier) }
        }
    }
    func lire(_ r: CKRecord) {
        url = r.s("url"); legende = r.s("legende"); qui = r.liste("qui"); par = r.s("par"); cree = r.date("cree")
        if let asset = r["image"] as? CKAsset, let f = asset.fileURL { image = try? Data(contentsOf: f) }
    }
}

extension Visite: Synchronisable {
    static let typeEnregistrement = "Visite"
    var idSynchro: String { cle.isEmpty ? membre : cle }
    var aPartager: Bool { true }
    func remplir(_ r: CKRecord) { r["membre"] = membre; r["quand"] = quand; r["ecran"] = ecran }
    func lire(_ r: CKRecord) { membre = r.s("membre"); quand = r.date("quand"); ecran = r.s("ecran") }
}

extension DocumentBrut: Synchronisable {
    static let typeEnregistrement = "Document"
    var idSynchro: String { collection + ":" + cle }
    /// Les IBAN restent sur l'appareil de celui qui les a importés, comme prévu dans le dossier.
    var aPartager: Bool { collection != "ibans" }
    func remplir(_ r: CKRecord) { r["collection"] = collection; r["json"] = json; r["foyer"] = foyer; r["cree"] = cree }
    func lire(_ r: CKRecord) {
        collection = r.s("collection"); json = r["json"] as? Data ?? Data(); foyer = r.s("foyer"); cree = r.date("cree")
    }
}

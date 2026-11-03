import Foundation
import SwiftData

/// Reprend un fichier « les-willys-sauvegarde-aaaa-mm-jj.json » téléchargé depuis l'app web
/// (Calendrier › La maison › Sauvegarde) ou depuis « Le coffre des Willys ».
///
/// Format : { "source": "les-willys", "collections": { "<nom>": { "<id>": { …document… } } }, "fichiers": {…} }
///
/// Ce qui a une place native (calendrier, idées, stock, boni, recettes, photos…) devient un modèle SwiftData ;
/// tout le reste (jardin, récoltes, restos, entretien, papiers, IBAN…) est gardé tel quel dans `DocumentBrut`.
/// Réimporter le même fichier remplace les éléments déjà importés au lieu de les dupliquer.
struct ImportSauvegarde {
    struct Bilan: CustomStringConvertible {
        var parCollection: [String: Int] = [:]
        var total: Int { parCollection.values.reduce(0, +) }
        var boniParFoyer: [String: Double] = [:]
        var description: String {
            let lignes = parCollection.sorted { $0.key < $1.key }.map { "\($0.key) : \($0.value)" }
            let boni = boniParFoyer.sorted { $0.key < $1.key }.map { "boni \(Famille.nomFoyer($0.key)) : \($0.value.euros)" }
            return (["\(total) éléments importés"] + lignes + boni).joined(separator: "\n")
        }
    }

    enum Erreur: LocalizedError {
        case pasUneSauvegarde
        var errorDescription: String? { "Ce fichier n'est pas une sauvegarde des Willys." }
    }

    let ctx: ModelContext

    func importer(_ data: Data) throws -> Bilan {
        guard let racine = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let collections = racine["collections"] as? [String: [String: Any]] else {
            throw Erreur.pasUneSauvegarde
        }
        var bilan = Bilan()
        for (nom, docs) in collections {
            for (id, brut) in docs {
                guard let d = brut as? [String: Any] else { continue }
                importer(collection: nom, id: id, d: d)
                bilan.parCollection[nom, default: 0] += 1
            }
        }
        try ctx.save()
        for b in (try? ctx.fetch(FetchDescriptor<Boni>())) ?? [] {
            bilan.boniParFoyer[b.foyer, default: 0] += b.valeur
        }
        return bilan
    }

    // MARK: - Une collection à la fois

    private func importer(collection: String, id: String, d: [String: Any]) {
        let par = d.s("by"), at = d.date("at")
        switch collection {
        case "events":
            supprimer(Evenement.self, cle: id)
            let e = Evenement(type: d.s("type", "ensemble"), titre: d.s("title"), debut: d.s("start", Jour.aujourdhui),
                              fin: d.s("end", d.s("start", Jour.aujourdhui)), personnes: d.liste("people"),
                              gardeChez: d["who"] as? String, par: par)
            e.cle = id; e.cree = at; ctx.insert(e)

        case "ideas":
            supprimer(Idee.self, cle: id)
            let i = Idee(genre: d.s("kind", "mot"), titre: d.s("title"), par: par)
            i.cle = id; i.quand = d.s("when"); i.prix = d.s("price"); i.lien = d.s("link")
            i.photo = d.s("photo"); i.note = d.s("note"); i.cree = at; ctx.insert(i)

        case "reactions":
            supprimer(Reaction.self, cle: id)
            let r = Reaction(element: d.s("item"), membre: d.s("member"), reaction: d.s("r"))
            r.cle = id; r.cree = at; ctx.insert(r)

        case "stock":
            supprimer(Article.self, cle: id)
            let a = Article(foyer: d.s("home"), rangement: Rangement(rawValue: d.s("place")) ?? .frais,
                            nom: d.s("name"), categorie: d.s("cat", "autre"), par: par)
            if d.s("place") == "epices" { a.rangement = "armoire"; a.categorie = "epices" }
            a.cle = id; a.quantite = d.s("qty"); a.depuis = d.s("since", Jour.aujourdhui)
            a.bonJours = d.int("days"); a.peremption = d["exp"] as? String
            a.prix = d.nombre("price"); a.tiroir = d.int("drawer"); a.cree = at; ctx.insert(a)

        case "boni":
            supprimer(Boni.self, cle: id)
            let b = Boni(foyer: d.s("home"), nom: d.s("name"), valeur: d.nombre("value"), par: par)
            b.cle = id; b.cree = at; ctx.insert(b)

        case "homes":
            supprimer(Foyer.self, cle: id)
            let f = Foyer(cle: id, nom: d.s("name", Famille.nomFoyer(id)))
            if let but = d["bonusGoal"] as? [String: Any] {
                f.objectifLibelle = but.s("label"); f.objectifMontant = but.nombre("amount")
            }
            ctx.insert(f)
            garderBrut(collection, id, d)   // le code d'accès et le reste restent disponibles

        case "recipes":
            supprimer(Recette.self, cle: id)
            let r = Recette(titre: d.s("title"), par: par)
            r.cle = id; r.intro = d.s("intro"); r.personnes = d.int("servings") ?? 4; r.cout = d.int("cost") ?? 1
            r.extra = d["extra"] as? Bool ?? false; r.photo = d.s("photo"); r.ingredients = d.liste("ingredients")
            r.envie = d["wish"] as? Bool ?? false; r.cree = at
            r.etapes = ((d["steps"] as? [[String: Any]]) ?? []).map {
                EtapeThermomix(text: $0.s("text"), time: $0.s("time"), temp: $0.s("temp"),
                               speed: $0.s("speed"), reverse: $0["reverse"] as? Bool ?? false)
            }
            ctx.insert(r)

        case "photos":
            supprimer(Photo.self, cle: id)
            let p = Photo(legende: d.s("legend"), qui: d.liste("who"), par: par)
            p.cle = id; p.url = d.s("url"); p.cree = at
            if p.url.hasPrefix("data:image"), let virgule = p.url.firstIndex(of: ",") {
                p.image = Data(base64Encoded: String(p.url[p.url.index(after: virgule)...]))
            }
            ctx.insert(p)

        case "visits":
            let v = Visite(membre: d.s("member", id)); v.quand = at; ctx.insert(v)

        default:
            garderBrut(collection, id, d)
        }
    }

    private func garderBrut(_ collection: String, _ id: String, _ d: [String: Any]) {
        let existants = (try? ctx.fetch(FetchDescriptor<DocumentBrut>(
            predicate: #Predicate { $0.collection == collection && $0.cle == id }))) ?? []
        existants.forEach(ctx.delete)
        let json = (try? JSONSerialization.data(withJSONObject: d)) ?? Data()
        let doc = DocumentBrut(collection: collection, cle: id, json: json, foyer: d.s("home"))
        doc.cree = d.date("at"); ctx.insert(doc)
    }

    private func supprimer<T: PersistentModel & AvecCle>(_: T.Type, cle: String) {
        // Chaque modèle natif a une propriété `cle` ; on filtre en mémoire pour rester générique.
        let tous = (try? ctx.fetch(FetchDescriptor<T>())) ?? []
        for o in tous where o.cle == cle { ctx.delete(o) }
    }
}

// MARK: - Lecture tolérante des documents JSON

extension Dictionary where Key == String, Value == Any {
    func s(_ k: String, _ defaut: String = "") -> String {
        if let v = self[k] as? String { return v }
        if let v = self[k] as? NSNumber { return v.stringValue }
        return defaut
    }
    func nombre(_ k: String) -> Double {
        if let v = self[k] as? NSNumber { return v.doubleValue }
        if let v = self[k] as? String { return Double(v.replacingOccurrences(of: ",", with: ".")) ?? 0 }
        return 0
    }
    func int(_ k: String) -> Int? {
        if let v = self[k] as? NSNumber { return v.intValue }
        if let v = self[k] as? String, let n = Int(v) { return n }
        return nil
    }
    func liste(_ k: String) -> [String] { (self[k] as? [Any])?.compactMap { $0 as? String } ?? [] }
    func date(_ k: String) -> Date {
        let ms = nombre(k); return ms > 0 ? Date(timeIntervalSince1970: ms / 1000) : .now
    }
}

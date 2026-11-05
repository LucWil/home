import Foundation
import SwiftData
import CloudKit

// La vie de la maison : qui fait quoi (le fil « Ça bouge à la maison ») et qui est là en ce moment.

/// Une ligne du fil d'activité : « Loulou a rangé 3 articles dans les armoires ».
/// Les gestes répétés d'une même personne sont regroupés (10 minutes) pour ne pas noyer le fil.
@Model final class Activite {
    var cle: String = UUID().uuidString
    var membre: String = ""
    var genre: String = ""          // ex. "range.armoire", "mange", "mot", "evenement", "voyage"…
    var onglet: String = "accueil"  // où l'activité mène quand on la touche
    var detail: String = ""         // le nom du dernier élément concerné
    var nombre: Int = 1
    var quand: Date = Date.now

    init(membre: String, genre: String, onglet: String, detail: String) {
        self.membre = membre; self.genre = genre; self.onglet = onglet; self.detail = detail
    }

    /// La phrase affichée et envoyée en notification (sans le prénom).
    var phrase: String {
        let n = nombre, s = n > 1 ? "s" : ""
        switch genre {
        case "range.frais": return n > 1 ? "a rangé \(n) articles au frais" : "a rangé \(detail) au frais"
        case "range.surgelateur": return n > 1 ? "a mis \(n) articles au surgélateur" : "a mis \(detail) au surgélateur"
        case "range.armoire": return n > 1 ? "a rangé \(n) articles dans les armoires" : "a rangé \(detail) dans les armoires"
        case "mange": return n > 1 ? "a mangé \(n) articles du stock" : "a mangé \(detail)"
        case "jete": return n > 1 ? "a jeté \(n) articles" : "a jeté \(detail)"
        case "mot": return "a laissé un mot : « \(detail) »"
        case "evenement": return n > 1 ? "a ajouté \(n) dates au calendrier" : "a ajouté « \(detail) » au calendrier"
        case "voyage": return "propose un voyage : \(detail)"
        case "etape": return n > 1 ? "a ajouté \(n) étapes au programme d'un voyage" : "a ajouté « \(detail) » au programme du voyage"
        case "weekend": return "propose un week-end : \(detail)"
        case "photo": return n > 1 ? "a ajouté \(n) photos au mur" : "a ajouté une photo au mur"
        case "recette": return "a ajouté la recette « \(detail) »"
        case "sortie": return "était au restaurant « \(detail) »"
        case "hotel": return "a noté l'hôtel « \(detail) »"
        case "reaction": return n > 1 ? "a réagi à \(n) idée\(s)" : "a réagi à « \(detail) »"
        default: return detail
        }
    }

    var icone: String {
        switch genre {
        case "range.frais", "range.armoire": "cabinet"
        case "range.surgelateur": "snowflake"
        case "mange": "checkmark.circle"
        case "jete": "trash"
        case "mot": "note.text"
        case "evenement": "calendar.badge.plus"
        case "voyage": "airplane"
        case "etape": "mappin.and.ellipse"
        case "weekend": "sun.max"
        case "photo": "photo"
        case "recette": "frying.pan"
        case "sortie": "fork.knife"
        case "hotel": "bed.double"
        default: "heart"
        }
    }
}

extension Activite: AvecCle {}

extension Activite: Synchronisable {
    static let typeEnregistrement = "Activite"
    var idSynchro: String { cle }
    var aPartager: Bool { true }
    func remplir(_ r: CKRecord) {
        r["membre"] = membre; r["genre"] = genre; r["onglet"] = onglet; r["detail"] = detail
        r["nombre"] = nombre; r["quand"] = quand
    }
    func lire(_ r: CKRecord) {
        membre = r.s("membre"); genre = r.s("genre"); onglet = r.s("onglet"); detail = r.s("detail")
        nombre = r.entier("nombre") ?? 1; quand = r.date("quand")
    }
}

enum Journal {
    /// Regarde ce que la personne est en train d'enregistrer et en tire les lignes du fil.
    /// Appelé par `enregistrer()` juste avant la sauvegarde.
    static func noter(dans ctx: ModelContext) {
        guard let moi = Base.moi else { return }
        var gestes: [(genre: String, onglet: String, detail: String)] = []
        for m in ctx.insertedModelsArray {
            switch m {
            case let a as Article: gestes.append(("range." + a.rangement, "cuisine", a.nom))
            case let b as Boni: gestes.append(("mange", "cuisine", b.nom))
            case let e as Evenement: gestes.append(("evenement", "calendrier", e.titre))
            case let i as Idee:
                switch i.genre {
                case "mot": gestes.append(("mot", "accueil", i.titre))
                case "voyage": gestes.append(("voyage", "voyages", i.titre))
                default: gestes.append(("weekend", "weekends", i.titre))
                }
            case let e as Etape: gestes.append(("etape", "voyages", e.titre))
            case is Photo: gestes.append(("photo", "accueil", ""))
            case let r as Recette: gestes.append(("recette", "cuisine", r.titre))
            case let s as Sortie: gestes.append(("sortie", "loisirs", s.nom))
            case let h as Hotel: gestes.append(("hotel", "loisirs", h.nom))
            case let d as DocumentBrut where d.collection == "waste":
                gestes.append(("jete", "cuisine", (d.valeurs["name"] as? String) ?? ""))
            default: break
            }
        }
        // « Mangé » retire l'article et crée un boni : c'est le boni qui compte comme « a mangé ».
        guard !gestes.isEmpty else { return }

        let depuis = Date.now.addingTimeInterval(-10 * 60)
        let recentes = (try? ctx.fetch(FetchDescriptor<Activite>(
            predicate: #Predicate { $0.membre == moi && $0.quand > depuis }))) ?? []
        for (genre, groupe) in Dictionary(grouping: gestes, by: \.genre) {
            let dernier = groupe.last!
            // Les mots et les idées ont chacun leur ligne ; le reste se regroupe.
            if !["mot", "voyage", "weekend", "recette"].contains(genre),
               let ligne = recentes.first(where: { $0.genre == genre }) {
                ligne.nombre += groupe.count; ligne.detail = dernier.detail; ligne.quand = .now
            } else {
                let a = Activite(membre: moi, genre: genre, onglet: dernier.onglet, detail: dernier.detail)
                a.nombre = groupe.count
                ctx.insert(a)
            }
        }
    }
}

/// Qui est là : chaque appareil note régulièrement son membre et l'onglet ouvert.
enum Presence {
    /// Une présence plus vieille que ça ne compte plus comme « en ce moment ».
    static let duree: TimeInterval = 3 * 60

    static func estLa(_ v: Visite) -> Bool { Date.now.timeIntervalSince(v.quand) < duree }

    static func libelle(_ onglet: String) -> String {
        switch onglet {
        case "calendrier": "regarde le calendrier"
        case "voyages": "regarde les voyages"
        case "cuisine": "est dans la cuisine"
        case "weekends": "regarde les week-ends"
        case "loisirs": "regarde les loisirs"
        case "chez-nous": "est dans Chez nous"
        default: "est sur l'accueil"
        }
    }

    /// Met à jour la présence de cet appareil (au plus une fois par minute, sauf changement d'onglet).
    static func signaler(onglet: String, dans ctx: ModelContext) {
        guard let moi = Base.moi else { return }
        let v = (try? ctx.fetch(FetchDescriptor<Visite>(predicate: #Predicate { $0.membre == moi })))?.first
            ?? { let n = Visite(membre: moi); ctx.insert(n); return n }()
        guard v.ecran != onglet || Date.now.timeIntervalSince(v.quand) > 60 else { return }
        v.ecran = onglet; v.quand = .now
        ctx.enregistrer()
    }
}

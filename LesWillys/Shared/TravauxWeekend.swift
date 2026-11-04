import Foundation
import SwiftData

/// Une chose à faire à la maison pendant le week-end : une tâche simple (heures données)
/// ou une peinture (heures calculées d'après la surface). Reste sur l'appareil : c'est un carnet personnel.
@Model final class TacheMaison {
    var cle: String = UUID().uuidString
    var titre: String = ""
    var genre: String = "tache"          // "tache" ou "peinture"
    var heures: Double = 1               // temps de travail effectif, séchage non compris
    var surface: Double = 0              // peinture : murs, en m²
    var surfacePlafond: Double = 0       // peinture : plafond, en m²
    var couches: Int = 2
    var sousCouche: Bool = false
    var ordre: Int = 0
    var fait: Bool = false
    var cree: Date = Date.now

    init(titre: String, heures: Double, ordre: Int) {
        self.titre = titre; self.heures = heures; self.ordre = ordre
    }

    init(peinture titre: String, surface: Double, surfacePlafond: Double, couches: Int, sousCouche: Bool, ordre: Int) {
        self.titre = titre; self.genre = "peinture"
        self.surface = surface; self.surfacePlafond = surfacePlafond
        self.couches = couches; self.sousCouche = sousCouche; self.ordre = ordre
        self.heures = Peinture.estimer(surface: surface, plafond: surfacePlafond, couches: couches, sousCouche: sousCouche).travail
    }

    var estPeinture: Bool { genre == "peinture" }
}

/// Combien de temps faut-il pour peindre ? Des repères de bricoleur, pas de professionnel :
/// protéger et reboucher, passer les couches au rouleau (avec les bords au pinceau), tout nettoyer.
enum Peinture {
    static let heuresParM2Mur = 0.13        // ≈ 7,5 m² par heure et par couche, bords compris
    static let heuresParM2Plafond = 0.20    // plus fatigant, on travaille bras levés
    static let preparationParM2 = 0.10      // bâches, adhésif, rebouchage, ponçage léger
    static let preparationFixe = 0.5        // sortir le matériel, ouvrir les pots
    static let nettoyage = 0.5              // rincer rouleaux et pinceaux, ranger, enlever l'adhésif
    static let sechageEntreCouches = 4.0    // heures d'attente, pendant lesquelles on fait autre chose
    static let metresCarresParLitre = 10.0

    struct Estimation {
        var preparation: Double
        var application: Double
        var nettoyage: Double
        var attente: Double          // séchage entre deux couches : du temps où l'on peut faire autre chose
        var litres: Double
        var couchesTotales: Int
        /// Le temps de travail effectif, arrondi à la demi-heure supérieure.
        var travail: Double { ((preparation + application + nettoyage) * 2).rounded(.up) / 2 }
    }

    static func estimer(surface: Double, plafond: Double, couches: Int, sousCouche: Bool) -> Estimation {
        let murs = max(0, surface), toit = max(0, plafond)
        let n = max(1, couches) + (sousCouche ? 1 : 0)
        let prep = (murs + toit) > 0 ? preparationFixe + preparationParM2 * (murs + toit) : 0
        let appli = Double(n) * (heuresParM2Mur * murs + heuresParM2Plafond * toit)
        let nettoyer = (murs + toit) > 0 ? nettoyage : 0
        let litres = ((murs + toit) * Double(n) / metresCarresParLitre * 2).rounded(.up) / 2
        return Estimation(preparation: prep, application: appli, nettoyage: nettoyer,
                          attente: Double(max(0, n - 1)) * sechageEntreCouches, litres: litres, couchesTotales: n)
    }
}

/// Un créneau de travail : le samedi (8 h) ou le dimanche (4 h).
struct Creneau: Identifiable, Equatable {
    var id: Int
    var date: Date
    var capacite: Double
    var estSamedi: Bool { Calendar.current.component(.weekday, from: date) == 7 }
    var nom: String { estSamedi ? "Samedi" : "Dimanche" }
}

/// Le morceau d'une tâche qui tombe dans un créneau.
struct Morceau: Identifiable, Equatable {
    var id: String { "\(creneau)-\(tache)" }
    var tache: String      // cle de la tâche
    var creneau: Int
    var heures: Double
}

struct Plan {
    var creneaux: [Creneau]
    var morceaux: [Morceau]
    /// Le créneau où chaque tâche se termine (par cle). Absent si la tâche est déjà faite.
    var fin: [String: Creneau]

    func utilise(_ c: Creneau) -> Double { morceaux.filter { $0.creneau == c.id }.reduce(0) { $0 + $1.heures } }
    func reste(_ c: Creneau) -> Double { max(0, c.capacite - utilise(c)) }
    func morceaux(de cle: String) -> [Morceau] { morceaux.filter { $0.tache == cle } }
}

enum PlanWeekend {
    static let heuresSamedi = 8.0
    static let heuresDimanche = 4.0

    /// Les créneaux des `semaines` prochains week-ends, à partir d'aujourd'hui (le samedi passé n'est plus compté).
    static func creneaux(depuis: Date = .now, semaines: Int = 26) -> [Creneau] {
        let cal = Calendar.current
        let debut = cal.startOfDay(for: depuis)
        var out: [Creneau] = []
        for i in 0..<(semaines * 7) {
            guard let d = cal.date(byAdding: .day, value: i, to: debut) else { continue }
            let w = cal.component(.weekday, from: d)
            if w == 7 { out.append(Creneau(id: out.count, date: d, capacite: heuresSamedi)) }
            else if w == 1 { out.append(Creneau(id: out.count, date: d, capacite: heuresDimanche)) }
        }
        return out
    }

    /// Répartit les tâches dans l'ordre : chacune remplit ce qui reste du créneau, puis déborde sur le suivant.
    static func repartir(_ taches: [TacheMaison], depuis: Date = .now, semaines: Int = 26) -> Plan {
        let cs = creneaux(depuis: depuis, semaines: semaines)
        var reste = cs.map(\.capacite)
        var morceaux: [Morceau] = [], fin: [String: Creneau] = [:]
        var i = 0
        for t in taches.filter({ !$0.fait }).sorted(by: { $0.ordre < $1.ordre }) {
            var besoin = max(0, t.heures)
            if besoin == 0 { continue }
            while besoin > 0.0001 && i < cs.count {
                if reste[i] <= 0.0001 { i += 1; continue }
                let h = min(besoin, reste[i])
                morceaux.append(Morceau(tache: t.cle, creneau: cs[i].id, heures: h))
                reste[i] -= h; besoin -= h
                fin[t.cle] = cs[i]
            }
        }
        return Plan(creneaux: cs, morceaux: morceaux, fin: fin)
    }
}

/// Quelques petites choses qui tiennent dans un trou de la journée.
enum IdeesDeTemps {
    static let liste: [(titre: String, heures: Double)] = [
        ("Tondre la pelouse", 1.5), ("Ranger le garage", 2), ("Désherber et arroser", 1),
        ("Courses de la semaine", 1.5), ("Lessive et repassage", 1.5), ("Cuisiner pour la semaine", 2),
        ("Petites réparations", 1), ("Tri du frigo et des armoires", 0.5), ("Nettoyer les vitres", 1),
    ]
    static func quiTiennent(dans heures: Double) -> [(titre: String, heures: Double)] {
        liste.filter { $0.heures <= heures + 0.0001 }
    }
}

func heuresTexte(_ h: Double) -> String {
    let m = Int((h * 60).rounded())
    let (hh, mm) = (m / 60, m % 60)
    return mm == 0 ? "\(hh) h" : hh == 0 ? "\(mm) min" : "\(hh) h \(mm)"
}

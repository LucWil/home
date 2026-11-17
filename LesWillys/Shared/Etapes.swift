import Foundation
import SwiftData
import SwiftUI
import CloudKit
import CoreLocation

/// Une étape du programme d'un voyage : un lieu, un jour, une heure. Partagée avec toute la famille.
@Model final class Etape {
    var cle: String = UUID().uuidString
    var voyage: String = ""          // la `cle` de l'idée de voyage
    var jour: Int = 1                // jour 1, jour 2…
    var heure: String = ""           // "09:30", ou vide
    var ordre: Int = 0               // l'ordre dans la journée
    var titre: String = ""
    var categorie: String = "visite"
    var adresse: String = ""
    var latitude: Double = 0
    var longitude: Double = 0
    var note: String = ""
    var par: String = ""
    var cree: Date = Date.now

    init(voyage: String, jour: Int, ordre: Int, titre: String, par: String) {
        self.voyage = voyage; self.jour = jour; self.ordre = ordre; self.titre = titre; self.par = par
    }

    var aUnePosition: Bool { !(latitude == 0 && longitude == 0) }
    var coordonnee: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: latitude, longitude: longitude) }
    var type: TypeEtape { TypeEtape(rawValue: categorie) ?? .visite }
}

enum TypeEtape: String, CaseIterable, Identifiable {
    case visite, nature, repas, hebergement, transport, activite
    var id: String { rawValue }
    var libelle: String {
        switch self {
        case .visite: "À voir"
        case .nature: "Nature et balade"
        case .repas: "Repas"
        case .hebergement: "Hôtel"
        case .transport: "Transport"
        case .activite: "Activité"
        }
    }
    var icone: String {
        switch self {
        case .visite: "camera.fill"
        case .nature: "mountain.2.fill"
        case .repas: "fork.knife"
        case .hebergement: "bed.double.fill"
        case .transport: "tram.fill"
        case .activite: "figure.hiking"
        }
    }
    /// Ce qu'on tape dans la recherche de lieux pour ce genre d'étape.
    var recherche: String {
        switch self {
        case .visite: "À voir, sites touristiques"
        case .nature: "Randonnée, point de vue, parc"
        case .repas: "Restaurant"
        case .hebergement: "Hôtel"
        case .transport: "Gare"
        case .activite: "Activités, loisirs"
        }
    }
}

extension Etape: AvecCle {}

extension Etape: Synchronisable {
    static let typeEnregistrement = "Etape"
    var idSynchro: String { cle }
    var aPartager: Bool { true }
    func remplir(_ r: CKRecord) {
        r["voyage"] = voyage; r["jour"] = jour; r["heure"] = heure; r["ordre"] = ordre; r["titre"] = titre
        r["categorie"] = categorie; r["adresse"] = adresse; r["latitude"] = latitude; r["longitude"] = longitude
        r["note"] = note; r["par"] = par; r["cree"] = cree
    }
    func lire(_ r: CKRecord) {
        voyage = r.s("voyage"); jour = r.entier("jour") ?? 1; heure = r.s("heure"); ordre = r.entier("ordre") ?? 0
        titre = r.s("titre"); categorie = r.s("categorie"); adresse = r.s("adresse")
        latitude = r.nombre("latitude"); longitude = r.nombre("longitude")
        note = r.s("note"); par = r.s("par"); cree = r.date("cree")
    }
}

/// Les couleurs des jours sur la carte : un trait et des épingles par jour.
enum CouleursJours {
    static let liste: [Color] = [Color(hex: 0x2F6FB5), Color(hex: 0xC8456B), Color(hex: 0x2C9A8A), Color(hex: 0xE2973A),
                                 Color(hex: 0x8A5CC2), Color(hex: 0x5F8A2E), Color(hex: 0xE07AA0)]
    static func pour(_ jour: Int) -> Color { liste[max(0, jour - 1) % liste.count] }
}

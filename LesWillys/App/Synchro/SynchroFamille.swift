import Foundation
import CloudKit
import SwiftData
import UIKit

/// La maison commune : une zone iCloud « Willys » qui appartient à Chouchou et qu'il partage
/// avec les sept autres membres (partage CloudKit de toute la zone).
///
/// - Sur les appareils de Chouchou, la zone est dans sa base iCloud *privée*.
/// - Pour les autres, elle apparaît dans leur base *partagée* dès qu'ils ont accepté l'invitation
///   (une seule fois par compte Apple : leur iPad la voit aussi).
///
/// La base locale SwiftData reste la source de l'app et des widgets ; CKSyncEngine (iOS 17)
/// envoie les changements notés dans la file d'envoi et rapporte ceux des autres.
@MainActor
final class SynchroFamille: ObservableObject {
    static let partagee = SynchroFamille()

    enum Etat: Equatable {
        case pasDeCompteICloud
        case enAttenteInvitation      // un membre qui n'a pas encore accepté l'invitation
        case pret                     // tout va bien
        case erreur(String)
    }
    @Published private(set) var etat: Etat = .enAttenteInvitation
    @Published private(set) var derniereSynchro: Date?

    static let nomZone = "Willys"
    let conteneur = CKContainer(identifier: Base.iCloud)
    private var moteur: CKSyncEngine?
    private var delegue: Delegue?

    /// Chouchou possède la maison commune ; tous les autres la reçoivent en partage.
    var estProprietaire: Bool { Base.moi == "chouchou" }

    /// Le propriétaire de la zone, tel que CloudKit le nomme (connu une fois l'invitation acceptée).
    private var proprietaireZone: String? {
        get { estProprietaire ? CKCurrentUserDefaultName : Base.reglages.string(forKey: "zone.proprietaire") }
        set { Base.reglages.set(newValue, forKey: "zone.proprietaire") }
    }
    var zoneID: CKRecordZone.ID? {
        proprietaireZone.map { CKRecordZone.ID(zoneName: Self.nomZone, ownerName: $0) }
    }

    // MARK: Démarrage

    func demarrer() async {
        guard moteur == nil, Base.moi != nil else { return }
        guard (try? await conteneur.accountStatus()) == .available else { etat = .pasDeCompteICloud; return }

        let base = estProprietaire ? conteneur.privateCloudDatabase : conteneur.sharedCloudDatabase
        let delegue = Delegue(synchro: self)
        var config = CKSyncEngine.Configuration(database: base, stateSerialization: Self.etatSauve(), delegate: delegue)
        config.automaticallySync = true
        self.delegue = delegue
        let moteur = CKSyncEngine(config)
        self.moteur = moteur

        if estProprietaire, let zoneID {
            moteur.state.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: zoneID))])
        }
        etat = zoneID == nil ? .enAttenteInvitation : .pret
        envoyerFile()
        try? await moteur.fetchChanges()
    }

    /// Prend tout ce qui attend dans la file d'envoi (app et widgets) et le confie à CloudKit.
    func envoyerFile() {
        guard let moteur, let zoneID else { return }
        let changements: [CKSyncEngine.PendingRecordZoneChange] = FileSynchro.vider().compactMap { ligne in
            let morceaux = ligne.split(separator: ":", maxSplits: 1).map(String.init)
            guard morceaux.count == 2 else { return nil }
            let id = CKRecord.ID(recordName: morceaux[1], zoneID: zoneID)
            return morceaux[0] == "delete" ? .deleteRecord(id) : .saveRecord(id)
        }
        if !changements.isEmpty { moteur.state.add(pendingRecordZoneChanges: changements) }
    }

    /// Met tout le contenu local dans la file (après avoir rejoint la maison commune).
    func toutEnvoyer() {
        let ctx = Base.app.mainContext
        var lignes: [String] = []
        func ajouter<T: Synchronisable>(_ t: T.Type) {
            for o in (try? ctx.fetch(FetchDescriptor<T>())) ?? [] where o.aPartager { lignes.append("save:" + o.nomEnregistrement) }
        }
        ajouter(Evenement.self); ajouter(Idee.self); ajouter(Reaction.self); ajouter(Article.self); ajouter(Boni.self)
        ajouter(Foyer.self); ajouter(Recette.self); ajouter(Photo.self); ajouter(Visite.self); ajouter(DocumentBrut.self)
        ajouter(Activite.self)
        ajouter(Restaurant.self); ajouter(Sortie.self); ajouter(Hotel.self); ajouter(PhotoLoisir.self)
        FileSynchro.ajouter(lignes)
        envoyerFile()
    }

    func synchroniserMaintenant() async {
        envoyerFile()
        try? await moteur?.fetchChanges()
        try? await moteur?.sendChanges()
    }

    // MARK: Invitation (côté Chouchou)

    /// Crée (ou retrouve) le partage de la zone et ouvre la fenêtre d'Apple pour inviter la famille
    /// par Messages, WhatsApp ou e-mail.
    func inviterLaFamille() async {
        guard estProprietaire, let zoneID else { return }
        let base = conteneur.privateCloudDatabase
        do {
            _ = try await base.modifyRecordZones(saving: [CKRecordZone(zoneID: zoneID)], deleting: [])
            let idPartage = CKRecord.ID(recordName: CKRecordNameZoneWideShare, zoneID: zoneID)
            let partage: CKShare
            if let existant = try? await base.record(for: idPartage) as? CKShare {
                partage = existant
            } else {
                let nouveau = CKShare(recordZoneID: zoneID)
                nouveau[CKShare.SystemFieldKey.title] = "Les Willys"
                nouveau.publicPermission = .none          // seulement les personnes invitées
                let (resultats, _) = try await base.modifyRecords(saving: [nouveau], deleting: [])
                guard case .success(let r) = resultats[idPartage], let enregistre = r as? CKShare else {
                    throw CKError(.internalError)
                }
                partage = enregistre
            }
            let fenetre = UICloudSharingController(share: partage, container: conteneur)
            fenetre.availablePermissions = [.allowPrivate, .allowReadWrite]
            Self.presenter(fenetre)
        } catch {
            etat = .erreur("Invitation impossible : \(error.localizedDescription)")
        }
    }

    // MARK: Invitation (côté famille)

    /// Appelé quand quelqu'un touche le lien d'invitation reçu de Chouchou.
    func accepter(_ invitation: CKShare.Metadata) async {
        do {
            _ = try await conteneur.accept(invitation)
            proprietaireZone = invitation.share.recordID.zoneID.ownerName
            etat = .pret
            toutEnvoyer()
            try? await moteur?.fetchChanges()
            if moteur == nil { await demarrer() }
        } catch {
            etat = .erreur("L'invitation n'a pas pu être acceptée : \(error.localizedDescription)")
        }
    }

    // MARK: Appliquer ce qui arrive d'iCloud

    fileprivate func appliquer(modifies: [CKRecord], supprimes: [CKRecord.ID]) {
        let ctx = Base.app.mainContext
        var nouvelles: [CKRecord] = []
        for r in modifies {
            if r.recordType == Activite.typeEnregistrement { nouvelles.append(r) }
            if !estProprietaire, proprietaireZone == nil, r.recordID.zoneID.zoneName == Self.nomZone {
                proprietaireZone = r.recordID.zoneID.ownerName; etat = .pret
            }
            CacheSysteme.garder(r)
            guard let (type, id) = Self.decouper(r.recordID.recordName) else { continue }
            (Self.trouver(type, id, ctx) ?? Self.creer(type, id, ctx))?.lire(r)
        }
        for id in supprimes {
            CacheSysteme.oublier(id.recordName)
            guard let (type, cle) = Self.decouper(id.recordName), let o = Self.trouver(type, cle, ctx) else { continue }
            ctx.delete(o)
        }
        try? ctx.save()             // pas `enregistrer()` : on ne renvoie pas ce qui vient d'arriver
        derniereSynchro = .now
        Alertes.annoncer(nouvelles)
        Base.rafraichirWidgets()
    }

    fileprivate func zoneVue(_ zoneID: CKRecordZone.ID) {
        guard !estProprietaire, zoneID.zoneName == Self.nomZone, proprietaireZone == nil else { return }
        proprietaireZone = zoneID.ownerName
        etat = .pret
        toutEnvoyer()
    }

    fileprivate func zonePerdue(_ zoneID: CKRecordZone.ID) {
        guard !estProprietaire, zoneID.zoneName == Self.nomZone else { return }
        proprietaireZone = nil
        etat = .enAttenteInvitation
    }

    /// Construit l'enregistrement à envoyer pour un objet local.
    fileprivate func enregistrement(pour id: CKRecord.ID) -> CKRecord? {
        guard let (type, cle) = Self.decouper(id.recordName),
              let o = Self.trouver(type, cle, Base.app.mainContext), o.aPartager else { return nil }
        let r = CacheSysteme.enregistrement(id, type: type)
        o.remplir(r)
        return r
    }

    /// Conflit : quelqu'un a modifié la même chose en même temps. On repart de la version d'iCloud,
    /// on y remet nos valeurs (la dernière personne à avoir touché gagne) et on renvoie.
    fileprivate func conflit(serveur: CKRecord) {
        CacheSysteme.garder(serveur)
        moteur?.state.add(pendingRecordZoneChanges: [.saveRecord(serveur.recordID)])
    }

    fileprivate func sauverEtat(_ s: CKSyncEngine.State.Serialization) {
        if let d = try? JSONEncoder().encode(s) { try? d.write(to: Self.fichier("etat-synchro.json")) }
        derniereSynchro = .now
    }

    // MARK: Outils

    private static func decouper(_ nom: String) -> (String, String)? {
        let m = nom.split(separator: "/", maxSplits: 1).map(String.init)
        return m.count == 2 ? (m[0], m[1]) : nil
    }

    private static func trouver(_ type: String, _ id: String, _ ctx: ModelContext) -> (any Synchronisable)? {
        func chercher<T: Synchronisable>(_ t: T.Type) -> T? {
            ((try? ctx.fetch(FetchDescriptor<T>())) ?? []).first { $0.idSynchro == id }
        }
        switch type {
        case Evenement.typeEnregistrement: return chercher(Evenement.self)
        case Idee.typeEnregistrement: return chercher(Idee.self)
        case Reaction.typeEnregistrement: return chercher(Reaction.self)
        case Article.typeEnregistrement: return chercher(Article.self)
        case Boni.typeEnregistrement: return chercher(Boni.self)
        case Foyer.typeEnregistrement: return chercher(Foyer.self)
        case Recette.typeEnregistrement: return chercher(Recette.self)
        case Photo.typeEnregistrement: return chercher(Photo.self)
        case Visite.typeEnregistrement: return chercher(Visite.self)
        case DocumentBrut.typeEnregistrement: return chercher(DocumentBrut.self)
        case Activite.typeEnregistrement: return chercher(Activite.self)
        case Restaurant.typeEnregistrement: return chercher(Restaurant.self)
        case Sortie.typeEnregistrement: return chercher(Sortie.self)
        case Hotel.typeEnregistrement: return chercher(Hotel.self)
        case PhotoLoisir.typeEnregistrement: return chercher(PhotoLoisir.self)
        default: return nil
        }
    }

    private static func creer(_ type: String, _ id: String, _ ctx: ModelContext) -> (any Synchronisable)? {
        let o: (any Synchronisable)?
        switch type {
        case Evenement.typeEnregistrement:
            let e = Evenement(type: "ensemble", titre: "", debut: Jour.aujourdhui, fin: Jour.aujourdhui, personnes: [], par: ""); e.cle = id; o = e
        case Idee.typeEnregistrement: let i = Idee(genre: "mot", titre: "", par: ""); i.cle = id; o = i
        case Reaction.typeEnregistrement: let r = Reaction(element: "", membre: "", reaction: ""); r.cle = id; o = r
        case Article.typeEnregistrement: let a = Article(foyer: "", rangement: .frais, nom: "", categorie: "autre", par: ""); a.cle = id; o = a
        case Boni.typeEnregistrement: let b = Boni(foyer: "", nom: "", valeur: 0, par: ""); b.cle = id; o = b
        case Foyer.typeEnregistrement: o = Foyer(cle: id, nom: Famille.nomFoyer(id))
        case Recette.typeEnregistrement: let r = Recette(titre: "", par: ""); r.cle = id; o = r
        case Photo.typeEnregistrement: let p = Photo(legende: "", qui: [], par: ""); p.cle = id; o = p
        case Visite.typeEnregistrement: o = Visite(membre: id)
        case Activite.typeEnregistrement: let a = Activite(membre: "", genre: "", onglet: "accueil", detail: ""); a.cle = id; o = a
        case Restaurant.typeEnregistrement: let r = Restaurant(nom: "", ville: "", par: ""); r.cle = id; o = r
        case Sortie.typeEnregistrement: let s = Sortie(ref: "", nom: "", lieu: "", foyer: "", par: ""); s.cle = id; o = s
        case Hotel.typeEnregistrement: let h = Hotel(nom: "", ville: "", foyer: "", par: ""); h.cle = id; o = h
        case PhotoLoisir.typeEnregistrement: let p = PhotoLoisir(parent: "", quoi: "", image: nil, par: ""); p.cle = id; o = p
        case DocumentBrut.typeEnregistrement:
            let m = id.split(separator: ":", maxSplits: 1).map(String.init)
            o = DocumentBrut(collection: m.first ?? "", cle: m.count > 1 ? m[1] : id, json: Data(), foyer: "")
        default: o = nil
        }
        if let o { ctx.insert(o) }
        return o
    }

    static func fichier(_ nom: String) -> URL {
        let dossier = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Base.groupe)
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return dossier.appendingPathComponent(nom)
    }

    private static func etatSauve() -> CKSyncEngine.State.Serialization? {
        (try? Data(contentsOf: fichier("etat-synchro.json"))).flatMap { try? JSONDecoder().decode(CKSyncEngine.State.Serialization.self, from: $0) }
    }

    private static func presenter(_ vc: UIViewController) {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        var haut = scene?.keyWindow?.rootViewController
        while let suivant = haut?.presentedViewController { haut = suivant }
        haut?.present(vc, animated: true)
    }
}

/// Le délégué de CKSyncEngine (appelé hors du fil principal) : il renvoie tout vers `SynchroFamille`.
private final class Delegue: CKSyncEngineDelegate, @unchecked Sendable {
    weak var synchro: SynchroFamille?
    init(synchro: SynchroFamille) { self.synchro = synchro }

    func handleEvent(_ evenement: CKSyncEngine.Event, syncEngine: CKSyncEngine) async {
        switch evenement {
        case .stateUpdate(let e):
            await synchro?.sauverEtat(e.stateSerialization)

        case .fetchedDatabaseChanges(let e):
            for m in e.modifications { await synchro?.zoneVue(m.zoneID) }
            for d in e.deletions { await synchro?.zonePerdue(d.zoneID) }

        case .fetchedRecordZoneChanges(let e):
            let modifies = e.modifications.map(\.record)
            let supprimes = e.deletions.map(\.recordID)
            await synchro?.appliquer(modifies: modifies, supprimes: supprimes)

        case .sentRecordZoneChanges(let e):
            for r in e.savedRecords { CacheSysteme.garder(r) }
            for echec in e.failedRecordSaves {
                switch echec.error.code {
                case .serverRecordChanged:
                    if let serveur = echec.error.serverRecord { await synchro?.conflit(serveur: serveur) }
                case .zoneNotFound:
                    syncEngine.state.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: echec.record.recordID.zoneID))])
                    syncEngine.state.add(pendingRecordZoneChanges: [.saveRecord(echec.record.recordID)])
                case .unknownItem:
                    CacheSysteme.oublier(echec.record.recordID.recordName)
                    syncEngine.state.add(pendingRecordZoneChanges: [.saveRecord(echec.record.recordID)])
                default:
                    break   // réseau, quota… CKSyncEngine réessaiera de lui-même
                }
            }

        case .accountChange:
            break

        default:
            break
        }
    }

    func nextRecordZoneChangeBatch(_ contexte: CKSyncEngine.SendChangesContext, syncEngine: CKSyncEngine) async -> CKSyncEngine.RecordZoneChangeBatch? {
        let enAttente = syncEngine.state.pendingRecordZoneChanges.filter { contexte.options.scope.contains($0) }
        return await CKSyncEngine.RecordZoneChangeBatch(pendingChanges: enAttente) { [weak self] id in
            let r = await self?.synchro?.enregistrement(pour: id)
            if r == nil { syncEngine.state.remove(pendingRecordZoneChanges: [.saveRecord(id)]) }
            return r
        }
    }
}

/// Garde les « champs système » de chaque enregistrement (son numéro de version côté iCloud),
/// pour que les mises à jour soient acceptées sans conflit.
enum CacheSysteme {
    private static let verrou = NSLock()
    private static var memoire: [String: Data] = {
        (try? Data(contentsOf: SynchroFamille.fichier("champs-systeme.plist")))
            .flatMap { try? PropertyListDecoder().decode([String: Data].self, from: $0) } ?? [:]
    }()

    static func garder(_ r: CKRecord) {
        let archive = NSKeyedArchiver(requiringSecureCoding: true)
        r.encodeSystemFields(with: archive)
        verrou.lock(); memoire[r.recordID.recordName] = archive.encodedData; ecrire(); verrou.unlock()
    }

    static func oublier(_ nom: String) {
        verrou.lock(); memoire[nom] = nil; ecrire(); verrou.unlock()
    }

    static func enregistrement(_ id: CKRecord.ID, type: String) -> CKRecord {
        verrou.lock(); let d = memoire[id.recordName]; verrou.unlock()
        if let d, let lecteur = try? NSKeyedUnarchiver(forReadingFrom: d) {
            lecteur.requiresSecureCoding = true
            if let r = CKRecord(coder: lecteur), r.recordID == id { return r }
        }
        return CKRecord(recordType: type, recordID: id)
    }

    private static func ecrire() {
        if let d = try? PropertyListEncoder().encode(memoire) { try? d.write(to: SynchroFamille.fichier("champs-systeme.plist")) }
    }
}

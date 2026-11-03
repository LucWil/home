import Foundation
import SwiftData
import AppIntents
import WidgetKit

/// La base locale partagée entre l'app et les widgets (même « App Group »).
/// L'app la synchronise avec iCloud ; les widgets la lisent seulement.
enum Base {
    static let groupe = "group.be.willys.app"
    static let iCloud = "iCloud.be.willys.app"
    static let reglages = UserDefaults(suiteName: groupe) ?? .standard

    /// Qui utilise cet appareil (choisi une fois sur l'écran des aimants).
    static var moi: String? {
        get { reglages.string(forKey: "moi") }
        set { reglages.set(newValue, forKey: "moi") }
    }
    static var monFoyer: String? { Famille.foyer(de: moi) }

    static func conteneur(synchro: Bool) -> ModelContainer {
        let schema = Schema(Schema_.modeles)
        let config = ModelConfiguration(
            "LesWillys",
            schema: schema,
            groupContainer: .identifier(groupe),
            cloudKitDatabase: synchro ? .private(iCloud) : .none
        )
        do { return try ModelContainer(for: schema, configurations: [config]) }
        catch {
            // Si iCloud n'est pas disponible (simulateur sans compte, par ex.), on reste en local.
            let local = ModelConfiguration("LesWillys", schema: schema, groupContainer: .identifier(groupe), cloudKitDatabase: .none)
            return try! ModelContainer(for: schema, configurations: [local])
        }
    }

    @MainActor static let app = conteneur(synchro: true)

    /// Après chaque changement, on prévient les widgets.
    static func rafraichirWidgets() { WidgetCenter.shared.reloadAllTimelines() }
}

/// Règle du boni : un article mangé quitte le stock et son prix part dans le boni du foyer.
enum Cuisine {
    static func manger(_ article: Article, par membre: String, dans ctx: ModelContext) {
        if article.prix > 0 {
            ctx.insert(Boni(foyer: article.foyer, nom: article.nom, valeur: article.prix, par: membre))
        }
        ctx.delete(article)
        try? ctx.save()
    }

    /// Les articles du foyer qui arrivent à date, le plus urgent d'abord.
    static func aManger(foyer: String, dans ctx: ModelContext, limite: Int = 5) -> [Article] {
        let f = FetchDescriptor<Article>(predicate: #Predicate { $0.foyer == foyer })
        let tous = (try? ctx.fetch(f)) ?? []
        return tous
            .compactMap { a -> (Article, Int)? in
                guard let j = a.joursRestants else { return nil }
                let seuil = a.rangement == "armoire" ? 14 : 2
                return j <= seuil ? (a, j) : nil
            }
            .sorted { $0.1 < $1.1 }
            .prefix(limite)
            .map { $0.0 }
    }
}

/// Bouton « Mangé » utilisable depuis le widget sans ouvrir l'app (iOS 17).
struct MangerIntent: AppIntent {
    static var title: LocalizedStringResource = "C'est mangé"
    static var description = IntentDescription("Retire l'article du stock et ajoute son prix au boni du foyer.")

    @Parameter(title: "Article") var cle: String

    init() {}
    init(cle: String) { self.cle = cle }

    @MainActor func perform() async throws -> some IntentResult {
        let ctx = ModelContext(Base.conteneur(synchro: false))
        let c = cle
        if let a = try ctx.fetch(FetchDescriptor<Article>(predicate: #Predicate { $0.cle == c })).first {
            Cuisine.manger(a, par: Base.moi ?? "", dans: ctx)
        }
        Base.rafraichirWidgets()
        return .result()
    }
}

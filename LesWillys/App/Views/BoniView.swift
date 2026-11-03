import SwiftUI
import SwiftData

/// Budget & boni : ce que le foyer a gagné en mangeant son stock au lieu de racheter,
/// et l'objectif de l'année (ex. la semaine de vacances).
struct BoniView: View {
    let moi: String
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var fermer
    @Query(sort: \Boni.cree, order: .reverse) private var tous: [Boni]
    @Query private var foyers: [Foyer]
    @State private var objectif = false

    private var foyer: String { Famille.foyer(de: moi) ?? "" }
    private var boni: [Boni] { tous.filter { $0.foyer == foyer } }
    private var total: Double { boni.reduce(0) { $0 + $1.valeur } }
    private var trimestre: Double {
        let c = Calendar.current, debut = c.date(from: DateComponents(year: c.component(.year, from: .now),
                                                                      month: ((c.component(.month, from: .now) - 1) / 3) * 3 + 1, day: 1))!
        return boni.filter { $0.cree >= debut }.reduce(0) { $0 + $1.valeur }
    }
    private var fiche: Foyer? { foyers.first { $0.cle == foyer } }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Text(fiche?.objectifLibelle.isEmpty == false ? "Le boni paie \(fiche!.objectifLibelle)" : "Gagné pour les vacances")
                        .font(.caption.weight(.semibold)).textCase(.uppercase)
                    Text(total.euros).font(.system(size: 52, weight: .heavy, design: .rounded)).monospacedDigit()
                    if let cible = fiche?.objectifMontant, cible > 0 {
                        ProgressView(value: min(total, cible), total: cible).tint(Theme.ok)
                        Text("sur \(cible.euros) · \(Int(min(100, total / cible * 100))) %").foregroundStyle(.secondary)
                    }
                    Text("Ce trimestre : \(trimestre.euros)").font(.subheadline.bold())
                    Text("Chaque produit du stock mangé au lieu d'être racheté vient grossir ce compteur.")
                        .font(.footnote).foregroundStyle(.secondary)
                    Button(fiche?.objectifMontant ?? 0 > 0 ? "Changer l'objectif" : "Donner un but au boni") { objectif = true }
                        .buttonStyle(.bordered)
                }
                .padding(.vertical, 8)
            }
            Section("Les derniers articles écoulés") {
                if boni.isEmpty { Text("Touche « Mangé » sur un article du stock pour commencer.").foregroundStyle(.secondary) }
                ForEach(boni.prefix(50)) { b in
                    HStack {
                        Aimant(membre: b.par, taille: 22)
                        Text(b.nom)
                        Spacer()
                        Text(b.valeur.euros).monospacedDigit().foregroundStyle(Theme.ok)
                    }
                }
            }
        }
        .navigationTitle("Budget & boni · \(Famille.nomFoyer(foyer))")
        .toolbar { Button("OK") { fermer() } }
        .sheet(isPresented: $objectif) { NavigationStack { FormulaireObjectif(foyer: foyer, fiche: fiche) } }
    }
}

struct FormulaireObjectif: View {
    let foyer: String
    let fiche: Foyer?
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var fermer
    @State private var libelle = ""
    @State private var montant = ""

    var body: some View {
        Form {
            TextField("L'objectif — ex. un dîner au restaurant tous les deux", text: $libelle)
            TextField("Montant (€)", text: $montant).keyboardType(.decimalPad)
        }
        .navigationTitle("L'objectif de l'année")
        .onAppear { libelle = fiche?.objectifLibelle ?? ""; montant = fiche.map { $0.objectifMontant > 0 ? String(Int($0.objectifMontant)) : "" } ?? "" }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Annuler") { fermer() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Enregistrer") {
                    let f = fiche ?? { let n = Foyer(cle: foyer, nom: Famille.nomFoyer(foyer)); ctx.insert(n); return n }()
                    f.objectifLibelle = libelle
                    f.objectifMontant = Double(montant.replacingOccurrences(of: ",", with: ".")) ?? 0
                    ctx.enregistrer(); Base.rafraichirWidgets(); fermer()
                }
            }
        }
    }
}

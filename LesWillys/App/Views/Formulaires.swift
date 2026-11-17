import SwiftUI
import SwiftData
import PhotosUI

/// Choisir des membres en touchant leurs aimants.
struct ChoixAimants: View {
    let membres: [Membre]
    @Binding var choisis: [String]
    var unSeul = false

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(membres) { m in
                    let pris = choisis.contains(m.id)
                    Button {
                        Retour.aimant()
                        if unSeul { choisis = pris ? [] : [m.id] }
                        else if pris { choisis.removeAll { $0 == m.id } } else { choisis.append(m.id) }
                    } label: {
                        VStack(spacing: 4) {
                            Aimant(membre: m.id, taille: 44)
                                .padding(3).overlay(Circle().stroke(pris ? Theme.accent : .clear, lineWidth: 3))
                                .overlay(alignment: .bottomTrailing) {
                                    if pris { Image(systemName: "checkmark.circle.fill").foregroundStyle(.white, Theme.accent).transition(.scale) }
                                }
                            Text(m.nom).font(.willys(.caption2, poids: pris ? .bold : nil))
                        }
                        .animation(Anim.rebond, value: pris)
                    }
                    .buttonStyle(StyleAimant())
                    .accessibilityLabel(m.nom)
                    .accessibilityAddTraits(pris ? .isSelected : [])
                }
            }
        }
    }
}

struct FormulaireMot: View {
    let moi: String
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var fermer
    @State private var texte = ""

    var body: some View {
        Form {
            Section("Ton mot") {
                TextField("Qui vient dimanche ?", text: $texte, axis: .vertical)
                    .font(Theme.main(24)).lineLimit(3...6)
                    .onChange(of: texte) { _, v in if v.count > 160 { texte = String(v.prefix(160)) } }
            }
        }
        .navigationTitle("Laisser un mot")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Annuler") { fermer() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Laisser le mot") {
                    Retour.succes()
                    avecAnimation { ctx.insert(Idee(genre: "mot", titre: texte.trimmingCharacters(in: .whitespacesAndNewlines), par: moi)) }
                    ctx.enregistrer(); Base.rafraichirWidgets(); fermer()
                }.disabled(texte.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }
}

struct FormulaireEvenement: View {
    let moi: String
    var jour: String = Jour.aujourdhui
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var fermer
    @State private var type: TypeEvenement = .ensemble
    @State private var titre = ""
    @State private var debut = Date.now
    @State private var fin = Date.now
    @State private var personnes: [String] = []
    @State private var enfant: [String] = []
    @State private var gardeChez = "manhattan"

    var body: some View {
        Form {
            Picker("Type", selection: $type) { ForEach(TypeEvenement.allCases) { Text($0.libelle).tag($0) } }
            TextField(type == .frejus ? "Ex. Manhattan et Julien à Fréjus" : "Ex. Amalia chez Grany", text: $titre)
            DatePicker("Du", selection: $debut, displayedComponents: .date)
            DatePicker("Au", selection: $fin, in: debut..., displayedComponents: .date)
            if type == .garde {
                Section("Quelle petite ?") { ChoixAimants(membres: Famille.enfants, choisis: $enfant, unSeul: true) }
                Picker("Garde chez", selection: $gardeChez) { ForEach(Famille.adultes) { Text($0.nom).tag($0.id) } }
            }
            Section("Qui ?") { ChoixAimants(membres: Famille.adultes, choisis: $personnes) }
        }
        .environment(\.locale, Locale(identifier: "fr_BE"))
        .navigationTitle("Ajouter une date")
        .onAppear { debut = Jour.date(jour); fin = debut }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Annuler") { fermer() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Ajouter") {
                    let qui = type == .garde ? enfant + personnes.filter { !enfant.contains($0) } : personnes
                    ctx.insert(Evenement(type: type.rawValue, titre: titre, debut: Jour.chaine(debut), fin: Jour.chaine(max(fin, debut)),
                                         personnes: qui, gardeChez: type == .garde ? gardeChez : nil, par: moi))
                    Retour.succes(); ctx.enregistrer(); Base.rafraichirWidgets(); fermer()
                }.disabled(titre.isEmpty)
            }
        }
    }
}

struct FormulaireIdee: View {
    let genre: String
    let moi: String
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var fermer
    @State private var titre = ""
    @State private var quand = ""
    @State private var prix = ""
    @State private var lien = ""
    @State private var photo = ""
    @State private var note = ""
    var body: some View {
        let voyage = genre == "voyage"
        Form {
            TextField(voyage ? "Destination — ex. Crète, hôtel avec piscine" : "L'idée — ex. Barbecue au ponton", text: $titre)
            TextField(voyage ? "Quand ? — ex. vacances de Pâques" : "Quand ? — ex. samedi 14 novembre", text: $quand)
            if voyage { TextField("Prix par personne (€)", text: $prix).keyboardType(.numberPad) }
            TextField("Lien (Sunweb, Booking…)", text: $lien).keyboardType(.URL).textInputAutocapitalization(.never)
            TextField("Photo (lien vers une image)", text: $photo).keyboardType(.URL).textInputAutocapitalization(.never)
            Section("Un mot") { TextField("Pourquoi ça vous plairait…", text: $note, axis: .vertical).lineLimit(3...8) }
        }
        .navigationTitle(voyage ? "Proposer un voyage" : "Proposer un week-end")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Annuler") { fermer() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Proposer") {
                    let i = Idee(genre: genre, titre: titre, par: moi)
                    i.quand = quand; i.prix = prix; i.note = note
                    i.lien = lien.hasPrefix("https://") ? lien : ""; i.photo = photo.hasPrefix("https://") ? photo : ""
                    Retour.succes(); ctx.insert(i); ctx.enregistrer(); Base.rafraichirWidgets(); fermer()
                }.disabled(titre.isEmpty)
            }
        }
    }
}

struct FormulaireArticle: View {
    let moi: String
    let foyer: String
    var rangement: Rangement = .frais
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var fermer
    @State private var nom = ""
    @State private var quantite = ""
    @State private var categorie = "legumes"
    @State private var prix = ""
    @State private var bonJours = ""
    @State private var depuis = Date.now
    @State private var peremption = Date.now.addingTimeInterval(30 * 86400)
    @State private var avecPeremption = false
    @State private var ou: Rangement = .frais

    /// Pour les armoires on propose conserves, épicerie, boissons… ; pour le frais, légumes, crèmerie…
    private var categoriesProposees: [String] { Categorie.attendues(dans: ou.rawValue) }

    var body: some View {
        Form {
            Picker("Où ?", selection: $ou) { ForEach(Rangement.allCases) { Text($0.libelle).tag($0) } }.pickerStyle(.segmented)
            TextField("Nom — ex. Haché porc et bœuf", text: $nom)
            TextField("Quantité — ex. 500 g", text: $quantite)
            Picker("Catégorie", selection: $categorie) { ForEach(categoriesProposees, id: \.self) { Text(Categorie.nom($0)).tag($0) } }
            DatePicker(ou == .surgelateur ? "Congelé le" : "Acheté le", selection: $depuis, displayedComponents: .date)
            if ou == .frais {
                TextField("Bon pendant (jours) — sinon \(Categorie.joursFrais[categorie] ?? 4)", text: $bonJours).keyboardType(.numberPad)
            }
            if ou == .armoire {
                Toggle("Date de péremption", isOn: $avecPeremption)
                if avecPeremption { DatePicker("À consommer avant", selection: $peremption, displayedComponents: .date) }
            }
            Section {
                TextField("Prix (€) — ex. 4,20", text: $prix).keyboardType(.decimalPad)
            } footer: {
                Text("Le prix sert au compteur « gagné pour les vacances » quand l'article est mangé au lieu d'être racheté.")
            }
        }
        .environment(\.locale, Locale(identifier: "fr_BE"))
        .navigationTitle("Ranger")
        .onAppear { ou = rangement; if !categoriesProposees.contains(categorie) { categorie = categoriesProposees.first ?? "autre" } }
        .onChange(of: ou) { _, _ in
            if !categoriesProposees.contains(categorie) { categorie = categoriesProposees.first ?? "autre" }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Annuler") { fermer() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Ranger") {
                    let a = Article(foyer: foyer, rangement: ou, nom: nom, categorie: categorie, par: moi)
                    a.quantite = quantite; a.depuis = Jour.chaine(depuis)
                    a.prix = Double(prix.replacingOccurrences(of: ",", with: ".")) ?? 0
                    if ou == .frais, let j = Int(bonJours) { a.bonJours = j }
                    if ou == .armoire, avecPeremption { a.peremption = Jour.chaine(peremption) }
                    if ou == .surgelateur { a.tiroir = Self.tiroirs[categorie] ?? 6 }
                    Retour.succes(); ctx.insert(a); ctx.enregistrer(); Base.rafraichirWidgets(); fermer()
                }.disabled(nom.isEmpty)
            }
        }
    }

    /// Le tiroir du surgélateur par défaut pour chaque catégorie, comme dans l'app web.
    static let tiroirs = ["viandes": 1, "poissons": 2, "plats": 3, "legumes": 4, "pains": 5]
}

struct FormulairePhoto: View {
    let moi: String
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var fermer
    @State private var choix: PhotosPickerItem?
    @State private var image: Data?
    @State private var legende = ""
    @State private var qui: [String] = []

    var body: some View {
        Form {
            PhotosPicker(selection: $choix, matching: .images) {
                if let image, let ui = UIImage(data: image) {
                    Image(uiImage: ui).resizable().scaledToFit().frame(maxHeight: 260)
                } else {
                    Label("Choisir une photo", systemImage: "photo.on.rectangle")
                }
            }
            TextField("Légende — ex. Premier jour d'école", text: $legende)
            Section("Qui est sur la photo ?") { ChoixAimants(membres: Famille.membres, choisis: $qui) }
        }
        .navigationTitle("Le mur des petites")
        .onChange(of: choix) { _, item in
            Task { if let d = try? await item?.loadTransferable(type: Data.self) { image = reduire(d) } }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Annuler") { fermer() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Au mur") {
                    let p = Photo(legende: legende, qui: qui, par: moi); p.image = image
                    Retour.succes(); ctx.insert(p); ctx.enregistrer(); Base.rafraichirWidgets(); fermer()
                }.disabled(image == nil)
            }
        }
    }

    /// Les photos sont réduites à 1200 px pour que la synchronisation iCloud reste rapide.
    private func reduire(_ d: Data) -> Data? {
        guard let ui = UIImage(data: d) else { return nil }
        let k = min(1, 1200 / max(ui.size.width, ui.size.height))
        let taille = CGSize(width: ui.size.width * k, height: ui.size.height * k)
        return UIGraphicsImageRenderer(size: taille).image { _ in ui.draw(in: CGRect(origin: .zero, size: taille)) }
            .jpegData(compressionQuality: 0.8)
    }
}

import SwiftUI
import SwiftData

/// Le calendrier du mois : les dates de la famille, et les bandes de vacances scolaires
/// (Belgique, Luxembourg) et de la maison de Fréjus au-dessus de chaque semaine.
struct CalendrierView: View {
    let moi: String
    @Environment(\.colorScheme) private var scheme
    @Environment(\.horizontalSizeClass) private var largeur
    @Query private var visites: [Visite]
    @Query(sort: \Evenement.debut) private var evenements: [Evenement]
    @State private var mois = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: .now))!
    @State private var jourChoisi = Jour.aujourdhui
    @State private var ajout = false

    private let cal: Calendar = { var c = Calendar(identifier: .gregorian); c.firstWeekday = 2; c.locale = Locale(identifier: "fr_BE"); return c }()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                IciAussi(onglet: "calendrier", moi: moi, visites: visites)
                entete
                grille
                legende
                Porte {
                    Text(Jour.joli(jourChoisi)).font(Theme.titre(20))
                    let vac = VacancesScolaires.le(jourChoisi)
                    if let be = vac.be { Etiquette(texte: "Belgique · \(be)", couleur: Color(hex: 0xC0392B)) }
                    if let lu = vac.lu { Etiquette(texte: "Luxembourg · \(lu)", couleur: Color(hex: 0x93A3AD)) }
                    let du = evenements.filter { $0.debut <= jourChoisi && $0.fin >= jourChoisi }
                    if du.isEmpty { Text("Rien ce jour-là.").foregroundStyle(.secondary) }
                    ForEach(du) { LigneEvenement(e: $0, moi: moi) }
                    Button("Ajouter une date ce jour-là") { ajout = true }.buttonStyle(.borderedProminent)
                }
                Porte {
                    Text("À venir").font(Theme.titre(20))
                    ForEach(evenements.filter { $0.fin >= Jour.aujourdhui }.prefix(20)) { LigneEvenement(e: $0, moi: moi) }
                }
            }
            .padding(16)
        }
        .background(Theme.emaille(scheme))
        .navigationTitle("Calendrier")
        .toolbar { Button { ajout = true } label: { Label("Ajouter une date", systemImage: "plus") } }
        .sheet(isPresented: $ajout) { NavigationStack { FormulaireEvenement(moi: moi, jour: jourChoisi) } }
    }

    private var moisCourant: Date { cal.date(from: cal.dateComponents([.year, .month], from: .now))! }

    private func changerMois(_ delta: Int) {
        Retour.leger()
        avecAnimation { mois = cal.date(byAdding: .month, value: delta, to: mois)! }
    }

    private var entete: some View {
        VStack(spacing: 8) {
            HStack {
                Button { changerMois(-1) } label: {
                    Image(systemName: "chevron.left").frame(width: 44, height: 44)
                }
                .accessibilityLabel("Mois précédent")
                Text(mois.formatted(.dateTime.month(.wide).year().locale(Locale(identifier: "fr_BE"))).capitalized)
                    .font(Theme.titre(24)).frame(maxWidth: .infinity)
                    .accessibilityAddTraits(.isHeader)
                Button { changerMois(1) } label: {
                    Image(systemName: "chevron.right").frame(width: 44, height: 44)
                }
                .accessibilityLabel("Mois suivant")
            }
            .buttonStyle(.bordered)
            if !cal.isDate(mois, equalTo: .now, toGranularity: .month) || jourChoisi != Jour.aujourdhui {
                Button("Revenir à aujourd'hui") {
                    Retour.leger()
                    avecAnimation { mois = moisCourant; jourChoisi = Jour.aujourdhui }
                }
                .font(.willys(.footnote, poids: .semibold))
                .frame(minHeight: 44)
                .transition(.opacity)
            }
        }
        // glisser vers la gauche ou la droite change de mois
        .gesture(DragGesture(minimumDistance: 30).onEnded { v in
            if abs(v.translation.width) > abs(v.translation.height) * 1.5 { changerMois(v.translation.width < 0 ? 1 : -1) }
        })
    }

    /// Les semaines du mois, du lundi au dimanche.
    private var semaines: [[Date]] {
        let premier = mois
        let decalage = (cal.component(.weekday, from: premier) + 5) % 7
        let depart = cal.date(byAdding: .day, value: -decalage, to: premier)!
        return (0..<6).map { s in (0..<7).map { j in cal.date(byAdding: .day, value: s * 7 + j, to: depart)! } }
            .filter { semaine in semaine.contains { cal.isDate($0, equalTo: mois, toGranularity: .month) } }
    }

    private var grille: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                ForEach(["lun", "mar", "mer", "jeu", "ven", "sam", "dim"], id: \.self) {
                    Text($0).font(.willys(.caption2, poids: .semibold)).textCase(.uppercase).foregroundStyle(.secondary).frame(maxWidth: .infinity)
                }
            }
            ForEach(semaines, id: \.first) { semaine in
                bandes(semaine)
                HStack(spacing: 4) { ForEach(semaine, id: \.self) { case_($0) } }
            }
        }
    }

    /// Une bande par pays en vacances (et Fréjus) au-dessus de la semaine.
    @ViewBuilder private func bandes(_ semaine: [Date]) -> some View {
        let jours = semaine.map(Jour.chaine)
        let be = jours.map { VacancesScolaires.le($0).be != nil }
        let lu = jours.map { VacancesScolaires.le($0).lu != nil }
        let fj = jours.map { j in evenements.contains { $0.type == "frejus" && $0.debut <= j && $0.fin >= j } }
        VStack(spacing: 2) {
            if be.contains(true) { bande(be, couleur: Color(hex: 0xC0392B), plein: false) }
            if lu.contains(true) { bande(lu, couleur: Color(hex: 0x93A3AD), plein: false) }
            if fj.contains(true) { bande(fj, couleur: Color(hex: 0x2A7FA8), plein: true) }
        }
        .padding(.top, 4)
    }

    private func bande(_ actifs: [Bool], couleur: Color, plein: Bool) -> some View {
        HStack(spacing: 0) {
            ForEach(0..<7, id: \.self) { i in
                Rectangle().fill(actifs[i] ? (plein ? couleur : couleur.opacity(0.35)) : .clear).frame(height: 5)
            }
        }
        .clipShape(Capsule())
    }

    private func case_(_ d: Date) -> some View {
        let j = Jour.chaine(d)
        let du = evenements.filter { $0.debut <= j && $0.fin >= j }
        let dansMois = cal.isDate(d, equalTo: mois, toGranularity: .month)
        return Button { Retour.selection(); avecAnimation { jourChoisi = j } } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(d.formatted(.dateTime.day())).font(.willys(.caption, poids: .bold)).monospacedDigit()
                if largeur == .compact {
                    // sur iPhone, des titres de 11 pt ne se lisent pas : des points de couleur, le détail est dessous
                    HStack(spacing: 3) {
                        ForEach(du.prefix(4)) { e in Circle().fill(e.typeEvenement.couleur).frame(width: 8, height: 8) }
                    }
                } else {
                    ForEach(du.prefix(3)) { e in
                        Text(e.titre).font(.willys(.caption2)).lineLimit(1).foregroundStyle(.white)
                            .padding(.horizontal, 3).frame(maxWidth: .infinity, alignment: .leading)
                            .background(e.typeEvenement.couleur, in: RoundedRectangle(cornerRadius: 3))
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(4)
            .frame(maxWidth: .infinity, minHeight: largeur == .compact ? 52 : 64, alignment: .topLeading)
            .background(Theme.porte(scheme), in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10)
                .strokeBorder(j == Jour.aujourdhui ? Theme.accent : (j == jourChoisi ? .primary : .secondary.opacity(0.2)),
                              lineWidth: j == Jour.aujourdhui || j == jourChoisi ? 2 : 1))
            .opacity(dansMois ? 1 : 0.4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(Jour.joli(j)), \(du.isEmpty ? "rien de prévu" : du.map(\.titre).joined(separator: ", "))")
        .accessibilityAddTraits(j == jourChoisi ? .isSelected : [])
    }

    private var legende: some View {
        HStack(spacing: 14) {
            ForEach([("Belgique", Color(hex: 0xC0392B).opacity(0.35)), ("Luxembourg", Color(hex: 0x93A3AD).opacity(0.35)),
                     ("Fréjus", Color(hex: 0x2A7FA8))], id: \.0) { n, c in
                HStack(spacing: 6) { Capsule().fill(c).frame(width: 24, height: 6); Text(n) }
            }
        }
        .font(.willys(.caption)).foregroundStyle(.secondary)
    }
}

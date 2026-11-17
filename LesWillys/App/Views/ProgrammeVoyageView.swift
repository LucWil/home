import SwiftUI
import SwiftData
import MapKit

/// Le programme d'un voyage : les étapes de chaque jour, dessinées sur la carte, avec le trajet de jour en jour.
/// Tout le monde peut ajouter une étape ; elle apparaît sur la carte de la famille.
struct ProgrammeVoyageView: View {
    let idee: Idee
    let moi: String
    @Environment(\.modelContext) private var ctx
    @Environment(\.colorScheme) private var scheme
    @Query(sort: \Etape.ordre) private var toutes: [Etape]
    @Query private var reactions: [Reaction]
    @State private var camera: MapCameraPosition = .automatic
    @State private var jourVu: Int? = nil              // nil = tous les jours
    @State private var ajout: Int?                      // le jour où l'on ajoute une étape
    @State private var choisie: String?                 // la cle de l'étape touchée

    private var etapes: [Etape] {
        toutes.filter { $0.voyage == idee.cle }
            .sorted { ($0.jour, $0.ordre, $0.heure) < ($1.jour, $1.ordre, $1.heure) }
    }
    private var jours: [Int] { Array(Set(etapes.map(\.jour))).sorted() }
    private var visibles: [Etape] { etapes.filter { jourVu == nil || $0.jour == jourVu } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                carte
                barreJours
                if etapes.isEmpty { vide } else { ForEach(jours.filter { jourVu == nil || $0 == jourVu }, id: \.self) { jour($0) } }
            }
            .padding(16)
        }
        .background(Theme.emaille(scheme))
        .navigationTitle(idee.titre)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem { Button { ajout = jourVu ?? (jours.last ?? 1) } label: { Label("Ajouter une étape", systemImage: "plus") } }
        }
        .sheet(item: Binding(get: { ajout.map { JourAjout(jour: $0) } }, set: { ajout = $0?.jour })) { j in
            NavigationStack {
                FormulaireEtape(idee: idee, jour: j.jour, ordre: (etapes.filter { $0.jour == j.jour }.map(\.ordre).max() ?? 0) + 1,
                                centre: centre, moi: moi)
            }
        }
        .onAppear { ajuster() }
        .onChange(of: jourVu) { _, _ in ajuster() }
        .onChange(of: etapes.count) { _, _ in ajuster() }
    }

    struct JourAjout: Identifiable { let jour: Int; var id: Int { jour } }

    // MARK: La carte

    private var carte: some View {
        Map(position: $camera) {
            // le trajet : un trait par jour, relié dans l'ordre des étapes
            ForEach(jours.filter { jourVu == nil || $0 == jourVu }, id: \.self) { j in
                let points = etapes.filter { $0.jour == j && $0.aUnePosition }.map(\.coordonnee)
                if points.count > 1 {
                    MapPolyline(coordinates: points)
                        .stroke(CouleursJours.pour(j).opacity(0.85), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round, dash: [1, 7]))
                }
            }
            ForEach(visibles.filter(\.aUnePosition)) { e in
                Annotation(e.titre, coordinate: e.coordonnee, anchor: .bottom) { epingle(e) }
            }
        }
        .mapStyle(.standard(elevation: .realistic, pointsOfInterest: .including([.nationalPark, .museum, .restaurant, .hotel])))
        .frame(height: 320)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(.primary.opacity(0.08)))
        .overlay {
            if etapes.contains(where: \.aUnePosition) == false {
                Text("Ajoute une étape : elle apparaîtra ici.").font(.willys(.subheadline, poids: .semibold))
                    .padding(10).background(.ultraThinMaterial, in: Capsule())
            }
        }
    }

    private func epingle(_ e: Etape) -> some View {
        let n = (etapes.filter { $0.jour == e.jour }.firstIndex { $0.cle == e.cle } ?? 0) + 1
        let actif = choisie == e.cle
        return Button {
            Retour.selection()
            avecAnimation { choisie = e.cle; camera = .region(MKCoordinateRegion(center: e.coordonnee, latitudinalMeters: 4000, longitudinalMeters: 4000)) }
        } label: {
            ZStack {
                Circle().fill(CouleursJours.pour(e.jour))
                Circle().strokeBorder(.white, lineWidth: 2)
                VStack(spacing: 0) {
                    Image(systemName: e.type.icone).font(.system(size: 11, weight: .bold))
                    Text("\(n)").font(.system(size: 10, weight: .heavy)).monospacedDigit()
                }.foregroundStyle(.white)
            }
            .frame(width: actif ? 46 : 36, height: actif ? 46 : 36)
            .shadow(radius: 3, y: 2)
            .frame(minWidth: 44, minHeight: 44)
        }
        .buttonStyle(StyleAimant())
        .accessibilityLabel("Jour \(e.jour), étape \(n) : \(e.titre)")
    }

    /// Cadre la carte sur ce qui est affiché.
    private func ajuster() {
        let pts = visibles.filter(\.aUnePosition).map(\.coordonnee)
        guard !pts.isEmpty else { return }
        if pts.count == 1 {
            camera = .region(MKCoordinateRegion(center: pts[0], latitudinalMeters: 6000, longitudinalMeters: 6000)); return
        }
        var rect = MKMapRect.null
        for p in pts { rect = rect.union(MKMapRect(origin: MKMapPoint(p), size: MKMapSize(width: 0, height: 0))) }
        let marge = max(rect.size.width, rect.size.height) * 0.3 + 2000
        camera = .rect(rect.insetBy(dx: -marge, dy: -marge))
    }

    /// Le point de départ des recherches : la dernière étape, ou le milieu des étapes.
    private var centre: CLLocationCoordinate2D? {
        etapes.last(where: \.aUnePosition)?.coordonnee
    }

    // MARK: Les jours

    private var barreJours: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                puce("Tout le voyage", actif: jourVu == nil, couleur: Theme.accent) { jourVu = nil }
                ForEach(jours, id: \.self) { j in
                    puce("Jour \(j)", actif: jourVu == j, couleur: CouleursJours.pour(j)) { jourVu = j }
                }
                Button { ajout = (jours.last ?? 0) + 1 } label: {
                    Label("Nouveau jour", systemImage: "plus").font(.willys(.subheadline, poids: .bold))
                        .padding(.horizontal, 14).frame(minHeight: 44)
                        .overlay(Capsule().strokeBorder(.primary.opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func puce(_ titre: String, actif: Bool, couleur: Color, action: @escaping () -> Void) -> some View {
        Button { Retour.selection(); avecAnimation(action) } label: {
            Text(titre).font(.willys(.subheadline, poids: .bold)).padding(.horizontal, 16).frame(minHeight: 44)
                .background(actif ? couleur : Theme.porte(scheme), in: Capsule())
                .foregroundStyle(actif ? Color.white : Color.primary)
        }
        .buttonStyle(StyleAimant())
        .accessibilityAddTraits(actif ? .isSelected : [])
    }

    private var vide: some View {
        ContentUnavailableView {
            Label("Pas encore de programme", systemImage: "map")
        } description: {
            Text("Ajoute les endroits à voir, les repas et l'hôtel. Chaque étape se place sur la carte, et toute la famille la voit.")
        } actions: {
            Button("Ajouter la première étape") { ajout = 1 }.buttonStyle(.borderedProminent)
        }
    }

    private func jour(_ j: Int) -> some View {
        let liste = etapes.filter { $0.jour == j }
        let km = distance(liste)
        return Porte {
            HStack {
                Circle().fill(CouleursJours.pour(j)).frame(width: 14, height: 14)
                Text("Jour \(j)").font(Theme.titre(20))
                Spacer()
                Text("\(liste.count) étape\(liste.count > 1 ? "s" : "")" + (km > 0.1 ? " · ≈ \(km.formatted(.number.precision(.fractionLength(0...1)))) km" : ""))
                    .font(.willys(.footnote)).foregroundStyle(.secondary)
            }
            ForEach(Array(liste.enumerated()), id: \.element.id) { i, e in
                if i > 0 { Divider() }
                ligne(e, rang: i + 1, precedente: i > 0 ? liste[i - 1] : nil, liste: liste)
            }
            Button("Ajouter une étape ce jour-là", systemImage: "plus") { ajout = j }
                .buttonStyle(.bordered).frame(minHeight: 44)
        }
    }

    private func ligne(_ e: Etape, rang: Int, precedente: Etape?, liste: [Etape]) -> some View {
        let coeurs = reactions.filter { $0.element == e.cle && $0.reaction == "coeur" }
        let aime = coeurs.contains { $0.membre == moi }
        return HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle().fill(CouleursJours.pour(e.jour))
                Image(systemName: e.type.icone).font(.footnote.bold()).foregroundStyle(.white)
            }
            .frame(width: 34, height: 34)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    if !e.heure.isEmpty { Text(e.heure).font(.willys(.footnote, poids: .bold)).monospacedDigit().foregroundStyle(.secondary) }
                    Text(e.titre).bold()
                }
                if !e.adresse.isEmpty { Text(e.adresse).font(.willys(.footnote)).foregroundStyle(.secondary).lineLimit(2) }
                if !e.note.isEmpty { Text(e.note).font(.willys(.subheadline)) }
                if let p = precedente, p.aUnePosition, e.aUnePosition {
                    let d = CLLocation(latitude: p.latitude, longitude: p.longitude).distance(from: CLLocation(latitude: e.latitude, longitude: e.longitude)) / 1000
                    Label("≈ \(d.formatted(.number.precision(.fractionLength(0...1)))) km depuis l'étape \(rang - 1)", systemImage: "arrow.turn.down.right")
                        .font(.willys(.caption)).foregroundStyle(.secondary)
                }
                HStack(spacing: 8) {
                    Aimant(membre: e.par, taille: 22)
                    Button {
                        Retour.selection()
                        avecAnimation { Reactions.basculer(element: e.cle, membre: moi, reaction: "coeur", existantes: reactions.filter { $0.element == e.cle }, ctx: ctx) }
                    } label: { Text("❤️\(coeurs.isEmpty ? "" : " \(coeurs.count)")") }
                        .buttonStyle(StylePastille(active: aime))
                        .accessibilityLabel("J'aime cette étape, \(coeurs.count)")
                    if e.aUnePosition {
                        Button { ouvrirDansPlans(e) } label: { Label("Y aller", systemImage: "location.fill") }
                            .buttonStyle(StylePastille(active: false))
                    }
                }
            }
            Spacer(minLength: 0)
            Menu {
                if e.aUnePosition { Button("Voir sur la carte", systemImage: "map") { montrer(e) } }
                if liste.first?.cle != e.cle { Button("Passer avant", systemImage: "arrow.up") { echanger(e, liste: liste, sens: -1) } }
                if liste.last?.cle != e.cle { Button("Passer après", systemImage: "arrow.down") { echanger(e, liste: liste, sens: 1) } }
                Menu("Changer de jour", systemImage: "calendar") {
                    ForEach(1...max(jours.last ?? 1, 1) + 1, id: \.self) { j in
                        if j != e.jour { Button("Jour \(j)") { deplacer(e, vers: j) } }
                    }
                }
                Button("Retirer", systemImage: "trash", role: .destructive) {
                    Retour.avertissement(); avecAnimation { ctx.delete(e); ctx.enregistrer() }
                }
            } label: { Image(systemName: "ellipsis.circle").font(.title3).frame(width: 44, height: 44) }
            .accessibilityLabel("Autres actions")
        }
    }

    // MARK: Gestes

    private func montrer(_ e: Etape) {
        choisie = e.cle
        withAnimation(Anim.douce) { camera = .region(MKCoordinateRegion(center: e.coordonnee, latitudinalMeters: 4000, longitudinalMeters: 4000)) }
    }

    private func ouvrirDansPlans(_ e: Etape) {
        let item = MKMapItem(placemark: MKPlacemark(coordinate: e.coordonnee))
        item.name = e.titre
        item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
    }

    private func echanger(_ e: Etape, liste: [Etape], sens: Int) {
        guard let i = liste.firstIndex(where: { $0.cle == e.cle }), liste.indices.contains(i + sens) else { return }
        Retour.leger()
        avecAnimation {
            let autre = liste[i + sens]
            let o = e.ordre; e.ordre = autre.ordre; autre.ordre = o
            if e.ordre == autre.ordre { e.ordre += sens }
            ctx.enregistrer()
        }
    }

    private func deplacer(_ e: Etape, vers jour: Int) {
        Retour.leger()
        avecAnimation {
            e.jour = jour
            e.ordre = (etapes.filter { $0.jour == jour }.map(\.ordre).max() ?? 0) + 1
            ctx.enregistrer()
        }
    }

    /// La longueur du trajet du jour, à vol d'oiseau, d'étape en étape.
    private func distance(_ liste: [Etape]) -> Double {
        let pts = liste.filter(\.aUnePosition)
        guard pts.count > 1 else { return 0 }
        return zip(pts, pts.dropFirst()).reduce(0) { total, paire in
            total + CLLocation(latitude: paire.0.latitude, longitude: paire.0.longitude)
                .distance(from: CLLocation(latitude: paire.1.latitude, longitude: paire.1.longitude)) / 1000
        }
    }
}

// MARK: - Ajouter une étape

struct FormulaireEtape: View {
    let idee: Idee
    let jour: Int
    let ordre: Int
    let centre: CLLocationCoordinate2D?
    let moi: String
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var fermer
    @State private var recherche = ""
    @State private var resultats: [MKMapItem] = []
    @State private var enCours = false
    @State private var choix: MKMapItem?
    @State private var titre = ""
    @State private var type: TypeEtape = .visite
    @State private var numeroJour: Int
    @State private var avecHeure = false
    @State private var heure = Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: .now) ?? .now
    @State private var note = ""

    init(idee: Idee, jour: Int, ordre: Int, centre: CLLocationCoordinate2D?, moi: String) {
        self.idee = idee; self.jour = jour; self.ordre = ordre; self.centre = centre; self.moi = moi
        _numeroJour = State(initialValue: jour)
    }

    var body: some View {
        Form {
            Section("Chercher un lieu") {
                HStack {
                    TextField("Ex. Aiguille du Midi, restaurant, gare…", text: $recherche)
                        .submitLabel(.search).onSubmit { Task { await chercher(recherche) } }
                    if enCours { ProgressView() }
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(TypeEtape.allCases) { t in
                            Button { type = t; Task { await chercher(t.recherche + (centre == nil ? " " + idee.titre : "")) } } label: {
                                Label(t.libelle, systemImage: t.icone).font(.willys(.footnote, poids: .semibold))
                                    .padding(.horizontal, 12).frame(minHeight: 44)
                                    .background(Theme.accent.opacity(0.22), in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                ForEach(resultats, id: \.self) { item in
                    Button {
                        Retour.selection(); choix = item
                        titre = item.name ?? titre
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(item.name ?? "Lieu").bold()
                                Text(item.placemark.title ?? "").font(.willys(.caption)).foregroundStyle(.secondary).lineLimit(2)
                            }
                            Spacer()
                            if choix == item { Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.ok) }
                        }
                        .frame(minHeight: 44)
                    }
                    .buttonStyle(.plain)
                }
            }
            Section("L'étape") {
                TextField("Nom de l'étape", text: $titre)
                Picker("Genre", selection: $type) { ForEach(TypeEtape.allCases) { Label($0.libelle, systemImage: $0.icone).tag($0) } }
                Stepper("Jour \(numeroJour)", value: $numeroJour, in: 1...30)
                Toggle("Heure prévue", isOn: $avecHeure)
                if avecHeure { DatePicker("À", selection: $heure, displayedComponents: .hourAndMinute) }
                TextField("Note (réservation, conseil…)", text: $note, axis: .vertical)
            }
        }
        .environment(\.locale, Locale(identifier: "fr_BE"))
        .navigationTitle("Une étape")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Annuler") { fermer() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Ajouter") { enregistrer() }.disabled(titre.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private func chercher(_ q: String) async {
        let texte = q.trimmingCharacters(in: .whitespaces)
        guard !texte.isEmpty else { return }
        enCours = true; defer { enCours = false }
        let requete = MKLocalSearch.Request()
        requete.naturalLanguageQuery = texte
        if let c = centre { requete.region = MKCoordinateRegion(center: c, latitudinalMeters: 40_000, longitudinalMeters: 40_000) }
        resultats = Array(((try? await MKLocalSearch(request: requete).start().mapItems) ?? []).prefix(8))
    }

    private func enregistrer() {
        let e = Etape(voyage: idee.cle, jour: numeroJour, ordre: ordre, titre: titre.trimmingCharacters(in: .whitespaces), par: moi)
        e.categorie = type.rawValue
        e.note = note
        if avecHeure { e.heure = heure.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits).locale(Locale(identifier: "fr_BE"))) }
        if let c = choix {
            e.latitude = c.placemark.coordinate.latitude; e.longitude = c.placemark.coordinate.longitude
            e.adresse = c.placemark.title ?? ""
        }
        ctx.insert(e); ctx.enregistrer(); Retour.succes(); fermer()
    }
}

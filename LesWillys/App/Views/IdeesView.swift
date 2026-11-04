import SwiftUI
import SwiftData

/// Voyages et week-ends : chacun propose, tout le monde réagit (J'adore, J'en suis, Bof).
struct IdeesView: View {
    let genre: String   // "voyage" ou "weekend"
    let moi: String
    @Environment(\.colorScheme) private var scheme
    @Query private var visites: [Visite]
    @Query(sort: \Idee.cree, order: .reverse) private var toutes: [Idee]
    @Query private var reactions: [Reaction]
    @State private var ajout = false

    private var idees: [Idee] {
        toutes.filter { $0.genre == genre }.sorted { score($0) > score($1) }
    }
    private func score(_ i: Idee) -> Int {
        reactions.filter { $0.element == i.cle && ($0.reaction == "partant" || $0.reaction == "adore") }.count
    }

    var body: some View {
        ScrollView {
            IciAussi(onglet: "loisirs", moi: moi, visites: visites)
                .frame(maxWidth: .infinity, alignment: .leading).padding([.horizontal, .top], 16)
            if idees.isEmpty {
                ContentUnavailableView {
                    Label(genre == "voyage" ? "Pas encore de voyage" : "Pas encore de week-end",
                          systemImage: genre == "voyage" ? "airplane" : "sun.max")
                } description: {
                    Text("Propose une idée : toute la famille pourra dire si elle en est.")
                } actions: {
                    Button(genre == "voyage" ? "Proposer un voyage" : "Proposer un week-end") { ajout = true }
                        .buttonStyle(.borderedProminent)
                }
                .padding(.top, 40)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 16)], spacing: 16) {
                ForEach(idees) { i in CarteIdee(idee: i, moi: moi, reactions: reactions.filter { $0.element == i.cle }) }
            }
            .padding(16)
        }
        .background(Theme.emaille(scheme))
        .navigationTitle(genre == "voyage" ? "Voyages" : "Week-ends")
        .toolbar { Button { ajout = true } label: { Label("Proposer", systemImage: "plus") } }
        .sheet(isPresented: $ajout) { NavigationStack { FormulaireIdee(genre: genre, moi: moi) } }
    }
}

struct CarteIdee: View {
    let idee: Idee
    let moi: String
    let reactions: [Reaction]
    @Environment(\.modelContext) private var ctx
    @Environment(\.colorScheme) private var scheme

    private static let choix = [("adore", "😍", "J'adore"), ("partant", "🙋", "J'en suis"), ("bof", "🤔", "Bof")]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .bottomTrailing) {
                if let url = URL(string: idee.photo), !idee.photo.isEmpty {
                    AsyncImage(url: url) { $0.resizable().scaledToFill() } placeholder: { Color.secondary.opacity(0.15) }
                } else {
                    LinearGradient(colors: [Famille.membre(idee.par)?.couleur.opacity(0.5) ?? .gray, Theme.accent.opacity(0.3)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                }
                if !idee.prix.isEmpty {
                    Text("\(idee.prix) € / pers.").font(.willys(.footnote, poids: .bold)).padding(.horizontal, 10).padding(.vertical, 3)
                        .background(Theme.porte(scheme), in: Capsule()).padding(10)
                }
            }
            .frame(height: 160).clipped()

            VStack(alignment: .leading, spacing: 8) {
                HStack { Aimant(membre: idee.par, taille: 26); Text(idee.titre).font(Theme.titre(19)) }
                if !idee.quand.isEmpty { Label(idee.quand, systemImage: "calendar").font(.willys(.subheadline)).foregroundStyle(.secondary) }
                if !idee.note.isEmpty { Text(idee.note).font(.willys(.subheadline)) }
                if let url = URL(string: idee.lien), !idee.lien.isEmpty { Link("Voir l'offre", destination: url).font(.willys(.subheadline, poids: .bold)) }
                HStack(spacing: 6) {
                    ForEach(Self.choix, id: \.0) { k, e, l in
                        let n = reactions.filter { $0.reaction == k }.count
                        let mienne = reactions.first { $0.membre == moi }?.reaction == k
                        Button {
                            Retour.selection()
                            avecAnimation { Reactions.basculer(element: idee.cle, membre: moi, reaction: k, existantes: reactions, ctx: ctx) }
                        } label: {
                            Text("\(e) \(l)\(n > 0 ? " · \(n)" : "")").contentTransition(.numericText())
                        }
                        .buttonStyle(StylePastille(active: mienne))
                        .accessibilityLabel("\(l), \(n) personne\(n > 1 ? "s" : "")")
                    }
                }
                let partants = reactions.filter { $0.reaction == "partant" }.map(\.membre)
                if !partants.isEmpty {
                    HStack { PileAimants(membres: partants, taille: 20); Text("en sont").font(.willys(.caption)).foregroundStyle(.secondary) }
                }
            }
            .padding([.horizontal, .bottom], 16)
        }
        .background(Theme.porte(scheme))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(.secondary.opacity(0.2)))
        .shadow(color: .black.opacity(0.08), radius: 10, y: 6)
        .contextMenu {
            ShareLink(item: "\(idee.titre)\(idee.quand.isEmpty ? "" : " — \(idee.quand)") \(idee.lien)")
            if idee.par == moi {
                Button("Retirer", systemImage: "trash", role: .destructive) {
                    Retour.avertissement(); avecAnimation { ctx.delete(idee); ctx.enregistrer() }
                }
            }
        }
    }
}

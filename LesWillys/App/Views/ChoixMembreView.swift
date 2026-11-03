import SwiftUI

/// « Qui rentre à la maison ? » — la maison dessinée, un aimant par adulte.
/// Le choix est retenu sur l'appareil (et partagé avec les widgets).
struct ChoixMembreView: View {
    let choisir: (String) -> Void
    @Environment(\.colorScheme) private var scheme

    private let colonnes = [GridItem(.adaptive(minimum: 86), spacing: 14)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(Locale(identifier: "fr_BE"))))
                    .font(.caption.weight(.semibold)).textCase(.uppercase).foregroundStyle(.secondary)
                Text("Qui rentre à la maison ?").font(Theme.titre(34))
                Text("Touche ton aimant. Cet iPhone ou cet iPad s'en souviendra, tu n'auras plus à le refaire.")
                    .foregroundStyle(.secondary)

                maison.padding(.top, 70)

                Text("Les petites sont à l'étage : ce sont les parents qui remplissent leur agenda.")
                    .font(.footnote).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity).multilineTextAlignment(.center).padding(.top, 8)
            }
            .padding(20)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.emaille(scheme))
    }

    private var maison: some View {
        VStack(spacing: 14) {
            // L'étage : la date sur un post-it, et les aimants des petites
            HStack(spacing: 12) {
                Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(Locale(identifier: "fr_BE"))))
                    .font(Theme.main(17)).foregroundStyle(Theme.encrePostit)
                    .padding(10).background(Theme.postit).rotationEffect(.degrees(-3.5))
                ForEach(Famille.enfants) { e in
                    HStack(spacing: 6) { Aimant(membre: e.id, taille: 26); Text(e.nom).font(.footnote.bold()) }
                        .padding(.vertical, 4).padding(.leading, 4).padding(.trailing, 10)
                        .background(.background, in: Capsule())
                }
            }
            .frame(maxWidth: .infinity, minHeight: 100)
            .background(panneau)

            // Le rez-de-chaussée : les adultes
            LazyVGrid(columns: colonnes, spacing: 22) {
                ForEach(Array(Famille.adultes.enumerated()), id: \.element.id) { i, m in
                    Button { choisir(m.id) } label: {
                        VStack(spacing: 7) {
                            Aimant(membre: m.id, taille: 64)
                            Text(m.nom).font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(.primary)
                        }
                    }
                    .buttonStyle(.plain)
                    .rotationEffect(.degrees([-6, 4, -2][i % 3]))
                }
            }
            .padding(.vertical, 26).padding(.horizontal, 12)
            .background(panneau)
            .overlay(alignment: .bottomTrailing) {
                UnevenRoundedRectangle(topLeadingRadius: 8, topTrailingRadius: 8)
                    .fill(Color(hex: 0x2F6FB5)).frame(width: 30, height: 62).padding(.trailing, 10)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(LinearGradient(colors: scheme == .dark ? [Color(hex: 0x4A3F35), Color(hex: 0x3B322A)]
                                                            : [Color(hex: 0xE9D8C4), Color(hex: 0xDCC6AD)],
                                     startPoint: .top, endPoint: .bottom))
        )
        .overlay(alignment: .top) {
            Triangle().fill(LinearGradient(colors: [Color(hex: 0xB5553C), Color(hex: 0x953F2C)], startPoint: .top, endPoint: .bottom))
                .frame(height: 72).padding(.horizontal, -8).offset(y: -70)
        }
        .overlay(alignment: .bottom) {
            Capsule().fill(Color(hex: 0x5F8A2E)).frame(height: 14).padding(.horizontal, -8).offset(y: 8)
        }
    }

    private var panneau: some View {
        RoundedRectangle(cornerRadius: 16).fill(Theme.porte(scheme)).shadow(color: .black.opacity(0.2), radius: 2, y: 2)
    }
}

struct Triangle: Shape {
    func path(in r: CGRect) -> Path {
        Path { p in p.move(to: CGPoint(x: r.midX, y: r.minY)); p.addLine(to: CGPoint(x: r.maxX, y: r.maxY)); p.addLine(to: CGPoint(x: r.minX, y: r.maxY)); p.closeSubpath() }
    }
}

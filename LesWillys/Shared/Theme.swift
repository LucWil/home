import SwiftUI
import UIKit

/// L'habillage « porte du frigo » : fond émaillé, aimants de couleur, post-it manuscrits.
///
/// Règles d'Apple (Human Interface Guidelines) appliquées partout :
/// - toutes les polices suivent la taille de texte choisie dans Réglages (Dynamic Type) ;
/// - couleurs adaptées au mode sombre et contrastes lisibles ;
/// - zones à toucher d'au moins 44 points ;
/// - animations coupées si « Réduire les animations » est activé ;
/// - retours haptiques discrets, seulement sur les gestes qui comptent.
enum Theme {
    static let accent = Color("AccentColor")
    static let postit = Color(hex: 0xFFF6C9)
    static let postitRose = Color(hex: 0xFFE3D6)
    static let encrePostit = Color(hex: 0x3B3110)
    static let ok = Color(light: 0x2F8A5B, dark: 0x5CC08B)
    static let alerte = Color(light: 0xC0582F, dark: 0xE88761)

    static func emaille(_ scheme: ColorScheme) -> Color { Color("Fond") }
    static func porte(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0x1A242E) : Color(hex: 0xF6F9F7)
    }

    // MARK: Typographie
    // Bricolage Grotesque pour les titres, Figtree pour le texte, Gochi Hand pour l'écriture à la main :
    // les mêmes polices que l'app web.

    /// Titre « affiche ». La taille donnée est celle du réglage standard ; elle grandit avec Dynamic Type.
    static func titre(_ taille: CGFloat) -> Font {
        .custom("BricolageGrotesque-ExtraBold", size: taille, relativeTo: style(pour: taille))
    }

    /// Écriture manuscrite des petits mots et des légendes.
    static func main(_ taille: CGFloat) -> Font {
        .custom("GochiHand-Regular", size: taille, relativeTo: .body)
    }

    /// Le style de texte iOS le plus proche d'une taille, pour que l'agrandissement suive la bonne courbe.
    private static func style(pour taille: CGFloat) -> Font.TextStyle {
        switch taille {
        case 30...: .largeTitle
        case 26..<30: .title
        case 21..<26: .title2
        case 19..<21: .title3
        default: .headline
        }
    }

    /// Les barres de navigation : grand titre en Bricolage, titre réduit en Figtree.
    static func appliquerAuxBarres() {
        let grand = UIFont(name: "BricolageGrotesque-ExtraBold", size: 34) ?? .systemFont(ofSize: 34, weight: .heavy)
        let petit = UIFont(name: "Figtree-Bold", size: 17) ?? .systemFont(ofSize: 17, weight: .bold)
        let barre = UINavigationBar.appearance()
        barre.largeTitleTextAttributes = [.font: UIFontMetrics(forTextStyle: .largeTitle).scaledFont(for: grand)]
        barre.titleTextAttributes = [.font: UIFontMetrics(forTextStyle: .headline).scaledFont(for: petit)]
    }
}

extension Font {
    /// Figtree, à la taille et au poids du style iOS correspondant (et qui suit Dynamic Type).
    static func willys(_ style: TextStyle, poids: Weight? = nil) -> Font {
        let (taille, defaut): (CGFloat, Weight) = switch style {
        case .largeTitle: (34, .bold)
        case .title: (28, .bold)
        case .title2: (22, .bold)
        case .title3: (20, .semibold)
        case .headline: (17, .semibold)
        case .callout: (16, .regular)
        case .subheadline: (15, .regular)
        case .footnote: (13, .regular)
        case .caption: (12, .regular)
        case .caption2: (11, .regular)
        default: (17, .regular)
        }
        let p = poids ?? defaut
        let nom = p == .bold || p == .heavy || p == .black ? "Figtree-Bold"
            : p == .semibold || p == .medium ? "Figtree-SemiBold" : "Figtree-Regular"
        return .custom(nom, size: taille, relativeTo: style)
    }
}

// MARK: - Retours haptiques

/// Une petite vibration pour confirmer un geste : jamais en continu, jamais pour rien.
enum Retour {
    static func succes() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func avertissement() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
    static func leger() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    /// L'aimant qui se colle au frigo.
    static func aimant() { UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.8) }
    static func selection() { UISelectionFeedbackGenerator().selectionChanged() }
}

// MARK: - Animations

enum Anim {
    static var douce: Animation? {
        UIAccessibility.isReduceMotionEnabled ? nil : .spring(response: 0.38, dampingFraction: 0.78)
    }
    static var rebond: Animation? {
        UIAccessibility.isReduceMotionEnabled ? nil : .spring(response: 0.3, dampingFraction: 0.55)
    }
}

/// Exécute un changement avec l'animation douce (ou sans, si l'utilisateur a réduit les animations).
func avecAnimation(_ changement: () -> Void) { withAnimation(Anim.douce, changement) }

extension AnyTransition {
    /// Un post-it qu'on colle : il arrive en grandissant un peu.
    static var colle: AnyTransition {
        UIAccessibility.isReduceMotionEnabled ? .opacity : .scale(scale: 0.85).combined(with: .opacity)
    }
    /// Un article qui quitte le stock.
    static var sort: AnyTransition {
        UIAccessibility.isReduceMotionEnabled ? .opacity
            : .asymmetric(insertion: .opacity, removal: .move(edge: .trailing).combined(with: .opacity))
    }
}

/// Le bouton-aimant : il s'enfonce un peu sous le doigt et revient en rebondissant.
struct StyleAimant: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .animation(Anim.rebond, value: configuration.isPressed)
    }
}

/// Les pastilles de réaction : capsules d'au moins 44 points de haut, état actif bien visible.
struct StylePastille: ButtonStyle {
    var active: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.willys(.footnote, poids: .semibold))
            .padding(.horizontal, 12).padding(.vertical, 6)
            .frame(minHeight: 32)
            .background(active ? Theme.accent.opacity(0.9) : Color.secondary.opacity(0.1), in: Capsule())
            .foregroundStyle(active ? Color.black.opacity(0.85) : Color.primary)
            .contentShape(Capsule().inset(by: -6))          // zone de toucher ≥ 44 pt
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(Anim.rebond, value: configuration.isPressed)
    }
}

// MARK: - Composants

/// Un aimant : rond, de la couleur du membre, avec son initiale (ou sa photo).
struct Aimant: View {
    let membre: String
    var taille: CGFloat = 36
    var photo: Data? = nil

    var body: some View {
        let m = Famille.membre(membre)
        ZStack {
            Circle().fill(
                LinearGradient(colors: [(m?.couleur ?? .gray).opacity(0.85), m?.couleur ?? .gray],
                               startPoint: .top, endPoint: .bottom))
            if let photo, let ui = UIImage(data: photo) {
                Image(uiImage: ui).resizable().scaledToFill().clipShape(Circle())
            } else {
                Text(m?.initiale ?? "?")
                    .font(.custom("BricolageGrotesque-ExtraBold", fixedSize: taille * 0.44))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.25), radius: 0, y: 1)
            }
        }
        .frame(width: taille, height: taille)
        // le reflet et l'ombre d'un vrai aimant
        .overlay(Circle().strokeBorder(.white.opacity(0.35), lineWidth: 1).blendMode(.overlay))
        .shadow(color: .black.opacity(0.22), radius: taille * 0.06, y: taille * 0.06)
        .accessibilityElement()
        .accessibilityLabel(m?.nom ?? membre)
    }
}

/// Une pile d'aimants qui se chevauchent.
struct PileAimants: View {
    let membres: [String]
    var taille: CGFloat = 24
    var body: some View {
        HStack(spacing: -taille * 0.25) {
            ForEach(membres, id: \.self) { Aimant(membre: $0, taille: taille) }
        }
        .accessibilityElement()
        .accessibilityLabel(membres.compactMap { Famille.membre($0)?.nom }.formatted(.list(type: .and).locale(Locale(identifier: "fr_BE"))))
    }
}

/// Un post-it légèrement de travers, avec l'aimant de son auteur en guise de punaise.
struct PostIt: View {
    let texte: String
    let auteur: String
    var sousTitre: String = ""
    var rose = false
    var taillePolice: CGFloat = 24

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(texte).font(Theme.main(taillePolice)).foregroundStyle(Theme.encrePostit)
                .frame(maxWidth: .infinity, alignment: .leading)
            if !sousTitre.isEmpty {
                Text(sousTitre).font(.willys(.caption)).foregroundStyle(Theme.encrePostit.opacity(0.75))
            }
        }
        .padding(.top, 20).padding([.horizontal, .bottom], 14)
        .background {
            // un léger dégradé et un coin plus sombre : du vrai papier
            ZStack {
                (rose ? Theme.postitRose : Theme.postit)
                LinearGradient(colors: [.clear, .black.opacity(0.05)], startPoint: .top, endPoint: .bottomTrailing)
            }
            .clipShape(RoundedRectangle(cornerRadius: 3))
        }
        .overlay(alignment: .top) { Aimant(membre: auteur, taille: 28).offset(y: -12) }
        .rotationEffect(.degrees(rose ? 1 : -1.2))
        .shadow(color: .black.opacity(0.18), radius: 10, y: 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Mot de \(Famille.membre(auteur)?.nom ?? "") : \(texte)")
    }
}

/// Une « porte » : la carte émaillée utilisée partout.
struct Porte<Contenu: View>: View {
    @Environment(\.colorScheme) private var scheme
    var teinte: Color? = nil
    @ViewBuilder var contenu: Contenu
    var body: some View {
        VStack(alignment: .leading, spacing: 10) { contenu }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(teinte.map { $0.opacity(0.14) } ?? .clear)
                    .background(Theme.porte(scheme), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(.primary.opacity(0.07)))
            .shadow(color: .black.opacity(scheme == .dark ? 0.35 : 0.07), radius: 14, y: 8)
    }
}

/// Un titre de section avec, à droite, une action facultative.
struct TitreSection<Action: View>: View {
    let titre: String
    @ViewBuilder var action: Action
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(titre).font(Theme.titre(22)).accessibilityAddTraits(.isHeader)
            Spacer()
            action
        }
    }
}
extension TitreSection {
    init(_ titre: String, @ViewBuilder action: () -> Action) { self.titre = titre; self.action = action() }
}
extension TitreSection where Action == EmptyView {
    init(_ titre: String) { self.titre = titre; self.action = EmptyView() }
}

/// Une étiquette de type (Garde, Voyage…).
struct Etiquette: View {
    let texte: String
    var couleur: Color = .secondary
    var body: some View {
        Text(texte).font(.willys(.caption, poids: .bold))
            .padding(.horizontal, 9).padding(.vertical, 3)
            .background(couleur.opacity(0.2), in: Capsule())
            .foregroundStyle(.primary)
    }
}

extension Color {
    /// Une couleur qui change entre le mode clair et le mode sombre.
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(Color(hex: dark)) : UIColor(Color(hex: light)) })
    }
}

/// Le petit point vert « en ligne » sur un aimant, qui respire doucement.
struct PointVert: View {
    @State private var respire = false
    var body: some View {
        Circle().fill(Theme.ok)
            .frame(width: 11, height: 11)
            .overlay(Circle().stroke(.white, lineWidth: 2))
            .scaleEffect(respire ? 1.12 : 0.92)
            .onAppear {
                guard !UIAccessibility.isReduceMotionEnabled else { return }
                withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) { respire = true }
            }
            .accessibilityLabel("en ligne")
    }
}

/// « Loulou regarde aussi le calendrier » : les aimants de ceux qui sont sur le même onglet, en ce moment.
struct IciAussi: View {
    let onglet: String
    let moi: String
    let visites: [Visite]
    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { _ in
            let la = visites.filter { $0.membre != moi && $0.ecran == onglet && Presence.estLa($0) }
            if !la.isEmpty {
                HStack(spacing: 8) {
                    PileAimants(membres: la.map(\.membre), taille: 24)
                        .overlay(alignment: .bottomTrailing) { PointVert().offset(x: 3, y: 3) }
                    Text("\(la.compactMap { Famille.membre($0.membre)?.nom }.formatted(.list(type: .and).locale(Locale(identifier: "fr_BE")))) \(la.count > 1 ? "regardent" : "regarde") aussi")
                        .font(.willys(.footnote, poids: .semibold))
                }
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(Theme.ok.opacity(0.14), in: Capsule())
                .transition(.colle)
            }
        }
    }
}

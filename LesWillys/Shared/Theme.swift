import SwiftUI

/// L'habillage « porte du frigo » : fond émaillé, aimants de couleur, post-it manuscrits.
enum Theme {
    static let accent = Color(hex: 0xE2973A)
    static let postit = Color(hex: 0xFFF6C9)
    static let postitRose = Color(hex: 0xFFE3D6)
    static let encrePostit = Color(hex: 0x3B3110)
    static let ok = Color(hex: 0x2F8A5B)
    static let alerte = Color(hex: 0xC0582F)

    static func emaille(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0x121A22) : Color(hex: 0xE9EFEC)
    }
    static func porte(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0x1A242E) : Color(hex: 0xF6F9F7)
    }

    /// Écriture manuscrite : on utilise une police ronde du système, en attendant
    /// d'embarquer « Gochi Hand » (licence OFL, à ajouter au projet si on veut l'identique).
    static func main(_ taille: CGFloat) -> Font {
        if UIFont(name: "GochiHand-Regular", size: taille) != nil { return .custom("GochiHand-Regular", size: taille) }
        return .system(size: taille, weight: .medium, design: .rounded).italic()
    }
    static func titre(_ taille: CGFloat) -> Font { .system(size: taille, weight: .heavy, design: .rounded) }
}

/// Un aimant : rond, de la couleur du membre, avec son initiale (ou sa photo).
struct Aimant: View {
    let membre: String
    var taille: CGFloat = 36
    var photo: Data? = nil

    var body: some View {
        let m = Famille.membre(membre)
        ZStack {
            Circle().fill(m?.couleur ?? .gray)
            if let photo, let ui = UIImage(data: photo) {
                Image(uiImage: ui).resizable().scaledToFill().clipShape(Circle())
            } else {
                Text(m?.initiale ?? "?")
                    .font(.system(size: taille * 0.42, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.2), radius: 0, y: 1)
            }
        }
        .frame(width: taille, height: taille)
        .overlay(Circle().strokeBorder(.black.opacity(0.12), lineWidth: 1))
        .shadow(color: .black.opacity(0.18), radius: 2, y: 2)
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
    }
}

/// Un post-it légèrement de travers, avec l'aimant de son auteur en guise de punaise.
struct PostIt: View {
    let texte: String
    let auteur: String
    var sousTitre: String = ""
    var rose = false
    var taillePolice: CGFloat = 22

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(texte).font(Theme.main(taillePolice)).foregroundStyle(Theme.encrePostit)
                .frame(maxWidth: .infinity, alignment: .leading)
            if !sousTitre.isEmpty {
                Text(sousTitre).font(.caption).foregroundStyle(Theme.encrePostit.opacity(0.7))
            }
        }
        .padding(.top, 18).padding([.horizontal, .bottom], 14)
        .background(rose ? Theme.postitRose : Theme.postit, in: RoundedRectangle(cornerRadius: 4))
        .overlay(alignment: .top) { Aimant(membre: auteur, taille: 26).offset(y: -12) }
        .rotationEffect(.degrees(rose ? 1 : -1.2))
        .shadow(color: .black.opacity(0.2), radius: 8, y: 6)
    }
}

/// Une « porte » : la carte blanche émaillée utilisée partout.
struct Porte<Contenu: View>: View {
    @Environment(\.colorScheme) private var scheme
    var teinte: Color? = nil
    @ViewBuilder var contenu: Contenu
    var body: some View {
        VStack(alignment: .leading, spacing: 10) { contenu }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background {
                RoundedRectangle(cornerRadius: 18)
                    .fill(teinte.map { $0.opacity(0.16) } ?? .clear)
                    .background(Theme.porte(scheme), in: RoundedRectangle(cornerRadius: 18))
            }
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(.secondary.opacity(0.2)))
            .shadow(color: .black.opacity(0.08), radius: 10, y: 6)
    }
}

/// Une étiquette de type (Garde, Voyage…).
struct Etiquette: View {
    let texte: String
    var couleur: Color = .secondary
    var body: some View {
        Text(texte).font(.caption.bold())
            .padding(.horizontal, 9).padding(.vertical, 2)
            .background(couleur.opacity(0.22), in: Capsule())
    }
}

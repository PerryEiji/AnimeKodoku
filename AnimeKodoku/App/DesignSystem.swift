import SwiftUI

enum Design {
    static let accent = Color(red: 0.60, green: 0.52, blue: 1)
    static let darkBase = Color.black
    static let darkSecondary = Color(red: 28/255, green: 28/255, blue: 30/255)
    static let radius: CGFloat = 12
    static let spacing: CGFloat = 16
    static let grid = [GridItem(.adaptive(minimum: 140, maximum: 220), spacing: 16, alignment: .top)]
}
@MainActor struct CoverArt: View {
    let anime: Anime
    var banner = false
    var body: some View {
        AsyncImage(url: banner ? anime.bannerUrl ?? anime.coverUrl : anime.coverUrl) { phase in
            if let image = phase.image { image.resizable().scaledToFill() }
            else {
                ZStack {
                    LinearGradient(colors: [Design.accent.opacity(0.45), Color.indigo.opacity(0.2), Design.darkSecondary], startPoint: .topLeading, endPoint: .bottomTrailing)
                    Image(systemName: "play.rectangle.on.rectangle.fill").font(.largeTitle).foregroundStyle(.white.opacity(0.65))
                }
            }
        }
        .accessibilityHidden(true)
    }
}
@MainActor struct AnimeCard: View {
    let anime: Anime
    var selected = false
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Color.clear.aspectRatio(2/3, contentMode: .fit)
                .overlay { CoverArt(anime: anime) }.clipped().clipShape(RoundedRectangle(cornerRadius: Design.radius))
                .overlay(alignment: .topTrailing) { if selected { Image(systemName: "checkmark.circle.fill").font(.title2).foregroundStyle(.white, Design.accent).padding(8) } }
            Text(anime.title).font(.headline).lineLimit(3)
            Text(anime.tags.joined(separator: " · ")).font(.caption).foregroundStyle(.secondary).lineLimit(2)
        }
        .contentShape(Rectangle()).accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}
@MainActor struct AnimeRow: View {
    let anime: Anime
    var body: some View {
        HStack(spacing: 12) {
            CoverArt(anime: anime).frame(width: 54, height: 76).clipped().clipShape(RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 4) { Text(anime.title).font(.headline); Text(anime.tags.joined(separator: " · ")).font(.caption).foregroundStyle(.secondary) }
            Spacer()
        }.accessibilityElement(children: .combine)
    }
}
@MainActor struct EmptyState: View {
    let title: String
    let message: String
    var symbol = "rectangle.stack"
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: symbol).font(.largeTitle).foregroundStyle(Design.accent)
            Text(title).font(.title2.bold()).multilineTextAlignment(.center)
            Text(message).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }.padding(32).frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
@MainActor struct ErrorState: View {
    let message: String
    let retry: () -> Void
    var body: some View {
        VStack(spacing: 12) { Label(message, systemImage: "exclamationmark.triangle").foregroundStyle(.secondary); Button("Riprova", action: retry).buttonStyle(.bordered) }.padding().frame(maxWidth: .infinity)
    }
}
@MainActor struct IconButton: View {
    let title: String
    let symbol: String
    let action: () -> Void
    var body: some View { Button(action: action) { Image(systemName: symbol).frame(minWidth: 44, minHeight: 44) }.accessibilityLabel(title).help(title) }
}

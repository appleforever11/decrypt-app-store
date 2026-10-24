import SwiftUI

struct AppArtwork: View {
    let url: URL?
    let size: CGFloat
    var body: some View {
        AsyncImage(url: url) { image in
            image.resizable().scaledToFit()
        } placeholder: {
            RoundedRectangle(cornerRadius: size * 0.22).fill(.quaternary)
                .overlay { Image(systemName: "app.dashed").font(.system(size: size * 0.48)).foregroundStyle(.secondary) }
        }
        .frame(width: size, height: size)
        .clipShape(.rect(cornerRadius: size * 0.22))
        .accessibilityLabel("App Store icon")
    }
}

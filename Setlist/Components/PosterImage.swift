import SwiftUI
import UIKit

enum PosterImageSize {
    case small
    case big
}

struct PosterImage: View {
    let photoData: Data?
    let placeholderType: Int
    let size: PosterImageSize

    var body: some View {
        switch size {
        case .small:
            posterImage
                .resizable()
                .scaledToFill()
                .frame(width: 52, height: 52)
                .scaleEffect(placeholderBleedScale)
                .frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: SetlistRadius.small))

        case .big:
            GeometryReader { proxy in
                posterImage
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .scaleEffect(placeholderBleedScale)
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
            }
        }
    }

    private var posterImage: Image {
        if let image = userImage {
            return Image(uiImage: image)
        }

        return Image("ImgPlaceholder\(normalizedPlaceholderType)\(assetSizeSuffix)")
    }

    private var userImage: UIImage? {
        guard let photoData else { return nil }
        return UIImage(data: photoData)
    }

    /// Figma-exported placeholder PNGs include transparent effect padding.
    /// Bleed only the placeholders so their visible artwork reaches the frame edge.
    private var placeholderBleedScale: CGFloat {
        guard userImage == nil else { return 1 }

        switch size {
        case .big:
            return 1.06
        case .small:
            return (1...3).contains(normalizedPlaceholderType) ? 1.04 : 1
        }
    }

    private var normalizedPlaceholderType: Int {
        min(max(placeholderType, 1), 6)
    }

    private var assetSizeSuffix: String {
        size == .small ? "Small" : "Big"
    }
}

struct PosterOverlay: View {
    let photoData: Data?
    let placeholderType: Int

    var body: some View {
        ZStack {
            PosterImage(
                photoData: photoData,
                placeholderType: placeholderType,
                size: .big
            )

            LinearGradient(
                stops: [
                    .init(color: SetlistColor.backgroundCanvas.opacity(0), location: 0.26),
                    .init(color: SetlistColor.backgroundCanvas, location: 0.72)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .frame(maxWidth: .infinity)
        .frame(height: 476)
        .clipped()
    }
}

#Preview("Poster placeholders") {
    VStack {
        PosterImage(photoData: nil, placeholderType: 1, size: .small)
        PosterOverlay(photoData: nil, placeholderType: 1)
    }
    .background(SetlistColor.backgroundCanvas)
    .preferredColorScheme(.dark)
}

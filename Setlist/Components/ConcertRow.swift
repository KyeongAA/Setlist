import SwiftUI

struct ConcertRow: View {
    let concert: SetlistConcert
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            HStack(spacing: SetlistSpacing.small) {
                PosterImage(
                    photoData: concert.photoData,
                    placeholderType: concert.placeholderType,
                    size: .small
                )

                VStack(alignment: .leading, spacing: SetlistSpacing.small) {
                    Text(concert.title)
                        .setlistTextStyle(.contentSong)
                        .foregroundStyle(SetlistColor.textPrimary)
                        .lineLimit(1)

                    HStack {
                        Text(concert.artist)
                            .setlistTextStyle(.contentArtist)
                            .foregroundStyle(SetlistColor.textPrimary)
                            .lineLimit(1)

                        Spacer()

                        Text(concert.date)
                            .setlistTextStyle(.utilityMetadata)
                            .foregroundStyle(SetlistColor.textTertiary)
                            .frame(width: 61, alignment: .leading)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, SetlistMargin.extraSmall)
            .padding(.vertical, SetlistSpacing.small)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(height: 76)
    }
}

#Preview("Concert row") {
    VStack(spacing: 0) {
        ForEach(SetlistConcert.samples) { concert in
            ConcertRow(concert: concert)
        }
    }
    .padding(.horizontal, SetlistSpacing.medium)
    .background(SetlistColor.backgroundCanvas)
    .preferredColorScheme(.dark)
}

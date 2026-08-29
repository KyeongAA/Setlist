import SwiftUI

enum SongRowAccessory {
    case handle
    case add
    case none
}

struct SongRow: View {
    let song: SetlistSong
    var accessory: SongRowAccessory = .none
    var reorderChanged: ((DragGesture.Value) -> Void)?
    var reorderEnded: (() -> Void)?
    var action: () -> Void = {}

    var body: some View {
        HStack(spacing: 0) {
            Text(song.number)
                .setlistTextStyle(.utilityMetadata)
                .foregroundStyle(SetlistColor.textPrimary)
                .frame(width: 16, alignment: .leading)

            VStack(alignment: .leading, spacing: 0) {
                Text(song.title)
                    .setlistTextStyle(.contentSong)
                    .foregroundStyle(SetlistColor.textPrimary)
                    .lineLimit(1)

                Text(song.artist)
                    .setlistTextStyle(.contentArtist)
                    .foregroundStyle(SetlistColor.textPrimary)
                    .lineLimit(1)
            }
            .padding(.horizontal, SetlistSpacing.small)
            .frame(maxWidth: .infinity, alignment: .leading)

            accessoryView
        }
        .frame(height: accessory == .add ? 68 : 48)
        .overlay(alignment: .bottom) {
            if accessory == .add {
                Rectangle()
                    .fill(SetlistColor.borderDefault)
                    .frame(height: 1)
            }
        }
    }

    @ViewBuilder
    private var accessoryView: some View {
        switch accessory {
        case .handle:
            if let reorderChanged, let reorderEnded {
                handleImage
                    .highPriorityGesture(
                        DragGesture(
                            minimumDistance: SetlistSpacing.xxs,
                            coordinateSpace: .global
                        )
                        .onChanged(reorderChanged)
                        .onEnded { _ in reorderEnded() }
                    )
            } else {
                handleImage
            }
        case .add:
            Button(action: action) {
                Image("IconPlus")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 10, height: 10)
                    .frame(width: 20, height: 20)
                    .background(SetlistColor.brandSecondary)
                    .clipShape(Circle())
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("곡 추가")
        case .none:
            EmptyView()
        }
    }

    private var handleImage: some View {
        Image("IconHandle")
            .resizable()
            .scaledToFit()
            .frame(width: 22, height: 18)
            .frame(width: 48, height: 48)
            .contentShape(Rectangle())
            .accessibilityLabel("순서 변경")
    }
}

#Preview("Song row states") {
    VStack {
        SongRow(song: .sampleSongs[0], accessory: .handle)
        SongRow(song: .sampleSongs[0], accessory: .none)
        SongRow(song: .sampleSongs[0], accessory: .add)
    }
    .padding()
    .background(SetlistColor.backgroundCanvas)
    .preferredColorScheme(.dark)
}

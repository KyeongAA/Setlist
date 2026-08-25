import PhotosUI
import SwiftUI

struct PhotoPickerButton: View {
    @State private var selection: PhotosPickerItem?

    let title: String
    var savePhoto: (Data) -> Void = { _ in }

    var body: some View {
        PhotosPicker(
            selection: $selection,
            matching: .images,
            preferredItemEncoding: .current
        ) {
            SmallButtonLabel(title: title)
        }
        .buttonStyle(.plain)
        .onChange(of: selection) { _, selectedItem in
            guard let selectedItem else { return }

            Task {
                defer { selection = nil }

                guard let data = try? await selectedItem.loadTransferable(type: Data.self) else {
                    return
                }

                savePhoto(data)
            }
        }
    }
}

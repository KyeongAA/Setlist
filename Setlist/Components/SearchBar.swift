import SwiftUI

enum SearchBarState {
    case normal
    case focused
    case filled
}

struct SearchBar: View {
    @Binding var text: String
    let state: SearchBarState
    var clearAction: () -> Void = {}
    var focusChanged: (Bool) -> Void = { _ in }
    var submit: () -> Void = {}

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: SetlistSpacing.xxs) {
            if state != .filled {
                Image("IconSearch")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18, height: 18)
                    .frame(width: 28, height: 28)
            }

            TextField(
                "",
                text: $text,
                prompt: Text("아티스트, 노래 제목 등")
                    .foregroundStyle(SetlistColor.textSecondary)
            )
            .setlistTextStyle(state == .filled ? .bodyPrimary : .bodySecondary)
            .foregroundStyle(
                state == .filled ? SetlistColor.textInverse : SetlistColor.textPrimary
            )
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .submitLabel(.search)
            .focused($isFocused)
            .onSubmit(submit)
            .frame(maxWidth: .infinity, alignment: .leading)

            if state != .normal {
                Button {
                    text = ""
                    clearAction()
                } label: {
                    Image("IconClose")
                        .resizable()
                        .scaledToFit()
                        .rotationEffect(.degrees(45))
                        .frame(width: 10, height: 10)
                        .frame(width: 22, height: 22)
                        .background(SetlistColor.backgroundSubtle)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("검색어 지우기")
            }
        }
        .padding(.horizontal, state == .filled ? SetlistSpacing.medium : SetlistSpacing.small)
        .frame(maxWidth: .infinity)
        .frame(height: 52)
        .background(state == .filled ? SetlistColor.backgroundInverse : .clear)
        .overlay {
            RoundedRectangle(cornerRadius: SetlistRadius.medium)
                .stroke(
                    state == .focused ? SetlistColor.focusRing : SetlistColor.borderDefault,
                    lineWidth: state == .filled ? 0 : 1
                )
        }
        .clipShape(RoundedRectangle(cornerRadius: SetlistRadius.medium))
        .padding(.horizontal, SetlistSpacing.medium)
        .onChange(of: isFocused) { _, newValue in
            focusChanged(newValue)
        }
        .onAppear {
            if state == .focused {
                isFocused = true
            }
        }
    }
}

#Preview("Search bar states") {
    @Previewable @State var query = "에스파"

    VStack(spacing: 28) {
        SearchBar(text: $query, state: .normal)
        SearchBar(text: $query, state: .focused)
        SearchBar(text: $query, state: .filled)
    }
    .padding()
    .background(SetlistColor.backgroundCanvas)
    .preferredColorScheme(.dark)
}

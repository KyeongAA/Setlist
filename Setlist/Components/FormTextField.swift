import SwiftUI

enum FormTextFieldState {
    case normal
    case focused
    case completed
}

struct FormTextField: View {
    @Binding var text: String
    let placeholder: String
    var state: FormTextFieldState = .normal

    @FocusState private var isFocused: Bool

    var body: some View {
        TextField(
            "",
            text: $text,
            prompt: Text(placeholder)
                .foregroundStyle(SetlistColor.textSecondary)
        )
        .setlistTextStyle(.bodySecondary)
        .foregroundStyle(text.isEmpty ? SetlistColor.textSecondary : SetlistColor.textPrimary)
        .focused($isFocused)
        .submitLabel(.done)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(SetlistSpacing.small)
        .frame(height: 48)
        .overlay {
            RoundedRectangle(cornerRadius: SetlistRadius.medium)
                .stroke(showsFocusRing ? SetlistColor.focusRing : SetlistColor.borderDefault, lineWidth: 1)
        }
        .onAppear {
            if state == .focused {
                isFocused = true
            }
        }
        .onChange(of: state) { _, newState in
            if newState == .focused {
                isFocused = true
            }
        }
    }

    private var showsFocusRing: Bool {
        isFocused || state == .focused
    }
}

#Preview("Text field states") {
    @Previewable @State var title = "콘서트명"

    VStack(spacing: 28) {
        FormTextField(text: $title, placeholder: "placeholder", state: .normal)
        FormTextField(text: $title, placeholder: "placeholder", state: .focused)
        FormTextField(text: $title, placeholder: "placeholder", state: .completed)
    }
    .padding()
    .background(SetlistColor.backgroundCanvas)
    .preferredColorScheme(.dark)
}

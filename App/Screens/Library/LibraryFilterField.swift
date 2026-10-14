import SwiftUI

/// Library's own filter, under the title (it used to be the top bar's pill):
/// it filters the grid in place. While it has focus a "This library /
/// Everything" switch shows under it; Everything hands the words to the
/// Search tab.
struct LibraryFilterField: View {
    @Environment(AppModel.self) private var model
    @FocusState private var focused: Bool

    var body: some View {
        @Bindable var model = model
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.mut)
                TextField("", text: $model.searchText, prompt: Text("Filter the library").foregroundStyle(Theme.mut))
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.txt)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .focused($focused)
                    .onSubmit { focused = false }
                if !model.searchText.isEmpty {
                    Button {
                        model.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 17))
                            .foregroundStyle(Theme.mut)
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear filter")
                }
            }
            .padding(.leading, 12)
            .padding(.trailing, 6)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .contentShape(Capsule())
            .glassControl(on: focused)
            if focused {
                LibraryScopeBar(scope: model.searchScope) { scope in
                    if scope == .everything {
                        model.searchQuery = model.searchText
                        focused = false
                        model.tab = .search
                    } else {
                        model.searchScope = .library
                    }
                }
                .transition(.opacity.combined(with: .offset(y: -6)))
            }
        }
        .animation(.snappy(duration: 0.2), value: focused)
        .onChange(of: model.chromeHidden) { if model.chromeHidden { focused = false } }
    }
}

/// "This library / Everything" under the focused filter.
private struct LibraryScopeBar: View {
    let scope: SearchScope
    let pick: (SearchScope) -> Void

    var body: some View {
        HStack(spacing: 4) {
            segment("This library", .library)
            segment("Everything", .everything)
        }
        .padding(4)
        .glassEffect(.regular, in: Capsule())
    }

    private func segment(_ title: String, _ value: SearchScope) -> some View {
        Button {
            pick(value)
        } label: {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(scope == value ? Theme.txt : Theme.mut)
                .frame(maxWidth: .infinity, minHeight: 32)
                .background(scope == value ? Theme.txt.opacity(0.16) : .clear, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

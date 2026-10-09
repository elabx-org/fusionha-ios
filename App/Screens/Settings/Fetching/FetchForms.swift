import SwiftUI
import FusionhaKit

// The add/edit Form sheet of the native card-list Settings panels and its rows.

/// The test verdict (`✓ Connected · SABnzbd 4.5.0 · categories: …` / `✕ message`).
struct FetchTestResultLine: View {
    var testing = false
    let result: ConnectionTestResult?
    var okFallback = "Connection successful"
    var clientLabel: String?

    var body: some View {
        if testing {
            HStack(spacing: 6) {
                ProgressView().controlSize(.mini)
                Text("Testing…").font(.system(size: 12)).foregroundStyle(Theme.mut)
            }
        } else if let result {
            if result.ok {
                VStack(alignment: .leading, spacing: 3) {
                    Label(result.version == nil ? (result.message.isEmpty ? okFallback : result.message) : "Connected",
                          systemImage: "checkmark")
                        .foregroundStyle(Theme.done)
                    if let version = result.version {
                        Text("\(clientLabel ?? "Client") \(version)")
                            .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                            .foregroundStyle(Theme.done)
                            .padding(.horizontal, 6).padding(.vertical, 1)
                            .background(Theme.done.opacity(0.14), in: RoundedRectangle(cornerRadius: 5))
                    }
                    if let cats = result.categories, !cats.isEmpty {
                        Text("categories: \(cats.joined(separator: ", "))")
                            .foregroundStyle(Theme.mut)
                    }
                }
                .font(.system(size: 12, weight: .semibold))
            } else {
                Label(result.message, systemImage: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.danger)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: Sheets

/// The add/edit dialog as a native Form sheet: Cancel / Save in the toolbar,
/// the web's dialog title + description, and an optional Test footer.
struct FetchFormSheet<Content: View>: View {
    let title: String
    var subtitle: String?
    var saveLabel = "Save"
    var canSave = true
    var saving = false
    var onCancel: () -> Void
    var onSave: () -> Void
    @ViewBuilder var content: Content

    var body: some View {
        NavigationStack {
            Form {
                if let subtitle {
                    Section {
                    } header: {
                        Text(subtitle)
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.mut)
                            .textCase(nil)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, -4)
                    }
                }
                content
            }
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    SheetCancelButton(action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if saving {
                        ProgressView()
                    } else {
                        SheetDoneButton(title: saveLabel, action: onSave).disabled(!canSave)
                    }
                }
            }
        }
        .tint(Theme.cyan)
        .presentationDragIndicator(.visible)
    }
}

/// A text field row inside a sheet Form: label on the left, input on the right.
struct FetchTextRow: View {
    let label: String
    @Binding var text: String
    var prompt = ""
    var secure = false
    var mono = false
    var keyboard: UIKeyboardType = .default
    var hint: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            LabeledContent {
                Group {
                    if secure {
                        SecureField(label, text: $text, prompt: Text(prompt))
                    } else {
                        TextField(label, text: $text, prompt: Text(prompt))
                    }
                }
                .font(.system(size: 14, design: mono ? .monospaced : .default))
                .multilineTextAlignment(.trailing)
                .keyboardType(keyboard)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .foregroundStyle(Theme.txt)
            } label: {
                Text(label).font(.system(size: 13.5, weight: .semibold)).foregroundStyle(Theme.txt)
            }
            if let hint {
                Text(hint).font(.system(size: 11.5)).foregroundStyle(Theme.mut)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// A Toggle row with the web's label + description (`.togrow`).
struct FetchToggleRow: View {
    let label: String
    var description: String?
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            FieldLabel(label: label, description: description)
        }
        .tint(Theme.indigo)
    }
}

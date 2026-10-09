import SwiftUI
import UIKit
import WidgetKit
import FusionhaKit

/// The web's Account page (`routes/Account.tsx`, "You"): a centred role-tinted
/// avatar, the name and role badge, then Requests made · Sign-in methods ·
/// Reset cache & reload · Sign out. No page title, like the web.
struct AccountView: View {
    @Environment(AppModel.self) private var model
    @State private var requestCount: Int?
    @State private var showingMethods = false
    @State private var resetting = false
    @State private var signingOut = false
    @State private var toast: CalToast?

    var body: some View {
        ScrollView {
            Group {
                if let me = model.me {
                    content(me)
                } else {
                    CalEmptyState(message: "Loading account…")
                }
            }
            .frame(maxWidth: 420)
            .frame(maxWidth: .infinity)
            .padding(.top, 26)
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .calToast($toast)
        .task { await loadRequests() }
        .sheet(isPresented: $showingMethods) {
            SignInMethodsSheet()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(Theme.panel)
        }
        .task {
            #if DEBUG
            if ProcessInfo.processInfo.environment["FUSIONHA_SCREENSHOT_ACCOUNT"] == "methods" {
                try? await Task.sleep(for: .seconds(1.5))
                showingMethods = true
            }
            #endif
        }
    }

    private func content(_ me: Me) -> some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                AccountAvatar(me: me, size: 74)
                Text(me.displayName)
                    .font(.system(size: 18, weight: .bold))
                    .tracking(-0.18)
                    .foregroundStyle(Theme.txt)
                    .padding(.top, 4)
                RoleBadge(me: me)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 10)
            .padding(.bottom, 26)
            .calReveal(0, stagger: 0.06)

            row {
                Text("Requests made").foregroundStyle(Theme.txt)
                Spacer()
                Text("\(requestCount ?? 0)").fontWeight(.semibold).foregroundStyle(Theme.dim)
            }
            .calReveal(1, stagger: 0.06)

            rowButton("Sign-in methods") { showingMethods = true }
                .calReveal(2, stagger: 0.06)

            rowButton(resetting ? "Resetting…" : "Reset cache & reload") { Task { await resetCache() } }
                .disabled(resetting)
                .calReveal(3, stagger: 0.06)

            row {
                Button("Sign out") {
                    signingOut = true
                    Task { await model.logOut() }
                }
                .buttonStyle(CalButtonStyle(variant: .danger, fullWidth: true))
                .disabled(signingOut)
            }
            .calReveal(4, stagger: 0.06)
        }
    }

    private func row<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        HStack(spacing: 0) { content() }
            .font(.system(size: 13.5))
            .padding(.vertical, 13)
            .padding(.horizontal, 15)
            .frame(maxWidth: .infinity, minHeight: 0, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).strokeBorder(Theme.line))
            .padding(.top, 10)
    }

    private func rowButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13.5, weight: .semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 13)
                .padding(.horizontal, 15)
                .contentShape(Rectangle())
        }
        .buttonStyle(AccountRowButtonStyle())
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).strokeBorder(Theme.line))
        .padding(.top, 10)
    }

    private func loadRequests() async {
        guard let client = model.client else { return }
        if let list = try? await client.requests() { requestCount = list.count }
    }

    /// The iOS form of the web's `resetAppCache`: drop cached responses and artwork
    /// and reload what's on screen. The sign-in and preferences stay.
    private func resetCache() async {
        resetting = true
        URLCache.shared.removeAllCachedResponses()
        await model.loadMe()
        if !model.requestScoped {
            await model.loadLibrary()
            await model.refreshQueue()
        }
        await loadRequests()
        WidgetCenter.shared.reloadAllTimelines()
        resetting = false
        toast = CalToast(message: "Cache cleared and reloaded.")
    }
}

/// The Account sheet the avatar menu opens on the shell (RootView hook).
struct AccountSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            AccountView()
                .background(Theme.bg.ignoresSafeArea())
                .navigationTitle("Account")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        SheetDoneButton { dismiss() }
                    }
                }
        }
    }
}

private struct AccountRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(configuration.isPressed ? Theme.cyan : Theme.txt)
    }
}

// MARK: Avatar + role badge (`access-shared.tsx`)

struct AccountAvatar: View {
    @Environment(AppModel.self) private var model
    let me: Me
    var size: CGFloat = 74
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            Circle().fill(fill)
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Text(me.displayInitials)
                    .font(.system(size: size * 24 / 74, weight: .bold))
                    .foregroundStyle(me.roleTone == .other ? Theme.mut : Theme.txt)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .shadow(color: .black.opacity(0.55), radius: 14, y: 10)
        .accessibilityHidden(true)
        .task(id: me.thumb) {
            // The same-origin avatar proxy; initials when it fails.
            guard me.thumb != nil, let client = model.client,
                  let data = try? await client.avatar(userId: me.id) else { image = nil; return }
            image = UIImage(data: data)
        }
    }

    private var fill: AnyShapeStyle {
        switch me.roleTone {
        case .admin:
            return AnyShapeStyle(LinearGradient(colors: [Color(hex: 0x494BAE), Theme.indigo],
                                                startPoint: .topLeading, endPoint: .bottomTrailing))
        case .manager:
            return AnyShapeStyle(LinearGradient(colors: [Theme.cyan, Color(hex: 0x18949F)],
                                                startPoint: .topLeading, endPoint: .bottomTrailing))
        case .requestor:
            return AnyShapeStyle(LinearGradient(colors: [Theme.miss, Color(hex: 0xAC6F08)],
                                                startPoint: .topLeading, endPoint: .bottomTrailing))
        case .other:
            return AnyShapeStyle(Theme.panel2)
        }
    }
}

struct RoleBadge: View {
    let me: Me

    private var tint: Color {
        switch me.roleTone {
        case .admin: return Theme.indigo
        case .manager: return Theme.cyan
        case .requestor: return Theme.miss
        case .other: return Theme.mut
        }
    }

    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(tint).frame(width: 6, height: 6)
            Text(me.accountRoleName ?? "No role")
        }
        .font(.system(size: 10.5, weight: .bold))
        .foregroundStyle(tint)
        .padding(.horizontal, 9)
        .padding(.vertical, 3)
        .background(me.roleTone == .other ? Theme.panel2 : tint.opacity(me.roleTone == .manager ? 0.15 : 0.16),
                    in: Capsule())
    }
}

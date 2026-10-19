import SwiftUI

/// Account sheet › Notifications for a requester: the same inline section as
/// the You tab (web `/account`), never Settings.
struct RequesterNotificationsPage: View {
    @State private var toast: CalToast?

    var body: some View {
        ScrollView {
            RequesterNotificationsSection { message, ok in toast = CalToast(message: message, isError: !ok) }
                .frame(maxWidth: 420)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
        }
        .scrollContentBackground(.hidden)
        .calToast($toast)
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
    }
}

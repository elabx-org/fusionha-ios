import SwiftUI
import FusionhaKit

struct CastCard: View {
    let member: CastMember

    private var initials: String {
        let parts = member.name.split(separator: " ")
        let letters = parts.count >= 2 ? [parts[0].first, parts[1].first].compactMap { $0 } : Array(member.name.prefix(2))
        return String(letters).uppercased()
    }

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                LinearGradient(colors: [Theme.i1, Theme.i2], startPoint: .topLeading, endPoint: .bottomTrailing)
                Text(initials).font(.system(size: 22, weight: .bold)).foregroundStyle(Theme.onTint(Theme.i1))
                if let url = member.profileUrl.flatMap({ TMDBImage.resized($0, to: "h632") }) {
                    DiscoverArt(url: url)
                }
            }
            .frame(width: 80, height: 80)
            .clipShape(Circle())
            Text(member.name).font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.txt)
                .multilineTextAlignment(.center).lineLimit(2)
            if let character = member.character, !character.isEmpty {
                Text(character).font(.system(size: 12)).foregroundStyle(Theme.mut)
                    .multilineTextAlignment(.center).lineLimit(2)
            }
        }
        .frame(width: 96)
    }
}

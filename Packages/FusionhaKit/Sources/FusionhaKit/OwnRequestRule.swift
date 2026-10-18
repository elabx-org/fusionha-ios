import Foundation

/// Who may decide a request the viewer made themselves. Since fusionha
/// 0.4.214 the server no longer refuses an admin's own request
/// (`own_request` 403), so an admin approves, declines and adjusts it like
/// anyone else's; every other approver still leaves it to another approver.
public enum OwnRequestRule {
    public static func isOwn(_ r: MediaRequest, viewerId: Int?) -> Bool {
        viewerId != nil && r.userId == viewerId
    }

    /// True when the viewer can't decide this request.
    public static func locked(_ r: MediaRequest, viewerId: Int?, viewerIsAdmin: Bool) -> Bool {
        !viewerIsAdmin && isOwn(r, viewerId: viewerId)
    }
}

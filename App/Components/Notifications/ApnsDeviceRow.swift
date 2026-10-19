import SwiftUI
import FusionhaKit

/// One "Other iOS devices" row (web `OtherDevicesSection`): name, when it was
/// last active, and a remove button. The caller confirms the removal.
struct ApnsDeviceRow: View {
    let device: ApnsDevice
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "iphone").font(.system(size: 16)).foregroundStyle(Theme.mut).frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 13.5, weight: .semibold)).foregroundStyle(Theme.txt).lineLimit(1)
                Text("fusionha app · \(device.environment) · active \(FetchFormat.ago(device.lastSuccessAt ?? device.lastSeenAt ?? device.createdAt))")
                    .font(.system(size: 11.5)).foregroundStyle(Theme.mut).lineLimit(1)
            }
            Spacer(minLength: 0)
            FetchIconButton(systemName: "trash", label: "Remove \(device.deviceName ?? "device")", danger: true,
                            action: onRemove)
        }
        .padding(.vertical, 10)
    }

    private var name: String {
        if let n = device.deviceName, !n.isEmpty { return n }
        return "iPhone"
    }
}

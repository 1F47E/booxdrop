import SwiftUI

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "cable.connector")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Connect your device")
                .font(.title2)
            Text("Plug in via USB and set transfer mode to MTP")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

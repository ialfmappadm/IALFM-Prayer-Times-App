#if os(watchOS)
import SwiftUI

struct NotificationsPage: View {
    @ObservedObject private var app = AppState.shared
    var body: some View {
        List {
            if app.announcements.isEmpty {
                Text("No announcements")
                    .font(.footnote).foregroundStyle(.secondary)
            } else {
                ForEach(app.announcements) { a in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(a.title).font(.headline)
                        Text(a.text).font(.footnote)
                            .foregroundStyle(.secondary)
                        if let when = a.when {
                            Text(when.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption2).foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .navigationTitle("Notifications")
    }
}
#endif
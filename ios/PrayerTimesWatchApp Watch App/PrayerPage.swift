#if os(watchOS)
import SwiftUI

struct PrayerPage: View {
    @ObservedObject private var app = AppState.shared

    // Fallback table in case dayTimes hasn't arrived yet
    private var table: [(String,String)] {
        if app.dayTimes.isEmpty {
            return [("Fajr","—"), ("Dhuhr","—"), ("Asr","—"), ("Maghrib","—"), ("Isha","—")]
        } else {
            // Render in a consistent order
            let order = ["Fajr","Dhuhr","Asr","Maghrib","Isha"]
            return order.compactMap { name in
                guard let t = app.dayTimes[name] else { return nil }
                return (name, t)
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                HStack { Spacer(); Text("Prayer").font(.headline).opacity(0.85) }

                Text("Next Prayer").font(.footnote).foregroundStyle(.secondary)

                Text(app.nextPrayer.isEmpty ? "—" : app.nextPrayer)
                    .font(.title2).fontWeight(.semibold)

                LiveCountdown(targetTs: app.targetTs)
                    .padding(.top, 2)

                VStack(spacing: 6) {
                    ForEach(Array(table.enumerated()), id: \.offset) { _, row in
                        HStack {
                            Text(row.0)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                            Spacer(minLength: 8)
                            Text(row.1)
                                .font(.subheadline).monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
                .padding(.top, 6)
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
    }
}

struct LiveCountdown: View {
    let targetTs: TimeInterval

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { ctx in
            let rem = max(0, targetTs - ctx.date.timeIntervalSince1970)
            let m = Int(rem / 60), s = Int(rem.truncatingRemainder(dividingBy: 60))
            Label(String(format: "%02d:%02d", m, s), systemImage: "timer")
                .font(.headline)
                .foregroundStyle(.tint)
        }
    }
}
#endif
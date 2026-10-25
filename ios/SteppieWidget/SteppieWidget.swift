import SwiftUI
import WidgetKit

struct TrackEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct TrackProvider: TimelineProvider {
    func placeholder(in context: Context) -> TrackEntry {
        TrackEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (TrackEntry) -> Void) {
        completion(TrackEntry(date: .now, snapshot: WidgetSnapshot.load() ?? .placeholder))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TrackEntry>) -> Void) {
        let entry = TrackEntry(date: .now, snapshot: WidgetSnapshot.load() ?? .placeholder)
        // The app reloads timelines whenever steps change; this is only a fallback.
        completion(Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(30 * 60))))
    }
}

/// Stadium lane used by the widget, same geometry as the app's track.
struct WidgetTrack: Shape {
    func path(in rect: CGRect) -> Path {
        Path(roundedRect: rect, cornerRadius: rect.height / 2, style: .continuous)
    }
}

struct SteppieWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TrackEntry

    var body: some View {
        switch family {
        case .accessoryCircular: circular
        case .accessoryRectangular: rectangular
        case .systemMedium: medium
        default: small
        }
    }

    private var s: WidgetSnapshot { entry.snapshot }
    private var done: Bool { s.steps >= s.goal }

    private var small: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack {
                WidgetTrack().stroke(Palette.lane, lineWidth: 10)
                WidgetTrack().trim(from: 0, to: s.progress)
                    .stroke(done ? Palette.volt : .white, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                Text(s.steps.formatted())
                    .font(BrandFont.numerals(30))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.6)
            }
            .frame(height: 64)
            Spacer(minLength: 0)
            Text(done ? "Goal hit" : "\(s.remaining.formatted()) to go")
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(.white)
            if let stake = s.stakeLabel {
                Text("\(stake) on the line")
                    .font(BrandFont.label(12))
                    .textCase(.uppercase)
                    .foregroundStyle(Palette.onFieldSecondary)
            }
        }
        .containerBackground(for: .widget) { Palette.field }
    }

    private var medium: some View {
        HStack(spacing: 10) {
            SteppieView(mood: done ? .cheer : .happy, pose: done ? .cheer : .idle, mane: s.maneLevel ?? 2, animated: false)
                .frame(width: 92, height: 106)
            VStack(alignment: .leading, spacing: 8) {
                Text(s.line ?? (done ? "Goal hit. That's how lions walk." : "\(s.remaining.formatted()) to go. You've got this."))
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(Palette.cobalt)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .lineLimit(3)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(s.steps.formatted()).font(BrandFont.numerals(28)).foregroundStyle(.white)
                    Text("of \(s.goal.formatted())").font(.caption.weight(.semibold)).foregroundStyle(Palette.onFieldSecondary)
                }
                ProgressView(value: s.progress)
                    .tint(done ? Palette.volt : .white)
            }
            Spacer(minLength: 0)
        }
        .containerBackground(for: .widget) { Palette.field }
    }

    private var circular: some View {
        Gauge(value: s.progress) {
            Image(systemName: "figure.walk")
        } currentValueLabel: {
            Text(compact(s.steps)).font(BrandFont.numerals(15))
        }
        .gaugeStyle(.accessoryCircular)
        .containerBackground(for: .widget) { Color.clear }
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(done ? "Goal hit" : "\(s.remaining.formatted()) to go").font(.headline)
            Gauge(value: s.progress) { EmptyView() }.gaugeStyle(.accessoryLinearCapacity)
            if let stake = s.stakeLabel { Text("\(stake) on the line").font(.caption2) }
        }
        .containerBackground(for: .widget) { Color.clear }
    }

    private func compact(_ n: Int) -> String {
        n >= 10_000 ? String(format: "%.0fk", Double(n) / 1000) : String(format: "%.1fk", Double(n) / 1000)
    }
}

struct SteppieTrackWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "SteppieTrack", provider: TrackProvider()) { entry in
            SteppieWidgetView(entry: entry)
        }
        .configurationDisplayName("Today's track")
        .description("Your steps, what's left, and what's on the line.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
    }
}

@main
struct SteppieWidgetBundle: WidgetBundle {
    var body: some Widget {
        SteppieTrackWidget()
    }
}

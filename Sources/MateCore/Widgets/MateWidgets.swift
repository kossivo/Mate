import SwiftUI
import WidgetKit
import AppIntents

public struct MateWidgetEntry: TimelineEntry {
    public let date: Date
    public let nextCommitment: TimeBlock?
    public let topTasks: [TaskItem]

    public init(date: Date, nextCommitment: TimeBlock? = nil, topTasks: [TaskItem] = []) {
        self.date = date
        self.nextCommitment = nextCommitment
        self.topTasks = topTasks
    }
}

public struct MateTimelineProvider: TimelineProvider {
    public init() {}

    public func placeholder(in context: Context) -> MateWidgetEntry {
        MateWidgetEntry(
            date: Date(),
            nextCommitment: TimeBlock(
                title: "Team Sync",
                startTime: Date().addingTimeInterval(1800),
                endTime: Date().addingTimeInterval(3600),
                category: "Work"
            ),
            topTasks: [
                TaskItem(title: "Finish slide deck", priority: .high, status: .planned),
                TaskItem(title: "Call Mum", priority: .medium, status: .planned)
            ]
        )
    }

    public func getSnapshot(in context: Context, completion: @escaping (MateWidgetEntry) -> Void) {
        completion(placeholder(in: context))
    }

    public func getTimeline(in context: Context, completion: @escaping (Timeline<MateWidgetEntry>) -> Void) {
        let entry = placeholder(in: context)
        // Refresh every 30 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date().addingTimeInterval(1800)
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

public struct MateSmallWidgetView: View {
    public let entry: MateWidgetEntry

    public init(entry: MateWidgetEntry) {
        self.entry = entry
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("Next Up", systemImage: "clock.badge.fill")
                    .font(.caption2.bold())
                    .foregroundStyle(.tint)
                Spacer()
            }

            if let next = entry.nextCommitment {
                Text(next.title)
                    .font(.subheadline.bold())
                    .lineLimit(2)

                Text(next.startTime.formatted(date: .omitted, time: .shortened))
                    .font(.title3.bold())
                    .foregroundStyle(.primary)

                if let cat = next.category {
                    Text(cat)
                        .font(.caption2.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.15))
                        .foregroundStyle(.blue)
                        .clipShape(Capsule())
                }
            } else {
                Text("All clear today!")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
    }
}

public struct MateMediumWidgetView: View {
    public let entry: MateWidgetEntry

    public init(entry: MateWidgetEntry) {
        self.entry = entry
    }

    public var body: some View {
        HStack(spacing: 16) {
            // Left: Next commitment
            VStack(alignment: .leading, spacing: 6) {
                Label("Next Commitment", systemImage: "clock.fill")
                    .font(.caption2.bold())
                    .foregroundStyle(.blue)

                if let next = entry.nextCommitment {
                    Text(next.title)
                        .font(.body.bold())
                        .lineLimit(2)
                    Text(next.startTime.formatted(date: .omitted, time: .shortened))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text("No events pending")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            // Right: Top Tasks
            VStack(alignment: .leading, spacing: 6) {
                Label("Priorities", systemImage: "checklist")
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)

                ForEach(entry.topTasks.prefix(2)) { task in
                    HStack(spacing: 6) {
                        Image(systemName: "circle")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(task.title)
                            .font(.caption.bold())
                            .lineLimit(1)
                    }
                }
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
    }
}

public struct MateWidgets: Widget {
    public let kind: String = "MateWidgets"

    public init() {}

    public var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MateTimelineProvider()) { entry in
            MateWidgetEntryView(entry: entry)
                .containerBackground(MateTheme.background, for: .widget)
        }
        .configurationDisplayName("Mate Productivity")
        .description("Glance at your next commitment and priority tasks.")
        #if os(iOS)
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryCircular])
        #else
        .supportedFamilies([.systemSmall, .systemMedium])
        #endif
    }
}

public struct MateWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    public let entry: MateWidgetEntry

    public init(entry: MateWidgetEntry) {
        self.entry = entry
    }

    public var body: some View {
        switch family {
        case .systemSmall:
            MateSmallWidgetView(entry: entry)
        case .systemMedium:
            MateMediumWidgetView(entry: entry)
        #if os(iOS)
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.nextCommitment?.title ?? "Mate")
                    .font(.headline)
                    .lineLimit(1)
                Text(entry.nextCommitment?.startTime.formatted(date: .omitted, time: .shortened) ?? "No commitments")
                    .font(.caption)
            }
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "clock.badge.checkmark")
                    .font(.title2)
            }
        #endif
        default:
            MateSmallWidgetView(entry: entry)
        }
    }
}

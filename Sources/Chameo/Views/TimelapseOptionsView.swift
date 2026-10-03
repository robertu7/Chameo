import SwiftUI

struct TimelapseOptionsView: View {
    @ObservedObject var export: TimelapseExportController
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            optionRow(L10n.string("Date range")) {
                TimelapseMenuField(title: L10n.string("Date range"), value: export.options.range.title) {
                    Picker(L10n.string("Date range"), selection: optionBinding(\.range)) {
                        ForEach(TimelapseDateRange.allCases) { range in
                            Text(range.title).tag(range)
                        }
                    }
                    .pickerStyle(.inline)
                }
            }
            periodControls
            Divider()
            optionRow(L10n.string("Playback speed")) {
                TimelapseMenuField(title: L10n.string("Playback speed"),
                                  value: L10n.format("%lld photos/sec", Int64(export.options.speed.rawValue))) {
                    Picker(L10n.string("Playback speed"), selection: optionBinding(\.speed)) {
                        ForEach(TimelapsePlaybackSpeed.allCases) { speed in
                            Text(L10n.format("%lld photos/sec", Int64(speed.rawValue))).tag(speed)
                        }
                    }
                    .pickerStyle(.inline)
                }
            }
            Divider()
        }
        .font(.system(size: 12))
        .multilineTextAlignment(.leading)
        .disabled(!export.canEditOptions)
    }

    private func optionRow<Control: View>(_ title: String, @ViewBuilder control: () -> Control) -> some View {
        HStack(spacing: 16) {
            Text(title)
            Spacer(minLength: 0)
            control().frame(width: 170)
        }
        .frame(minHeight: 40)
    }

    @ViewBuilder
    private var periodControls: some View {
        switch export.options.range {
        case .allPhotos: EmptyView()
        case .month, .year:
            let periods = export.periods(for: export.options.range)
            if periods.isEmpty {
                Text(L10n.string("No dated photos are available."))
                    .font(.caption).foregroundStyle(.secondary).padding(.bottom, 8)
            } else {
                optionRow(export.options.range.title) {
                    TimelapseMenuField(title: export.options.range.title, value: periodTitle(periodBinding.wrappedValue)) {
                        Picker(export.options.range.title, selection: periodBinding) {
                            ForEach(periods, id: \.self) { date in
                                Text(periodTitle(date)).tag(date)
                            }
                        }
                        .pickerStyle(.inline)
                    }
                }
            }
        }
    }

    private var periodBinding: Binding<Date> {
        Binding(get: {
            export.options.interval(calendar: export.calendar)?.start ?? export.options.period
        }, set: { date in
            var options = export.options
            options.period = date
            export.updateOptions(options)
        })
    }

    private func periodTitle(_ date: Date) -> String {
        var style = Date.FormatStyle(date: .omitted, time: .omitted, locale: locale,
                                    calendar: export.calendar, timeZone: export.calendar.timeZone).year()
        if export.options.range == .month { style = style.month(.wide) }
        return date.formatted(style)
    }

    private func optionBinding<Value>(_ keyPath: WritableKeyPath<TimelapseExportOptions, Value>) -> Binding<Value> {
        Binding(get: { export.options[keyPath: keyPath] }, set: { value in
            var options = export.options
            options[keyPath: keyPath] = value
            export.updateOptions(options)
        })
    }
}

/// A native menu with the reference's single-chevron, full-width field.
private struct TimelapseMenuField<Content: View>: View {
    let title: String
    let value: String
    @ViewBuilder var content: () -> Content
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.colorSchemeContrast) private var contrast
    @FocusState private var isFocused: Bool
    @State private var isHovered = false

    var body: some View {
        Menu(content: content) {
            HStack(spacing: 8) {
                Text(value).lineLimit(1)
                Spacer(minLength: 0)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .frame(height: 26)
            .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 6))
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(isFocused ? Color.accentColor : Color.primary.opacity(contrast == .increased ? 0.5 : 0.16),
                                  lineWidth: isFocused ? 2 : 0.7)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 6).fill(.primary.opacity(isHovered ? 0.04 : 0))
            }
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .focused($isFocused)
        .onHover { isHovered = $0 }
        .opacity(isEnabled ? 1 : 0.5)
        .accessibilityLabel(title)
        .accessibilityValue(value)
    }
}

import SwiftUI
import TodoCore

struct ChoiceOption<Value: Hashable>: Identifiable {
    let value: Value
    let title: String
    var subtitle: String = ""
    var symbol: String = ""
    var color: Color? = nil
    var id: Value { value }
}

struct ChoiceField<Value: Hashable>: View {
    let title: String
    var symbol: String = ""
    @Binding var selection: Value
    let options: [ChoiceOption<Value>]
    @State private var showing = false
    @FocusState private var focused: Value?
    private var selected: ChoiceOption<Value>? { options.first { $0.value == selection } }

    var body: some View {
        HStack(spacing: 16) {
            FormLabel(title: title, symbol: symbol)
            Spacer(minLength: 4)
            Button { showing.toggle() } label: {
                HStack(spacing: 9) {
                    if let color = selected?.color { Circle().fill(color).frame(width: 7, height: 7) }
                    Text(selected?.title ?? "请选择").lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "chevron.up.chevron.down").font(.system(size: 9, weight: .semibold)).foregroundStyle(Style.accentSoft)
                }.font(.system(size: 12, weight: .medium)).padding(.horizontal, 12).frame(height: 37)
                    .background(Style.surfaceMuted, in: RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(showing ? Style.orangeFill : Style.border))
            }.buttonStyle(ElasticButtonStyle(pressedScale: 0.98, hoverScale: 1))
                .frame(width: 230).disabled(options.isEmpty)
                .accessibilityLabel(title).accessibilityValue(selected?.title ?? "请选择")
                .popover(isPresented: $showing, arrowEdge: .bottom) { menu }
        }
    }

    private var menu: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary).padding(.horizontal, 10).padding(.top, 5)
            ScrollViewReader { reader in
                ScrollView {
                    VStack(spacing: 3) {
                        ForEach(options) { option in
                            Button { selection = option.value; showing = false } label: {
                                HStack(spacing: 10) {
                                    if let color = option.color { Circle().fill(color).frame(width: 8, height: 8) }
                                    else if !option.symbol.isEmpty {
                                        Image(systemName: option.symbol).frame(width: 18).foregroundStyle(Style.orange)
                                    }
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(option.title).font(.system(size: 12, weight: selection == option.value ? .semibold : .regular))
                                        if !option.subtitle.isEmpty { Text(option.subtitle).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(2) }
                                    }.frame(maxWidth: .infinity, alignment: .leading)
                                    Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)).foregroundStyle(Style.orange)
                                        .opacity(selection == option.value ? 1 : 0)
                                }.padding(.horizontal, 11).frame(minHeight: 40).padding(.vertical, option.subtitle.isEmpty ? 0 : 5)
                            }.buttonStyle(ChoiceRowStyle(selected: selection == option.value, highlighted: focused == option.value))
                                .focusable().focusEffectDisabled().focused($focused, equals: option.value).id(option.value)
                                .accessibilityAddTraits(selection == option.value ? [.isSelected] : [])
                        }
                    }.padding(2)
                }.frame(height: min(CGFloat(options.count) * (options.contains { !$0.subtitle.isEmpty } ? 57 : 43) + 4, 310))
                    .onAppear { focused = selection; reader.scrollTo(selection, anchor: .center) }
                    .onChange(of: focused) { _, value in if let value { reader.scrollTo(value, anchor: .center) } }
            }
        }.padding(10).frame(width: 272).foregroundStyle(Style.ink).background(Style.surface)
            .onExitCommand { showing = false }
            .onMoveCommand { direction in
                guard direction == .up || direction == .down, !options.isEmpty else { return }
                let index = options.firstIndex { $0.value == (focused ?? selection) } ?? 0
                focused = options[min(max(index + (direction == .down ? 1 : -1), 0), options.count - 1)].value
            }
            .onKeyPress(.return) {
                if let focused { selection = focused; showing = false; return .handled }
                return .ignored
            }
    }
}

struct ChoiceRowStyle: ButtonStyle {
    var selected = false
    var highlighted = false
    @State private var hovered = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.contentShape(RoundedRectangle(cornerRadius: 9))
            .background(selected ? Style.orangeTint : hovered || highlighted || configuration.isPressed ? Style.surfaceMuted : Style.surface, in: RoundedRectangle(cornerRadius: 9))
            .onHover { hovered = $0 }
    }
}

struct FormLabel: View {
    let title: String
    var symbol: String = ""
    var body: some View {
        HStack(spacing: 9) {
            if !symbol.isEmpty { Image(systemName: symbol).foregroundStyle(Style.accentSoft).frame(width: 17) }
            Text(title).fixedSize()
        }.font(.system(size: 12, weight: .medium)).foregroundStyle(Style.ink)
    }
}

struct BrandToggleStyle: ToggleStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        Button { configuration.isOn.toggle() } label: {
            HStack {
                configuration.label.font(.system(size: 12, weight: .medium)).foregroundStyle(Style.ink)
                Spacer()
                Capsule().fill(configuration.isOn ? Style.accentFill : Style.surfaceMuted)
                    .overlay(Capsule().strokeBorder(Style.border.opacity(configuration.isOn ? 0 : 1)))
                    .overlay(alignment: configuration.isOn ? .trailing : .leading) {
                        Circle().fill(configuration.isOn ? Style.orangeFill : Style.accentSoft).frame(width: 17, height: 17).padding(3)
                    }.frame(width: 40, height: 23)
            }.contentShape(Rectangle())
        }.buttonStyle(ElasticButtonStyle(pressedScale: 0.995, hoverScale: 1))
            .accessibilityValue(configuration.isOn ? "开启" : "关闭")
            .opacity(enabled ? 1 : 0.45).animation(reduceMotion ? nil : Motion.press, value: configuration.isOn)
    }
}

struct PriorityField: View {
    @Binding var selection: Priority
    var body: some View {
        HStack {
            FormLabel(title: "重要程度", symbol: "flag")
            Spacer()
            HStack(spacing: 3) {
                ForEach(Priority.allCases, id: \.self) { priority in
                    Button { selection = priority } label: {
                        HStack(spacing: 5) {
                            if priority == .important { Image(systemName: "flag.fill").font(.system(size: 10)).foregroundStyle(Style.orange) }
                            Text(priority.title).font(.system(size: 12, weight: selection == priority ? .semibold : .regular))
                        }.frame(width: 72, height: 31)
                            .background(selection == priority ? Style.surface : .clear, in: RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(selection == priority ? Style.border : .clear))
                    }.buttonStyle(ElasticButtonStyle(pressedScale: 0.97, hoverScale: 1))
                        .accessibilityLabel("\(priority.title)优先级").accessibilityAddTraits(selection == priority ? [.isSelected] : [])
                }
            }.padding(3).background(Style.surfaceMuted, in: RoundedRectangle(cornerRadius: 11))
        }
    }
}

struct DateTimeField: View {
    let title: String
    @Binding var selection: Date
    var includesTime = true
    var minimum: Date? = nil
    @State private var showDate = false
    @State private var showTime = false

    var body: some View {
        HStack(spacing: 8) {
            FormLabel(title: title)
            Spacer(minLength: 12)
            Button { showDate.toggle() } label: {
                HStack(spacing: 8) {
                    Image(systemName: "calendar").foregroundStyle(Style.orange)
                    Text(DateText.string(selection, "yyyy年M月d日")).monospacedDigit()
                    Image(systemName: "chevron.down").font(.system(size: 8, weight: .semibold)).foregroundStyle(Style.accentSoft)
                }.font(.system(size: 12, weight: .medium)).padding(.horizontal, 11).frame(height: 37)
                    .background(Style.surfaceMuted, in: RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(showDate ? Style.orangeFill : Style.border))
            }.accessibilityLabel("\(title)日期").accessibilityValue(DateText.string(selection, "yyyy年M月d日"))
                .popover(isPresented: $showDate, arrowEdge: .bottom) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("选择\(title)日期").font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
                        MonthCalendar(selection: Binding(get: { selection }, set: { day in
                            selection = DateSelection.replacingDay(in: selection, with: day); showDate = false
                        }), minimum: minimum)
                        Divider().overlay(Style.border)
                        HStack(spacing: 8) {
                            quickDay("今天", offset: 0)
                            quickDay("明天", offset: 1)
                            quickDay("一周后", offset: 7)
                        }
                    }.padding(18).frame(width: 310).foregroundStyle(Style.ink).background(Style.surface)
                        .onExitCommand { showDate = false }
                }
            if includesTime {
                Button { showTime.toggle() } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "clock").foregroundStyle(Style.accentSoft)
                        Text(DateText.string(selection, "HH:mm")).monospacedDigit()
                    }.font(.system(size: 12, weight: .medium)).padding(.horizontal, 11).frame(height: 37)
                        .background(Style.surfaceMuted, in: RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(showTime ? Style.orangeFill : Style.border))
                }.accessibilityLabel("\(title)时间").accessibilityValue(DateText.string(selection, "HH:mm"))
                    .popover(isPresented: $showTime, arrowEdge: .bottom) {
                        TimePalette(selection: $selection) { showTime = false }
                    }
            }
        }.buttonStyle(ElasticButtonStyle(pressedScale: 0.98, hoverScale: 1))
            .onChange(of: minimum) { _, minimum in
                if let minimum, Calendar.current.startOfDay(for: selection) < Calendar.current.startOfDay(for: minimum) {
                    selection = DateSelection.replacingDay(in: selection, with: minimum)
                }
            }
    }

    private func quickDay(_ title: String, offset: Int) -> some View {
        let day = Calendar.current.date(byAdding: .day, value: offset, to: Date())!
        return Button { selection = DateSelection.replacingDay(in: selection, with: day); showDate = false } label: {
            Text(title).font(.system(size: 11, weight: .medium)).frame(maxWidth: .infinity).padding(.vertical, 9)
                .background(Style.orangeTint, in: RoundedRectangle(cornerRadius: 8)).foregroundStyle(Style.orange)
        }.buttonStyle(ElasticButtonStyle(pressedScale: 0.96, hoverScale: 1))
            .disabled(minimum.map { Calendar.current.startOfDay(for: day) < Calendar.current.startOfDay(for: $0) } ?? false)
    }
}

struct MonthCalendar: View {
    @Binding var selection: Date
    var minimum: Date? = nil
    var markedDays: Set<Date> = []
    var compact = false
    @State private var month: Date
    @State private var choosingMonth = false
    private let cal = Calendar.current
    init(selection: Binding<Date>, minimum: Date? = nil, markedDays: Set<Date> = [], compact: Bool = false) {
        _selection = selection; self.minimum = minimum; self.markedDays = markedDays; self.compact = compact
        _month = State(initialValue: selection.wrappedValue)
    }
    var body: some View {
        VStack(spacing: compact ? 14 : 16) {
            HStack(spacing: 7) {
                Button { choosingMonth.toggle() } label: {
                    HStack(spacing: 6) {
                        Text(DateText.string(month, choosingMonth ? "yyyy年" : "yyyy年 M月"))
                        Image(systemName: choosingMonth ? "chevron.up" : "chevron.down").font(.system(size: 8, weight: .semibold))
                    }.font(.system(size: 14, weight: .semibold))
                }.accessibilityLabel(choosingMonth ? "返回日期选择" : "选择月份")
                Spacer()
                navigation(-1)
                navigation(1)
            }
            if choosingMonth {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 7), count: 3), spacing: 9) {
                    ForEach(1...12, id: \.self) { number in
                        Button {
                            let year = cal.component(.year, from: month)
                            month = cal.date(from: DateComponents(year: year, month: number, day: 1))!
                            choosingMonth = false
                        } label: {
                            Text("\(number)月").font(.system(size: 12, weight: .medium)).frame(maxWidth: .infinity).frame(height: 37)
                                .background(cal.component(.month, from: month) == number ? Style.orangeTint : Style.surfaceMuted, in: RoundedRectangle(cornerRadius: 9))
                        }.accessibilityLabel("\(cal.component(.year, from: month))年\(number)月")
                    }
                }
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: 7), spacing: compact ? 5 : 6) {
                    ForEach(Array(["一", "二", "三", "四", "五", "六", "日"].enumerated()), id: \.offset) { index, title in
                        Text(title).font(.system(size: 10, weight: .medium)).foregroundStyle(index >= 5 ? Style.orange : Style.accentSoft).frame(height: 20)
                    }
                    ForEach(DateSelection.monthDays(containing: month), id: \.self) { day in dayButton(day) }
                }
            }
        }.buttonStyle(ElasticButtonStyle(pressedScale: 0.94, hoverScale: 1))
            .onChange(of: selection) { _, day in
                if !cal.isDate(day, equalTo: month, toGranularity: .month) { month = day }
            }
    }
    private func navigation(_ direction: Int) -> some View {
        Button {
            let first = cal.dateInterval(of: .month, for: month)!.start
            month = cal.date(byAdding: choosingMonth ? .year : .month, value: direction, to: first)!
        } label: {
            Image(systemName: direction < 0 ? "chevron.left" : "chevron.right").font(.system(size: 10, weight: .semibold))
                .frame(width: 27, height: 27).background(Style.surfaceMuted, in: RoundedRectangle(cornerRadius: 8))
        }.accessibilityLabel(direction < 0 ? (choosingMonth ? "上一年" : "上个月") : (choosingMonth ? "下一年" : "下个月"))
    }
    private func dayButton(_ day: Date) -> some View {
        let selected = cal.isDate(day, inSameDayAs: selection)
        let today = cal.isDateInToday(day)
        let inMonth = cal.isDate(day, equalTo: month, toGranularity: .month)
        let disabled = minimum.map { day < cal.startOfDay(for: $0) } ?? false
        return Button { selection = day } label: {
            VStack(spacing: 2) {
                Text("\(cal.component(.day, from: day))").font(.system(size: compact ? 11 : 12, weight: selected || today ? .semibold : .regular, design: .rounded))
                Circle().fill(markedDays.contains(day) ? Style.orangeFill : .clear).frame(width: 3, height: 3)
            }.frame(maxWidth: .infinity).frame(height: compact ? 29 : 32)
                .foregroundStyle(selected ? Color.white : inMonth ? Style.ink : Style.accentSoft.opacity(0.55))
                .background(selected ? Style.accentFill : today ? Style.orangeTint : .clear, in: RoundedRectangle(cornerRadius: 9))
                .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(today && !selected ? Style.orangeFill.opacity(0.5) : .clear))
                .opacity(disabled ? 0.25 : 1)
        }.disabled(disabled).accessibilityLabel(DateText.string(day, "yyyy年M月d日") + (markedDays.contains(day) ? "，有待办截止" : ""))
            .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}

private struct TimePalette: View {
    @Binding var selection: Date
    let dismiss: () -> Void
    private let cal = Calendar.current
    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Image(systemName: "clock").foregroundStyle(Style.orange)
                Text("选择时间").font(.system(size: 13, weight: .semibold))
                Spacer()
                Text(DateText.string(selection, "HH:mm")).font(.system(size: 15, weight: .semibold, design: .rounded)).monospacedDigit()
            }
            HStack(spacing: 12) {
                column(title: "时", range: 0..<24, component: .hour)
                column(title: "分", range: 0..<60, component: .minute)
            }
            Button("完成", action: dismiss).buttonStyle(SoftButtonStyle(prominent: true))
        }.padding(16).frame(width: 222).foregroundStyle(Style.ink).background(Style.surface).onExitCommand(perform: dismiss)
    }
    private func column(title: String, range: Range<Int>, component: Calendar.Component) -> some View {
        let selected = cal.component(component, from: selection)
        return VStack(spacing: 8) {
            Text(title).font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
            ScrollViewReader { reader in
                ScrollView {
                    LazyVStack(spacing: 3) {
                        ForEach(range, id: \.self) { value in
                            Button {
                                selection = DateSelection.replacingTime(in: selection,
                                    hour: component == .hour ? value : cal.component(.hour, from: selection),
                                    minute: component == .minute ? value : cal.component(.minute, from: selection))
                            } label: {
                                Text(String(format: "%02d", value)).font(.system(size: 14, weight: selected == value ? .semibold : .regular, design: .rounded))
                                    .monospacedDigit().frame(maxWidth: .infinity).frame(height: 32)
                            }.buttonStyle(ChoiceRowStyle(selected: selected == value)).id(value)
                                .accessibilityLabel("\(value)\(title)").accessibilityAddTraits(selected == value ? [.isSelected] : [])
                        }
                    }.padding(4)
                }.frame(height: 186).background(Style.surfaceMuted, in: RoundedRectangle(cornerRadius: 10))
                    .onAppear { reader.scrollTo(selected, anchor: .center) }
            }
        }
    }
}

struct IntervalField: View {
    @Binding var value: Int
    let unit: String
    var body: some View {
        HStack {
            FormLabel(title: "重复间隔", symbol: "arrow.triangle.2.circlepath")
            Spacer()
            HStack(spacing: 0) {
                step(-1)
                Text("每 \(value) \(unit)").font(.system(size: 12, weight: .medium)).monospacedDigit().frame(width: 100)
                step(1)
            }.padding(3).background(Style.surfaceMuted, in: RoundedRectangle(cornerRadius: 10))
        }
    }
    private func step(_ delta: Int) -> some View {
        Button { value = min(99, max(1, value + delta)) } label: {
            Image(systemName: delta > 0 ? "plus" : "minus").font(.system(size: 11, weight: .medium)).frame(width: 29, height: 29)
                .background(Style.surface, in: RoundedRectangle(cornerRadius: 7))
        }.buttonStyle(ElasticButtonStyle()).disabled(delta > 0 ? value >= 99 : value <= 1)
            .accessibilityLabel(delta > 0 ? "增加重复间隔" : "减少重复间隔").accessibilityValue("\(value)\(unit)")
    }
}

enum ReminderOptions {
    static func choices(atStart: String) -> [ChoiceOption<Int>] {
        [ChoiceOption(value: -1, title: "不提醒", symbol: "bell.slash"), ChoiceOption(value: 0, title: atStart, symbol: "bell.badge")]
        + [(5, "提前 5 分钟"), (15, "提前 15 分钟"), (30, "提前 30 分钟"), (60, "提前 1 小时"), (1440, "提前 1 天")]
            .map { ChoiceOption(value: $0.0, title: $0.1, symbol: "clock") }
    }
}

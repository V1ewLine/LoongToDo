import SwiftUI
import TodoCore

struct DayInspector: View {
    @ObservedObject var store: AppStore
    @ObservedObject var calendar: CalendarService
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                MonthCard(store: store)
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        Text(Calendar.current.isDateInToday(store.selectedDay) ? "今天的日程" : DateText.string(store.selectedDay, "M月d日") + "日程").font(.system(size: 14, weight: .semibold))
                        Spacer()
                        Button { store.newEvent() } label: { Image(systemName: "plus").font(.system(size: 13, weight: .semibold)).frame(width: 26, height: 26).background(Style.accentSoft.opacity(0.12), in: Circle()) }.buttonStyle(ElasticButtonStyle()).foregroundStyle(Style.accent).help("新建日程")
                    }
                    if !calendar.isConnected {
                        CalendarConnect(calendar: calendar, day: store.selectedDay) { store.error = $0 }
                    } else if calendar.events.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Image(systemName: "calendar.badge.checkmark").font(.system(size: 24, weight: .ultraLight)).foregroundStyle(Style.accent)
                            Text("这一天，还留着空白。").font(.system(size: 12)).foregroundStyle(.secondary)
                            Button("安排一段时间") { store.newEvent() }.buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(Style.accent)
                        }.padding(.vertical, 8)
                    } else {
                        ForEach(calendar.events.prefix(4)) { event in CompactEvent(event: event) }
                        Button(calendar.events.count > 4 ? "查看全部 \(calendar.events.count) 个日程 →" : "查看日程详情 →") { store.filter = .calendar }
                            .buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(Style.accent)
                    }
                }.padding(20).glassPanel(radius: 22)
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "arrow.triangle.2.circlepath").foregroundStyle(Style.accent)
                    Text("把好习惯设为重复日程，\n给生活一点稳定的节奏。")
                        .lineSpacing(5)
                }.font(.system(size: 10)).foregroundStyle(.secondary).padding(.horizontal, 10)
            }.padding(2)
        }.scrollIndicators(.hidden)
    }
}

struct MonthCard: View {
    @ObservedObject var store: AppStore
    @State private var month = Date()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var selection
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 3), count: 7)
    private var days: [Date] {
        let calendar = Calendar.current
        let first = calendar.date(from: calendar.dateComponents([.year, .month], from: month))!
        let leading = (calendar.component(.weekday, from: first) + 5) % 7
        let start = calendar.date(byAdding: .day, value: -leading, to: first)!
        return (0..<42).map { calendar.date(byAdding: .day, value: $0, to: start)! }
    }
    var body: some View {
        let dueDays = Set(store.todos.compactMap { todo -> Date? in
            guard !todo.isCompleted, let due = todo.dueDate else { return nil }
            return Calendar.current.startOfDay(for: due)
        })
        VStack(spacing: 20) {
            HStack {
                Text(DateText.string(month, "yyyy年 M月")).font(.system(size: 14, weight: .semibold))
                Spacer()
                Button { shift(-1) } label: { Image(systemName: "chevron.left").frame(width: 25, height: 25).background(Style.accentSoft.opacity(0.09), in: Circle()) }.help("上个月")
                Button { shift(1) } label: { Image(systemName: "chevron.right").frame(width: 25, height: 25).background(Style.accentSoft.opacity(0.09), in: Circle()) }.help("下个月")
            }.buttonStyle(ElasticButtonStyle()).font(.system(size: 10, weight: .semibold))
            LazyVGrid(columns: columns, spacing: 7) {
                ForEach(Array(["一", "二", "三", "四", "五", "六", "日"].enumerated()), id: \.offset) { _, day in
                    Text(day).font(.system(size: 9)).foregroundStyle(.tertiary).frame(height: 20)
                }
                ForEach(days, id: \.self) { day in dayCell(day, hasDue: dueDays.contains(day)) }
            }
            HStack(spacing: 5) {
                Circle().fill(Style.accentSoft).frame(width: 4, height: 4)
                Text("有待办截止").font(.system(size: 9)).foregroundStyle(.tertiary)
                Spacer()
                Button("回到今天") { month = Date(); store.selectedDay = Date() }.buttonStyle(ElasticButtonStyle()).font(.system(size: 10)).foregroundStyle(Style.accent)
            }
        }.padding(20).glassPanel(radius: 22)
            .onChange(of: store.selectedDay) { _, day in
                if !Calendar.current.isDate(day, equalTo: month, toGranularity: .month) { month = day }
            }
    }
    private func shift(_ offset: Int) { month = Calendar.current.date(byAdding: .month, value: offset, to: month)! }
    private func dayCell(_ day: Date, hasDue: Bool) -> some View {
        let cal = Calendar.current
        let selected = cal.isDate(day, inSameDayAs: store.selectedDay)
        let today = cal.isDateInToday(day)
        let inMonth = cal.isDate(day, equalTo: month, toGranularity: .month)
        return Button { store.selectedDay = day } label: {
            VStack(spacing: 2) {
                Text("\(cal.component(.day, from: day))").font(.system(size: 11, weight: selected || today ? .semibold : .regular, design: .rounded))
                Circle().fill(hasDue ? (selected ? Color.white : Style.accentSoft) : .clear).frame(width: 3, height: 3)
            }.frame(maxWidth: .infinity).frame(height: 28)
                .foregroundStyle(selected ? .white : inMonth ? Color.primary.opacity(0.8) : Color.secondary.opacity(0.3))
                .background {
                    if selected {
                        RoundedRectangle(cornerRadius: 10).fill(Style.accentFill.gradient)
                            .shadow(color: Style.accent.opacity(0.23), radius: 4, y: 3)
                            .matchedGeometryEffect(id: "selected-day", in: selection)
                    }
                }
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(today && !selected ? Style.accent.opacity(0.45) : .clear))
        }.buttonStyle(ElasticButtonStyle(pressedScale: 0.82, hoverScale: 1.08))
            .animation(reduceMotion ? nil : Motion.release, value: store.selectedDay)
            .accessibilityLabel(DateText.string(day, "yyyy年M月d日") + (hasDue ? "，有待办截止" : "")).accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}

struct CompactEvent: View {
    let event: AgendaEvent
    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            RoundedRectangle(cornerRadius: 2).fill(Color(nsColor: event.color).opacity(0.75)).frame(width: 3, height: 48)
            VStack(alignment: .leading, spacing: 7) {
                Text(event.allDay ? "全天" : DateText.string(event.start, "HH:mm") + " – " + DateText.string(event.end, "HH:mm"))
                    .font(.system(size: 10, weight: .medium, design: .rounded)).foregroundStyle(.secondary)
                Text(event.title).font(.system(size: 12, weight: .medium)).lineLimit(2)
                if event.recurring { Label("重复日程", systemImage: "repeat").font(.system(size: 9)).foregroundStyle(.tertiary) }
            }
            Spacer(minLength: 0)
        }
    }
}

struct CalendarConnect: View {
    @ObservedObject var calendar: CalendarService
    let day: Date
    let onError: (String) -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            Text("连接系统日历，在这里查看安排，也能添加单次或重复日程。")
                .font(.system(size: 12)).foregroundStyle(.secondary).lineSpacing(5)
            Button {
                Task { do { try await calendar.connect(day: day) } catch { onError(error.localizedDescription) } }
            } label: {
                if calendar.isConnecting { ProgressView().controlSize(.small) }
                else { Label("连接系统日历", systemImage: "link") }
            }.buttonStyle(SoftButtonStyle()).disabled(calendar.isConnecting)
        }
    }
}

struct CalendarPage: View {
    @ObservedObject var store: AppStore
    @ObservedObject var calendar: CalendarService
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text(DateText.string(store.selectedDay, "M月d日 EEEE")).font(.system(size: 13, weight: .medium))
                Spacer()
                Button { moveDay(-1) } label: { Image(systemName: "chevron.left") }.help("前一天")
                Button { store.selectedDay = Date() } label: { Text("今天") }.padding(.horizontal, 8)
                Button { moveDay(1) } label: { Image(systemName: "chevron.right") }.help("后一天")
            }.buttonStyle(ElasticButtonStyle()).font(.system(size: 12)).foregroundStyle(Style.accent)
            if !calendar.isConnected {
                CalendarConnect(calendar: calendar, day: store.selectedDay) { store.error = $0 }.padding(24).frame(maxWidth: .infinity, alignment: .leading).glassPanel()
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        if calendar.events.isEmpty {
                            VStack(spacing: 17) {
                                Image(systemName: "calendar").font(.system(size: 34, weight: .ultraLight)).foregroundStyle(Style.accent)
                                Text("这一天，还没有日程").font(.system(size: 15, weight: .medium))
                                Text("选择右侧日期，或为这一天添加安排。").font(.system(size: 12)).foregroundStyle(.secondary)
                            }.padding(.vertical, 54).frame(maxWidth: .infinity)
                        }
                        ForEach(calendar.events) { event in
                            HStack(alignment: .top, spacing: 18) {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(event.allDay ? "全天" : DateText.string(event.start, "HH:mm")).font(.system(size: 16, weight: .medium, design: .rounded))
                                    if !event.allDay { Text(DateText.string(event.end, "HH:mm")).font(.system(size: 11, design: .rounded)).foregroundStyle(.secondary) }
                                }.frame(width: 48, alignment: .leading)
                                RoundedRectangle(cornerRadius: 2).fill(Color(nsColor: event.color)).frame(width: 3)
                                VStack(alignment: .leading, spacing: 9) {
                                    Text(event.title).font(.system(size: 14, weight: .medium))
                                    HStack {
                                        SmallTag(text: event.calendarTitle, icon: "calendar", color: Color(nsColor: event.color))
                                        if event.recurring { SmallTag(text: "重复", icon: "repeat") }
                                    }
                                    if !event.location.isEmpty { Label(event.location, systemImage: "mappin.and.ellipse").font(.system(size: 11)).foregroundStyle(.secondary) }
                                }.frame(maxWidth: .infinity, alignment: .leading)
                            }.padding(20).floatingCard(radius: 21)
                        }
                    }.padding(2)
                }.scrollIndicators(.hidden)
                Button { NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Calendar.app")) } label: {
                    Label("在系统日历中编辑或管理日程", systemImage: "arrow.up.forward.square")
                }.buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(.secondary)
            }
        }.frame(maxHeight: .infinity, alignment: .top)
    }
    private func moveDay(_ value: Int) { store.selectedDay = Calendar.current.date(byAdding: .day, value: value, to: store.selectedDay)! }
}

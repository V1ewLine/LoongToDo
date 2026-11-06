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
    var body: some View {
        let dueDays = Set(store.todos.compactMap { todo -> Date? in
            guard !todo.isCompleted, let due = todo.dueDate else { return nil }
            return Calendar.current.startOfDay(for: due)
        })
        VStack(spacing: 18) {
            MonthCalendar(selection: $store.selectedDay, markedDays: dueDays, compact: true)
            HStack(spacing: 5) {
                Circle().fill(Style.orangeFill).frame(width: 4, height: 4)
                Text("有待办截止").font(.system(size: 9)).foregroundStyle(.secondary)
                Spacer()
                Button("回到今天") { store.selectedDay = Date() }
                    .buttonStyle(ElasticButtonStyle()).font(.system(size: 10, weight: .medium)).foregroundStyle(Style.orange)
            }
        }.padding(20).glassPanel(radius: 22)
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

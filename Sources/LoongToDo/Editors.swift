import SwiftUI
import TodoCore

struct TodoEditor: View {
    @ObservedObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var todo: Todo
    @State private var hasDue: Bool
    @State private var due: Date
    @State private var reminder: Int
    @State private var saving = false
    @State private var error: String?
    @FocusState private var titleFocused: Bool
    private let isNew: Bool

    init(store: AppStore, todo: Todo) {
        self.store = store
        _todo = State(initialValue: todo)
        _hasDue = State(initialValue: todo.dueDate != nil)
        _due = State(initialValue: todo.dueDate ?? Date().addingTimeInterval(3600))
        _reminder = State(initialValue: todo.reminderMinutes ?? -1)
        isNew = !store.todos.contains(where: { $0.id == todo.id })
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            EditorHeading(title: isNew ? "一件新的小事" : "把计划整理好", subtitle: isNew ? "记下来，然后专心去生活。" : "每个计划，都可以慢慢调整。", icon: "checkmark.circle")
            VStack(alignment: .leading, spacing: 16) {
                TextField("想做什么？", text: $todo.title).font(.system(size: 21, weight: .medium)).textFieldStyle(.plain).focused($titleFocused)
                Divider()
                TextField("添加备注，留下一点细节…", text: $todo.notes, axis: .vertical).lineLimit(3...5).font(.system(size: 13)).textFieldStyle(.plain)
            }.padding(20).glassPanel(radius: 17)
            VStack(spacing: 18) {
                PriorityField(selection: $todo.priority)
                Divider()
                Toggle(isOn: $hasDue) { FormLabel(title: "设置截止日期", symbol: "calendar.badge.clock") }.toggleStyle(BrandToggleStyle())
                if hasDue {
                    DateTimeField(title: "截止时间", selection: $due)
                    ChoiceField(title: "提醒我", symbol: "bell", selection: $reminder, options: ReminderOptions.choices(atStart: "截止时"))
                }
            }.font(.system(size: 13)).padding(20).glassPanel(radius: 17)
                .animation(reduceMotion ? nil : Motion.layout, value: hasDue)
            if todo.calendarEventID != nil { Text("这条待办已添加到日历。日历中的安排独立管理，修改待办不会改变日程。").font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) }
            if let error { Text(error).font(.system(size: 12)).foregroundStyle(Style.orange).fixedSize(horizontal: false, vertical: true) }
            HStack {
                if !isNew && todo.calendarEventID == nil {
                    Button("添加到日历…") {
                        Task { if await save() { dismiss(); store.newEvent(from: todo) } }
                    }.buttonStyle(.plain).font(.system(size: 12)).foregroundStyle(Style.accent).disabled(saving)
                }
                Spacer()
                Button("取消") { dismiss() }.keyboardShortcut(.cancelAction).buttonStyle(SoftButtonStyle()).disabled(saving)
                Button { Task { if await save() { dismiss() } } } label: {
                    if saving { ProgressView().controlSize(.small) } else { Text("保存待办") }
                }.keyboardShortcut(.defaultAction).buttonStyle(SoftButtonStyle(prominent: true)).disabled(saving || todo.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }.padding(28).frame(width: 560).foregroundStyle(Style.ink).background { AuroraBackground() }.interactiveDismissDisabled(saving)
            .task { titleFocused = true }
    }
    @MainActor private func save() async -> Bool {
        saving = true; error = nil
        defer { saving = false }
        todo.dueDate = hasDue ? due : nil
        todo.reminderMinutes = hasDue && reminder >= 0 ? reminder : nil
        do {
            let saved = try await store.save(todo)
            if !saved { error = store.error; store.error = nil }
            return saved
        } catch { self.error = error.localizedDescription; return false }
    }
}

struct EventEditor: View {
    @ObservedObject var store: AppStore
    @ObservedObject var calendar: CalendarService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var draft: EventDraft
    @State private var endsRepeat = false
    @State private var repeatEnd: Date
    @State private var alarm = -1
    @State private var saving = false
    @State private var error: String?
    @FocusState private var titleFocused: Bool
    let todoID: UUID?
    init(store: AppStore, calendar: CalendarService, context: EventEditorContext) {
        self.store = store; self.calendar = calendar; todoID = context.todoID
        _draft = State(initialValue: context.draft)
        _repeatEnd = State(initialValue: Calendar.current.date(byAdding: .month, value: 1, to: context.draft.start)!)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            EditorHeading(title: "为重要的事，留点时间", subtitle: "单次安排，或让好习惯如期发生。", icon: "calendar")
            if !calendar.isConnected {
                CalendarConnect(calendar: calendar, day: store.selectedDay) { error = $0 }.padding(20).glassPanel()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        TextField("日程标题", text: $draft.title).font(.system(size: 21, weight: .medium)).textFieldStyle(.plain).focused($titleFocused).padding(19).glassPanel(radius: 16)
                        timeFields
                        repeatFields
                        detailFields
                    }.padding(2)
                }.scrollIndicators(.hidden)
            }
            if let error { Text(error).font(.system(size: 12)).foregroundStyle(Style.orange).fixedSize(horizontal: false, vertical: true) }
            HStack {
                if todoID != nil { Text("添加后，日程与待办独立管理。").font(.system(size: 10)).foregroundStyle(.secondary) }
                Spacer()
                Button("取消") { dismiss() }.keyboardShortcut(.cancelAction).buttonStyle(SoftButtonStyle()).disabled(saving)
                Button("添加到日历") { save() }.keyboardShortcut(.defaultAction).buttonStyle(SoftButtonStyle(prominent: true))
                    .disabled(saving || !calendar.isConnected || calendar.calendars.isEmpty || draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }.padding(28).frame(width: 580, height: calendar.isConnected ? 710 : 360).foregroundStyle(Style.ink).background { AuroraBackground() }
            .interactiveDismissDisabled(saving)
            .task { selectDefaultCalendar(); titleFocused = true }
            .onChange(of: calendar.isConnected) { _, _ in selectDefaultCalendar() }
    }
    private var timeFields: some View {
        VStack(spacing: 16) {
            Toggle(isOn: $draft.allDay) { FormLabel(title: "全天日程", symbol: "sun.max") }.toggleStyle(BrandToggleStyle())
            DateTimeField(title: "开始", selection: $draft.start, includesTime: !draft.allDay)
            DateTimeField(title: draft.allDay ? "结束（含当天）" : "结束", selection: $draft.end, includesTime: !draft.allDay)
            Divider()
            ChoiceField(title: "写入日历", symbol: "calendar", selection: $draft.calendarID,
                        options: calendar.calendars.map { ChoiceOption(value: $0.id, title: $0.title, subtitle: $0.source, color: Color(nsColor: $0.color)) })
            if calendar.calendars.isEmpty { Text("暂无可写日历。请先在系统日历中添加账户或创建日历，再重新打开此窗口。").font(.system(size: 11)).foregroundStyle(Style.orange) }
        }.font(.system(size: 13)).padding(19).glassPanel(radius: 17)
            .onChange(of: draft.start) { old, new in
                if draft.end <= new { draft.end = new.addingTimeInterval(max(1800, draft.end.timeIntervalSince(old))) }
                if Calendar.current.startOfDay(for: repeatEnd) < Calendar.current.startOfDay(for: new) { repeatEnd = new }
            }
    }
    private var repeatFields: some View {
        VStack(alignment: .leading, spacing: 16) {
            ChoiceField(title: "重复", symbol: "repeat", selection: $draft.frequency,
                        options: RepeatFrequency.allCases.map { ChoiceOption(value: $0, title: $0.title, symbol: $0 == .none ? "minus.circle" : "repeat") })
            if draft.frequency != .none {
                IntervalField(value: $draft.interval, unit: draft.frequency.unit)
                Toggle("设置重复结束日期", isOn: $endsRepeat).toggleStyle(BrandToggleStyle())
                if endsRepeat { DateTimeField(title: "重复至（含当天）", selection: $repeatEnd, includesTime: false, minimum: Calendar.current.startOfDay(for: draft.start)) }
                if draft.frequency == .monthly {
                    Text("每月按开始日期的日号重复；没有该日期的月份将跳过。").font(.system(size: 10)).foregroundStyle(.secondary)
                }
            }
        }.font(.system(size: 13)).padding(19).glassPanel(radius: 17)
            .animation(reduceMotion ? nil : Motion.layout, value: draft.frequency)
            .animation(reduceMotion ? nil : Motion.layout, value: endsRepeat)
    }
    private var detailFields: some View {
        VStack(alignment: .leading, spacing: 16) {
            ChoiceField(title: "日历提醒", symbol: "bell", selection: $alarm, options: ReminderOptions.choices(atStart: "开始时"))
            Divider()
            TextField("地点（选填）", text: $draft.location).textFieldStyle(.plain)
            TextField("备注（选填）", text: $draft.notes, axis: .vertical).lineLimit(2...3).textFieldStyle(.plain)
        }.font(.system(size: 13)).padding(19).glassPanel(radius: 17)
    }
    private func selectDefaultCalendar() {
        if !calendar.calendars.contains(where: { $0.id == draft.calendarID }) { draft.calendarID = calendar.calendars.first(where: { $0.id == calendar.defaultCalendarID })?.id ?? calendar.calendars.first?.id ?? "" }
    }
    private func save() {
        guard !saving else { return }
        saving = true; error = nil
        draft.repeatUntil = endsRepeat && draft.frequency != .none ? repeatEnd : nil
        draft.alarmMinutes = alarm >= 0 ? alarm : nil
        do {
            let id = try calendar.create(draft)
            store.eventSaved(id: id, todoID: todoID, day: draft.start)
            dismiss()
        } catch { self.error = error.localizedDescription; saving = false }
    }
}

struct EditorHeading: View {
    let title: String
    let subtitle: String
    let icon: String
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon).font(.system(size: 23, weight: .regular)).foregroundStyle(Style.orange).frame(width: 48, height: 48).background(Style.orangeTint, in: RoundedRectangle(cornerRadius: 15))
            VStack(alignment: .leading, spacing: 7) {
                Text(title).font(.system(size: 20, weight: .semibold))
                Text(subtitle).font(.system(size: 12)).foregroundStyle(.secondary)
            }
        }
    }
}

import SwiftUI
import EventKit
import TodoCore

struct ContentView: View {
    @ObservedObject var store: AppStore
    @ObservedObject var calendar: CalendarService
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var quickTitle = ""
    @FocusState private var searching: Bool
    @FocusState private var adding: Bool
    private let minute = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            AuroraBackground()
            HStack(spacing: 0) {
                Sidebar(store: store, calendar: calendar).frame(width: 216)
                VStack(alignment: .leading, spacing: 22) {
                    topBar
                    HStack(alignment: .top, spacing: 22) {
                        mainColumn.frame(maxWidth: .infinity)
                        DayInspector(store: store, calendar: calendar).frame(width: 264)
                    }
                }.padding(.horizontal, 28).padding(.top, 42).padding(.bottom, 24)
            }
        }
        .overlay(alignment: .bottom) { ToastOverlay(message: store.toast, undo: store.undoDelete).padding(.bottom, 26) }
        .frame(minWidth: 1100, minHeight: 740)
        .sheet(item: $store.todoEditor) { todo in TodoEditor(store: store, todo: todo) }
        .sheet(item: $store.eventEditor) { context in EventEditor(store: store, calendar: calendar, context: context) }
        .alert("请留意", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) {
            Button("知道了", role: .cancel) { store.error = nil }
            if store.isReadOnly { Button("查看数据文件") { store.revealData() } }
        } message: { Text(store.error ?? "") }
        .alert("删除这条待办？", isPresented: Binding(get: { store.pendingDeletion != nil }, set: { if !$0 { store.pendingDeletion = nil } })) {
            Button("取消", role: .cancel) { store.pendingDeletion = nil }
            Button("删除", role: .destructive) { if let todo = store.pendingDeletion { store.delete(todo) }; store.pendingDeletion = nil }
        } message: { Text("\(store.pendingDeletion?.title ?? "")\n已添加到系统日历的日程会保留。") }
        .onChange(of: scenePhase) { _, phase in if phase == .active { store.refresh() } }
        .onChange(of: store.selectedDay) { _, day in calendar.refresh(day: day) }
        .onReceive(NotificationCenter.default.publisher(for: .EKEventStoreChanged)) { _ in calendar.refresh(day: store.selectedDay) }
        .onReceive(minute) { date in store.now = date; calendar.refresh(day: store.selectedDay) }
        .background {
            Button("") { searching = true }.keyboardShortcut("f").hidden()
        }
    }

    private var topBar: some View {
        HStack {
            HStack(spacing: 7) {
                Image(systemName: "sparkle").foregroundStyle(Style.accent)
                Text("少一点忙乱，多一点从容").foregroundStyle(.secondary)
            }.font(.system(size: 12, weight: .medium))
            Spacer()
            if store.isDemo { SmallTag(text: "界面预览 · 数据不保存", icon: "eye", color: Style.orange) }
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("搜索待办", text: $store.search).textFieldStyle(.plain).focused($searching)
                if !store.search.isEmpty { Button { store.search = "" } label: { Image(systemName: "xmark.circle.fill") }.buttonStyle(.plain).foregroundStyle(.secondary) }
                else { Text("⌘ F").foregroundStyle(.tertiary) }
            }.font(.system(size: 12)).padding(.horizontal, 13).padding(.vertical, 10).frame(width: 210).glassPanel(radius: 14)
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Style.accentSoft.opacity(searching ? 0.65 : 0)))
                .animation(reduceMotion ? nil : Motion.hover, value: searching)
        }.frame(height: 30)
    }

    private var mainColumn: some View {
        VStack(alignment: .leading, spacing: 22) {
            hero
            HStack(alignment: .firstTextBaseline) {
                Text(store.filter.title).font(.system(size: 20, weight: .semibold))
                if store.filter != .calendar { Text("\(store.visibleTodos.count)").font(.system(size: 12, weight: .medium)).foregroundStyle(Style.accent).padding(.horizontal, 8).padding(.vertical, 3).background(Style.accent.opacity(0.08), in: Capsule()).contentTransition(.numericText()).animation(reduceMotion ? nil : Motion.layout, value: store.visibleTodos.count) }
                Spacer()
                Button { store.filter == .calendar ? store.newEvent() : store.newTodo() } label: {
                    Label(store.filter == .calendar ? "新建日程" : "新建待办", systemImage: "plus")
                }.buttonStyle(SoftButtonStyle(prominent: true))
            }
            if store.filter == .calendar {
                CalendarPage(store: store, calendar: calendar)
            } else {
                if store.filter != .completed { quickAdd }
                AnimatedTodoList(store: store)
            }
        }.frame(maxHeight: .infinity, alignment: .top)
    }

    private var hero: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                Text(DateText.string(store.now, "M月d日 EEEE").uppercased()).font(.system(size: 11, weight: .medium, design: .monospaced)).tracking(1).foregroundStyle(Style.accent)
                Text(heroTitle).font(.system(size: 29, weight: .semibold)).tracking(-0.7)
                Text(store.todayCount == 0 ? "留白，也是生活的一部分。" : "今天还有 \(store.todayCount) 件小事，慢慢来，一件一件完成。")
                    .font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(2)
            }
            Spacer(minLength: 4)
            ProgressBubble(completed: store.completedToday, progress: store.progress)
        }.padding(26).frame(maxWidth: .infinity, minHeight: 158, alignment: .leading)
            .background(LinearGradient(colors: [Style.accentSoft.opacity(0.11), .white.opacity(0.06)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 28))
            .glassPanel(radius: 28)
    }
    private var heroTitle: String {
        switch store.filter { case .completed: return "每一步，都算数。"; case .upcoming: return "把期待，安排进生活。"; case .calendar: return "为重要的事，留出时间。"; default: return "今天，从容一点。" }
    }
    private var quickAdd: some View {
        HStack(spacing: 12) {
            Image(systemName: "plus").font(.system(size: 13, weight: .semibold)).foregroundStyle(Style.accent)
                .frame(width: 28, height: 28).background(Style.accentSoft.opacity(0.14), in: Circle())
                .rotationEffect(.degrees(adding && !reduceMotion ? 90 : 0))
            TextField("记下一件想做的事…", text: $quickTitle).font(.system(size: 13)).textFieldStyle(.plain).focused($adding).onSubmit(addQuickTodo)
            Button(action: addQuickTodo) { Image(systemName: "return").font(.system(size: 12)).foregroundStyle(.secondary).padding(6).background(.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 6)) }
                .buttonStyle(ElasticButtonStyle()).disabled(quickTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty).help("添加待办")
        }.padding(14).glassPanel(radius: 20)
            .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Style.accentSoft.opacity(adding ? 0.65 : 0), lineWidth: 1.5))
            .shadow(color: Style.accentSoft.opacity(adding ? 0.15 : 0), radius: 10, y: 3)
            .animation(reduceMotion ? nil : Motion.hover, value: adding)
    }
    private func addQuickTodo() {
        guard !quickTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        store.quickAdd(quickTitle)
        if store.error == nil { quickTitle = ""; store.filter = .today; store.search = "" }
    }
}

struct Sidebar: View {
    @ObservedObject var store: AppStore
    @ObservedObject var calendar: CalendarService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Namespace private var selection
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                BrandLogo().frame(width: 38, height: 38)
                VStack(alignment: .leading, spacing: 2) {
                    Text("LoongTodo").font(.system(size: 17, weight: .semibold, design: .rounded))
                    Text("一事一刻，自有节奏").font(.system(size: 9)).foregroundStyle(.secondary)
                }
            }.padding(.bottom, 48)
            Text("我的空间").font(.system(size: 10, weight: .medium)).foregroundStyle(.tertiary).padding(.leading, 14).padding(.bottom, 14)
            VStack(spacing: 8) {
                ForEach(TodoFilter.allCases.filter { $0 != .calendar }) { filter in navItem(filter) }
            }
            Divider().opacity(0.4).padding(.vertical, 23).padding(.horizontal, 12)
            Text("时间安排").font(.system(size: 10, weight: .medium)).foregroundStyle(.tertiary).padding(.leading, 14).padding(.bottom, 14)
            navItem(.calendar)
            Button { store.newEvent() } label: {
                Label("添加日程", systemImage: "plus").font(.system(size: 13)).foregroundStyle(.secondary).padding(.horizontal, 14).padding(.vertical, 14).frame(maxWidth: .infinity, alignment: .leading)
            }.buttonStyle(ElasticButtonStyle(pressedScale: 0.95, hoverScale: 1.015))
            Spacer(minLength: 24)
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: "sun.horizon").font(.system(size: 24, weight: .ultraLight)).foregroundStyle(Style.accent)
                Text("让计划轻一点，\n让生活多一点。").font(.system(size: 13, weight: .medium)).lineSpacing(5).fixedSize(horizontal: false, vertical: true)
                Text("MAKE ROOM FOR LIFE").font(.system(size: 7, weight: .medium, design: .monospaced)).tracking(1.3).foregroundStyle(.tertiary)
            }.padding(18).frame(maxWidth: .infinity, alignment: .leading).glassPanel(radius: 18)
            HStack(spacing: 7) {
                Circle().fill(calendar.isConnected ? Style.accentSoft : .secondary.opacity(0.5)).frame(width: 5, height: 5)
                Text(calendar.isConnected ? "系统日历已连接" : "待办保存在本机").font(.system(size: 10)).foregroundStyle(.secondary)
                Spacer()
                Menu {
                    Button("打开本地数据位置") { store.revealData() }
                    Button("在系统日历中查看") { NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Calendar.app")) }
                    Button("刷新日历") { store.refresh() }
                } label: { Image(systemName: "ellipsis").foregroundStyle(.secondary) }.menuStyle(.borderlessButton).fixedSize().help("更多选项")
            }.padding(.horizontal, 9).padding(.top, 24)
        }.padding(.horizontal, 18).padding(.top, 62).padding(.bottom, 26)
            .background {
                if reduceTransparency { Color(nsColor: .windowBackgroundColor) }
                else { Rectangle().fill(.ultraThinMaterial) }
            }.overlay(alignment: .trailing) { Rectangle().fill(.white.opacity(0.35)).frame(width: 1) }
    }
    private func navItem(_ filter: TodoFilter) -> some View {
        let selected = store.filter == filter
        return Button { store.filter = filter; store.search = "" } label: {
            HStack(spacing: 11) {
                Image(systemName: filter.symbol).font(.system(size: 16, weight: selected ? .medium : .regular)).frame(width: 20)
                Text(filter.title).font(.system(size: 13, weight: selected ? .semibold : .regular))
                Spacer()
                if filter != .calendar { Text("\(store.count(filter))").font(.system(size: 11, weight: .medium, design: .rounded)).foregroundStyle(selected ? Style.accent : Color.secondary) }
            }.foregroundStyle(selected ? Style.accent : Color.primary.opacity(0.7))
                .padding(.horizontal, 14).padding(.vertical, 14)
                .background {
                    if selected {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(LinearGradient(colors: [Style.accentSoft.opacity(0.26), Style.accentSoft.opacity(0.12)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.white.opacity(0.7)))
                            .shadow(color: Style.accent.opacity(0.08), radius: 6, y: 4)
                            .matchedGeometryEffect(id: "sidebar-selection", in: selection)
                    }
                }
        }.buttonStyle(ElasticButtonStyle(pressedScale: 0.94, hoverScale: 1.02))
            .animation(reduceMotion ? nil : Motion.release, value: store.filter)
            .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}

struct TodoRow: View {
    let todo: Todo
    let store: AppStore
    let now: Date
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        HStack(alignment: .top, spacing: 13) {
            Button { store.toggle(todo) } label: {
                ZStack {
                    Circle().fill(todo.isCompleted ? Style.accentFill : Style.accentSoft.opacity(0.05))
                    Circle().strokeBorder(todo.isCompleted ? Style.accent.opacity(0.2) : Style.accent.opacity(0.27), lineWidth: 1.5)
                    Image(systemName: "checkmark").font(.system(size: 12, weight: .bold)).foregroundStyle(.white)
                        .scaleEffect(todo.isCompleted || reduceMotion ? 1 : 0.3).opacity(todo.isCompleted ? 1 : 0)
                }.frame(width: 25, height: 25).padding(3)
                    .animation(reduceMotion ? nil : Motion.release, value: todo.isCompleted)
            }.buttonStyle(ElasticButtonStyle(pressedScale: 0.78, hoverScale: 1.12)).help(todo.isCompleted ? "恢复待办" : "标记完成").accessibilityLabel(todo.isCompleted ? "恢复：\(todo.title)" : "完成：\(todo.title)")
            Button { store.todoEditor = todo } label: {
                VStack(alignment: .leading, spacing: 8) {
                    Text(todo.title).font(.system(size: 14, weight: .medium)).strikethrough(todo.isCompleted).foregroundStyle(todo.isCompleted ? .secondary : .primary).lineLimit(2).multilineTextAlignment(.leading)
                    if !todo.notes.isEmpty { Text(todo.notes).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1) }
                    HStack(spacing: 6) {
                        if let due = todo.dueDate {
                            let overdue = due < now && !todo.isCompleted
                            SmallTag(text: (overdue ? "逾期 · " : "") + DateText.due(due, now: now), icon: "clock", color: overdue ? Style.orange : .secondary)
                        }
                        if todo.priority == .important { SmallTag(text: "重要", icon: "flag.fill", color: Style.orange) }
                        if todo.reminderMinutes != nil { Image(systemName: "bell").font(.system(size: 10)).foregroundStyle(.tertiary).help("已设置截止提醒") }
                        if todo.calendarEventID != nil { Image(systemName: "calendar.badge.checkmark").font(.system(size: 11)).foregroundStyle(Style.accent).help("已添加到系统日历") }
                    }
                }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
            }.buttonStyle(.plain)
            Menu {
                Button("编辑待办") { store.todoEditor = todo }
                Button(todo.isCompleted ? "恢复待办" : "标记完成") { store.toggle(todo) }
                Button(todo.calendarEventID == nil ? "添加到日历…" : "已添加到日历") { store.newEvent(from: todo) }.disabled(todo.calendarEventID != nil)
                Divider()
                Button("删除待办…", role: .destructive) { store.pendingDeletion = todo }
            } label: { Image(systemName: "ellipsis").font(.system(size: 14)).foregroundStyle(.secondary).padding(4) }
                .menuStyle(.borderlessButton).fixedSize().help("待办操作")
        }.padding(17).floatingCard(radius: 21)
            .overlay(RoundedRectangle(cornerRadius: 21).fill(Style.accentSoft.opacity(todo.isCompleted ? 0.06 : 0)).allowsHitTesting(false))
            .contextMenu {
                Button("编辑待办") { store.todoEditor = todo }
                Button("添加到日历…") { store.newEvent(from: todo) }.disabled(todo.calendarEventID != nil)
                Button("删除待办…", role: .destructive) { store.pendingDeletion = todo }
            }
    }
}

struct EmptyTasks: View {
    let filter: TodoFilter
    let searching: Bool
    let add: () -> Void
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle().fill(Style.accentSoft.opacity(0.07)).frame(width: 108, height: 108)
                Circle().fill(LinearGradient(colors: [Style.accentSoft.opacity(0.12), Style.accentSoft.opacity(0.32)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay(Circle().strokeBorder(.white.opacity(0.75), lineWidth: 1.5))
                    .shadow(color: Style.accent.opacity(0.14), radius: 12, x: 0, y: 8).frame(width: 82, height: 82)
                Image(systemName: searching ? "magnifyingglass" : filter == .completed ? "checkmark.seal" : "leaf").font(.system(size: 32, weight: .light)).foregroundStyle(Style.accent)
            }
            Text(searching ? "没有找到这条待办" : filter == .completed ? "完成的小事，都值得记录" : "还没有待办，刚刚好").font(.system(size: 16, weight: .medium))
            Text(searching ? "试试其他关键词。" : filter == .upcoming ? "设置未来七天的截止日期，计划就会出现在这里。" : filter == .completed ? "勾选完成的待办会收进这里。" : "从一件小事开始，给今天一个轻盈的起点。")
                .font(.system(size: 12)).foregroundStyle(.secondary).multilineTextAlignment(.center)
            if !searching && filter != .completed { Button("写下第一件事", action: add).buttonStyle(SoftButtonStyle()).padding(.top, 4) }
        }
    }
}

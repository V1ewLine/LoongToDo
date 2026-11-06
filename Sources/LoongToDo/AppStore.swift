import AppKit
import Combine
import TodoCore

@MainActor
final class AppStore: ObservableObject {
    @Published private(set) var todos: [Todo] = []
    @Published var error: String?
    @Published var toast: String?
    @Published var filter: TodoFilter = .today
    @Published var search = ""
    @Published var selectedDay = Date()
    @Published var now = Date()
    @Published var todoEditor: Todo?
    @Published var eventEditor: EventEditorContext?
    @Published var pendingDeletion: Todo?
    @Published private(set) var isReadOnly = false
    let isDemo: Bool
    let calendar: CalendarService
    private let notifications = NotificationService()
    private let repository: TodoRepository
    private var toastTask: Task<Void, Never>?
    private var deleted: Todo?

    init() {
        isDemo = ProcessInfo.processInfo.arguments.contains("--demo") || Bundle.main.object(forInfoDictionaryKey: "LoongPreview") as? Bool == true
        let dataURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("com.loong.todo", isDirectory: true).appendingPathComponent("todos.json")
        repository = TodoRepository(url: dataURL)
        calendar = CalendarService(isDemo: isDemo)
        if isDemo {
            let start = Calendar.current.startOfDay(for: Date())
            todos = [
                Todo(title: "把脑海里的好想法，变成现实", notes: "留出一段不被打扰的时间，迈出第一步。", dueDate: start.addingTimeInterval(18 * 3600), priority: .important),
                Todo(title: "读 20 页一直想读的书", dueDate: start.addingTimeInterval(21 * 3600), reminderMinutes: 15),
                Todo(title: "整理本周的灵感与笔记", notes: "少一点杂乱，多一点清晰。"),
                Todo(title: "给下周安排一次小小的出逃", dueDate: start.addingTimeInterval(2 * 86400 + 12 * 3600)),
                Todo(title: "喝一杯水，舒展一下身体", completedAt: Date())
            ]
        } else {
            do { todos = try repository.load() }
            catch { isReadOnly = true; self.error = "无法读取待办数据，已暂停写入以保护原文件。\n\(error.localizedDescription)\n数据文件：\(dataURL.path)" }
            notifications.start()
            if !isReadOnly { syncReminders() }
        }
        calendar.refresh(day: selectedDay)
    }

    var visibleTodos: [Todo] {
        todos.filter { filter.includes($0, now: now) && (search.isEmpty || $0.title.localizedStandardContains(search) || $0.notes.localizedStandardContains(search)) }
            .sorted { left, right in
                if filter == .completed { return left.completedAt! > right.completedAt! }
                if left.priority != right.priority { return left.priority == .important }
                if left.dueDate != right.dueDate { return (left.dueDate ?? .distantFuture) < (right.dueDate ?? .distantFuture) }
                return left.createdAt > right.createdAt
            }
    }
    var completedToday: Int { todos.filter { $0.completedAt.map { Calendar.current.isDate($0, inSameDayAs: now) } ?? false }.count }
    var todayCount: Int { count(.today) }
    var progress: Double { Double(completedToday) / Double(max(1, todayCount + completedToday)) }
    func count(_ filter: TodoFilter) -> Int { todos.filter { filter.includes($0, now: now) }.count }

    @discardableResult private func persist(_ updated: [Todo]) -> Bool {
        guard !isReadOnly else { error = "数据处于保护状态，暂时无法修改。请先检查本地数据文件。"; return false }
        do {
            if !isDemo { try repository.save(updated) }
            todos = updated
            if !isDemo { syncReminders() }
            return true
        } catch { self.error = "保存失败，原有数据未改变：\(error.localizedDescription)"; return false }
    }
    func save(_ todo: Todo) async throws -> Bool {
        let validated = try todo.validated()
        if let date = validated.reminderDate {
            let previous = todos.first { $0.id == todo.id }
            let reminderChanged = previous?.reminderDate != date
            if reminderChanged && date <= Date() { throw ValidationError("提醒时间已经过去，请调整截止日期或关闭提醒。") }
            if date > Date(), !isDemo { try await notifications.authorize() }
        }
        var copy = todos
        if let index = copy.firstIndex(where: { $0.id == todo.id }) { copy[index] = validated }
        else { copy.append(validated) }
        guard persist(copy) else { return false }
        showToast("已保存待办")
        return true
    }
    func quickAdd(_ title: String) {
        do {
            let todo = try Todo(title: title).validated()
            if persist(todos + [todo]) { showToast("已添加到待办") }
        } catch { self.error = error.localizedDescription }
    }
    func toggle(_ todo: Todo) {
        var copy = todos
        guard let index = copy.firstIndex(where: { $0.id == todo.id }) else { return }
        copy[index].completedAt = todo.isCompleted ? nil : Date()
        if persist(copy) { showToast(todo.isCompleted ? "已恢复待办" : "完成一件，轻盈一点。") }
    }
    func delete(_ todo: Todo) {
        if persist(todos.filter { $0.id != todo.id }) { deleted = todo; showToast("已删除待办，可撤销") }
    }
    func undoDelete() {
        guard let deleted, !todos.contains(where: { $0.id == deleted.id }) else { return }
        if persist(todos + [deleted]) { self.deleted = nil; showToast("已恢复待办") }
    }
    var canUndoDelete: Bool { deleted != nil }
    func newTodo() { todoEditor = Todo(title: "") }
    func newEvent(from todo: Todo? = nil) {
        let dayStart = Calendar.current.isDateInToday(selectedDay) ? Date() : Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: selectedDay)!
        var draft = EventDraft(now: todo?.dueDate ?? dayStart)
        if let todo { draft.title = todo.title; draft.notes = todo.notes }
        draft.calendarID = calendar.defaultCalendarID
        eventEditor = EventEditorContext(draft: draft, todoID: todo?.id)
    }
    func eventSaved(id: String, todoID: UUID?, day: Date) {
        if let todoID, let index = todos.firstIndex(where: { $0.id == todoID }) {
            var copy = todos; copy[index].calendarEventID = id
            if !persist(copy) { error = "日程已添加到系统日历，但待办关联保存失败。请勿重复添加。" }
        }
        selectedDay = day
        calendar.refresh(day: day)
        showToast("日程已添加到系统日历")
    }
    func refresh() {
        now = Date()
        calendar.refresh(day: selectedDay)
        if !isDemo && !isReadOnly { syncReminders() }
    }
    func showToast(_ message: String) {
        toastTask?.cancel(); toast = message
        toastTask = Task {
            try? await Task.sleep(for: .seconds(4))
            if !Task.isCancelled { toast = nil }
        }
    }
    private func syncReminders() { notifications.reconcile(todos) { [weak self] message in self?.error = message } }
    func revealData() { NSWorkspace.shared.activateFileViewerSelecting([repository.url]) }
}

struct EventEditorContext: Identifiable {
    let id = UUID()
    var draft: EventDraft
    var todoID: UUID?
}

import Foundation
import TodoCore

final class TodoCoreTests {
    var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return calendar
    }
    func date(_ year: Int = 2026, _ month: Int = 11, _ day: Int, _ hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }
    func testTodayIncludesOverdueAndUndatedButNotCompletedOrTomorrow() {
        let now = date(2026, 11, 6)
        expectTrue(TodoFilter.today.includes(Todo(title: "undated"), now: now, calendar: calendar))
        expectTrue(TodoFilter.today.includes(Todo(title: "overdue", dueDate: date(2026, 11, 5)), now: now, calendar: calendar))
        expectTrue(TodoFilter.today.includes(Todo(title: "later", dueDate: date(2026, 11, 6, 23)), now: now, calendar: calendar))
        expectFalse(TodoFilter.today.includes(Todo(title: "tomorrow", dueDate: date(2026, 11, 7, 0)), now: now, calendar: calendar))
        expectFalse(TodoFilter.today.includes(Todo(title: "done", completedAt: now), now: now, calendar: calendar))
    }
    func testUpcomingUsesCalendarDaysAcrossDaylightSaving() {
        let now = date(2026, 10, 31)
        expectTrue(TodoFilter.upcoming.includes(Todo(title: "first", dueDate: date(2026, 11, 1, 0)), now: now, calendar: calendar))
        expectTrue(TodoFilter.upcoming.includes(Todo(title: "last", dueDate: date(2026, 11, 7, 23)), now: now, calendar: calendar))
        expectFalse(TodoFilter.upcoming.includes(Todo(title: "outside", dueDate: date(2026, 11, 8, 0)), now: now, calendar: calendar))
    }
    func testReminderRemovedForCompletedAndUndatedTasks() throws {
        var todo = Todo(title: "test", dueDate: date(2026, 11, 6), reminderMinutes: 15)
        expectEqual(todo.reminderDate, todo.dueDate!.addingTimeInterval(-900))
        todo.completedAt = Date()
        expectNil(todo.reminderDate)
        todo.completedAt = nil; todo.dueDate = nil
        expectNil(try todo.validated().reminderMinutes)
        expectThrows(try Todo(title: " \n ").validated())
    }
    func testRepositoryPersistsEveryFieldAndDoesNotSilentlyResetCorruptData() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let repository = TodoRepository(url: folder.appendingPathComponent("todos.json"))
        expectEqual(try repository.load(), [])
        let todo = Todo(title: "中文待办 🫧", notes: "多行\n备注", dueDate: date(2026, 11, 6), reminderMinutes: 60, priority: .important, completedAt: Date(), calendarEventID: "event-id")
        try repository.save([todo])
        expectEqual(try repository.load(), [todo])
        try Data("invalid".utf8).write(to: repository.url)
        expectThrows(try repository.load())
        expectEqual(try String(contentsOf: repository.url, encoding: .utf8), "invalid")
    }
    func testAllDayEventUsesExclusiveEndAcrossDaylightSaving() throws {
        var draft = EventDraft(); draft.title = "全天"; draft.calendarID = "test"; draft.allDay = true
        draft.start = date(2026, 11, 1, 12); draft.end = draft.start
        let validated = try draft.validated(calendar: calendar)
        expectEqual(validated.start, date(2026, 11, 1, 0))
        expectEqual(validated.end, date(2026, 11, 2, 0))
        expectEqual(validated.end.timeIntervalSince(validated.start), 25 * 3600)
    }
    func testRepeatUntilIncludesLastDayAndRejectsEarlierDay() throws {
        var draft = EventDraft(); draft.title = "每周"; draft.calendarID = "test"
        draft.start = date(2026, 11, 6); draft.end = draft.start.addingTimeInterval(3600)
        draft.frequency = .weekly; draft.interval = 2; draft.repeatUntil = date(2026, 11, 20, 0)
        expectEqual(try draft.validated(calendar: calendar).repeatUntil, date(2026, 11, 21, 0).addingTimeInterval(-1))
        draft.repeatUntil = date(2026, 11, 5)
        expectThrows(try draft.validated(calendar: calendar))
    }
    func testInvalidEventsAreRejectedBeforeCalendarWrite() {
        var draft = EventDraft(); draft.title = "test"; draft.calendarID = "test"; draft.end = draft.start
        expectThrows(try draft.validated())
        draft.end = draft.start.addingTimeInterval(3600); draft.interval = 0
        expectThrows(try draft.validated())
        draft.interval = 1; draft.calendarID = ""
        expectThrows(try draft.validated())
    }
    func testCalendarGridIncludesLeapDayAndUsesWholeDaysAcrossDST() {
        let leapGrid = DateSelection.monthDays(containing: date(2028, 2, 20), calendar: calendar)
        expectEqual(leapGrid.count, 42)
        expectEqual(calendar.component(.weekday, from: leapGrid[0]), 2)
        expectTrue(leapGrid.contains(date(2028, 2, 29, 0)))
        let springGrid = DateSelection.monthDays(containing: date(2026, 3, 31), calendar: calendar)
        expectEqual(Set(springGrid).count, 42)
        expectTrue(springGrid.allSatisfy { calendar.component(.hour, from: $0) == 0 })
        expectTrue(springGrid.contains(date(2026, 3, 8, 0)))
        expectTrue(springGrid.contains(date(2026, 3, 9, 0)))
    }
    func testDateControlsPreserveLocalTimeAndNormalizeMissingDSTHour() {
        let before = calendar.date(from: DateComponents(year: 2026, month: 3, day: 7, hour: 9, minute: 45))!
        let selected = DateSelection.replacingDay(in: before, with: date(2026, 3, 8), calendar: calendar)
        expectEqual(calendar.component(.day, from: selected), 8)
        expectEqual(calendar.component(.hour, from: selected), 9)
        expectEqual(calendar.component(.minute, from: selected), 45)
        expectEqual(selected.timeIntervalSince(before), 23 * 3600)
        let missingHour = DateSelection.replacingTime(in: selected, hour: 2, minute: 30, calendar: calendar)
        expectEqual(missingHour, date(2026, 3, 8, 3))
        let endOfDay = DateSelection.replacingTime(in: selected, hour: 23, minute: 59, calendar: calendar)
        expectEqual(calendar.component(.day, from: endOfDay), 8)
        expectEqual(calendar.component(.hour, from: endOfDay), 23)
        expectEqual(calendar.component(.minute, from: endOfDay), 59)
    }
}

private func expectTrue(_ value: Bool, file: StaticString = #filePath, line: UInt = #line) {
    precondition(value, "Expected true at \(file):\(line)")
}
private func expectFalse(_ value: Bool, file: StaticString = #filePath, line: UInt = #line) {
    precondition(!value, "Expected false at \(file):\(line)")
}
private func expectEqual<T: Equatable>(_ left: T, _ right: T, file: StaticString = #filePath, line: UInt = #line) {
    precondition(left == right, "Expected \(left) == \(right) at \(file):\(line)")
}
private func expectNil<T>(_ value: T?, file: StaticString = #filePath, line: UInt = #line) {
    precondition(value == nil, "Expected nil at \(file):\(line)")
}
private func expectThrows<T>(_ operation: @autoclosure () throws -> T, file: StaticString = #filePath, line: UInt = #line) {
    do { _ = try operation() } catch { return }
    preconditionFailure("Expected an error at \(file):\(line)")
}

@main
struct CheckRunner {
    static func main() throws {
        let tests = TodoCoreTests()
        let cases: [(String, () throws -> Void)] = [
            ("today filter", tests.testTodayIncludesOverdueAndUndatedButNotCompletedOrTomorrow),
            ("upcoming DST boundaries", tests.testUpcomingUsesCalendarDaysAcrossDaylightSaving),
            ("reminder lifecycle", tests.testReminderRemovedForCompletedAndUndatedTasks),
            ("disk persistence and corruption", tests.testRepositoryPersistsEveryFieldAndDoesNotSilentlyResetCorruptData),
            ("all-day DST semantics", tests.testAllDayEventUsesExclusiveEndAcrossDaylightSaving),
            ("inclusive recurrence end", tests.testRepeatUntilIncludesLastDayAndRejectsEarlierDay),
            ("event validation", tests.testInvalidEventsAreRejectedBeforeCalendarWrite),
            ("calendar grid leap day and DST", tests.testCalendarGridIncludesLeapDayAndUsesWholeDaysAcrossDST),
            ("date controls preserve wall-clock time", tests.testDateControlsPreserveLocalTimeAndNormalizeMissingDSTHour)
        ]
        for (name, test) in cases { try test(); print("PASS: \(name)") }
        print("All \(cases.count) checks passed.")
    }
}

import Foundation

extension Date {
    /// Start of the calendar day for this date.
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }

    /// Start of the current month containing this date.
    var startOfMonth: Date {
        let components = Calendar.current.dateComponents([.year, .month], from: self)
        return Calendar.current.date(from: components) ?? self
    }

    /// End of the current month containing this date.
    var endOfMonth: Date {
        guard let next = Calendar.current.date(byAdding: .month, value: 1, to: startOfMonth) else {
            return self
        }
        return next.addingTimeInterval(-1)
    }

    /// Start of the week containing this date (locale-aware).
    var startOfWeek: Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: self)
        return calendar.date(from: components) ?? self
    }

    /// Whether this date falls on the same calendar day as another.
    func isSameDay(as other: Date) -> Bool {
        Calendar.current.isDate(self, inSameDayAs: other)
    }

    /// Whether this date is in the current calendar month.
    var isThisMonth: Bool {
        Calendar.current.isDate(self, equalTo: .now, toGranularity: .month)
    }

    /// Relative day label: Today, Yesterday, or formatted date.
    var relativeDayLabel: String {
        if Calendar.current.isDateInToday(self) {
            return "Today"
        }
        if Calendar.current.isDateInYesterday(self) {
            return "Yesterday"
        }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: self)
    }

    /// Short weekday abbreviation (Mon, Tue, …).
    var shortWeekday: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: self)
    }

    /// Month and year display string.
    var monthYearLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: self)
    }
}

extension Calendar {
    /// Ordered dates for the last `count` days ending today.
    func lastDays(_ count: Int, endingAt end: Date = .now) -> [Date] {
        (0..<count).reversed().compactMap { offset in
            date(byAdding: .day, value: -offset, to: end.startOfDay)
        }
    }
}

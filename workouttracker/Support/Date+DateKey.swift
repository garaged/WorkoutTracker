import Foundation

extension Date {
    func dayKey(calendar: Calendar = .current) -> String {
        let d = calendar.startOfDay(for: self)
        let c = calendar.dateComponents([.year, .month, .day], from: d)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}

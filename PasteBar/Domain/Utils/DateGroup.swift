import Foundation

enum DateGroup {
  static func title(for date: Date, calendar: Calendar = .current) -> String {
    if calendar.isDateInToday(date) {
      return "Today"
    }
    if calendar.isDateInYesterday(date) {
      return "Yesterday"
    }
    return "Earlier"
  }
}

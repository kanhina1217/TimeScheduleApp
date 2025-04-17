import SwiftUI
import CoreData

// Timetableエンティティの拡張
extension Timetable {
    // 曜日を文字列で取得
    var dayOfWeekString: String {
        let days = ["月", "火", "水", "木", "金", "土", "日"]
        let index = min(max(Int(dayOfWeek), 0), days.count - 1)
        return days[index]
    }
    
    // 時限を文字列で取得
    var periodString: String {
        return "\(period)限"
    }
    
    // 関連付けられた色の取得
    var displayColor: Color {
        guard let colorName = color else { return .gray }
        
        switch colorName {
        case "red": return .red
        case "blue": return .blue
        case "green": return .green
        case "yellow": return .yellow
        case "purple": return .purple
        default: return .gray
        }
    }
}

// Patternエンティティの拡張
extension Pattern {
    var displayName: String {
        return name ?? "不明なパターン"
    }
}

// Subjectエンティティの拡張
extension Subject {
    var displayColor: Color {
        guard let colorName = color else { return .gray }
        
        switch colorName {
        case "red": return .red
        case "blue": return .blue
        case "green": return .green
        case "yellow": return .yellow
        case "purple": return .purple
        default: return .gray
        }
    }
}

// Attendanceエンティティの拡張
extension Attendance {
    var statusString: String {
        return isPresent ? "出席" : "欠席"
    }
    
    var formattedDate: String {
        guard let date = date else { return "日付なし" }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "ja_JP")
        
        return formatter.string(from: date)
    }
}
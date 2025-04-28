import SwiftUI
import CoreData

/**
 * 時程パターンについて
 * 
 * 時程パターンは各時限（1限、2限...）の開始時刻と終了時刻を表し、
 * 「通常」「短縮」などの授業時間の異なるスケジュールを管理します。
 * 時間割自体（どの教科がどのコマに配置されるか）は変わらず、
 * 時程パターンが変わるとその時間帯だけが変わります。
 */

// MARK: - エンティティ拡張
// Timetableエンティティの拡張
extension Timetable {
    // 曜日を文字列で取得
    var dayOfWeekString: String {
        let days = ["日", "月", "火", "水", "木", "金", "土"]
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
    
    // 各時限の時間情報を取得
    var periodTimeArray: [[String: String]] {
        guard let timesData = periodTimes as? [[String: String]] else {
            return []
        }
        return timesData
    }
    
    // 特定の時限の開始時間を取得
    func startTimeForPeriod(_ period: Int) -> String {
        let times = periodTimeArray
        guard period > 0, period <= times.count else {
            return "--:--"
        }
        
        return times[period-1]["startTime"] ?? "--:--"
    }
    
    // 特定の時限の終了時間を取得
    func endTimeForPeriod(_ period: Int) -> String {
        let times = periodTimeArray
        guard period > 0, period <= times.count else {
            return "--:--"
        }
        
        return times[period-1]["endTime"] ?? "--:--"
    }
    
    // 時限の合計数を取得
    var periodCount: Int {
        return periodTimeArray.count
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
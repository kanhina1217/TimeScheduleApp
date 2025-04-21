import WidgetKit
import SwiftUI

struct TimetableWidgetEntryView: View {
    var entry: TimetableWidgetProvider.Entry
    @Environment(\.widgetFamily) var family
    @Environment(\.colorScheme) var colorScheme
    
    // 曜日表示のための配列
    private let weekdayNames = ["日", "月", "火", "水", "木", "金", "土"]
    
    // 曜日ごとのテーマカラー
    private func themeColorForWeekday(_ weekday: Int) -> Color {
        switch weekday {
        case 1: return Color(.systemRed).opacity(0.9) // 日曜日
        case 2: return Color(.systemBlue).opacity(0.9) // 月曜日
        case 3: return Color(.systemOrange).opacity(0.9) // 火曜日
        case 4: return Color(.systemGreen).opacity(0.9) // 水曜日
        case 5: return Color(.systemYellow).opacity(0.9) // 木曜日
        case 6: return Color(.systemPink).opacity(0.9) // 金曜日
        case 7: return Color(.systemPurple).opacity(0.9) // 土曜日
        default: return Color(.systemBlue).opacity(0.9)
        }
    }
    
    // 科目名からカラーを取得 - 改良版でより鮮やかな色を提供
    private func colorForSubject(_ subject: String) -> Color {
        let colors: [Color] = [
            Color.blue.opacity(0.8),
            Color.green.opacity(0.75),
            Color.orange.opacity(0.8),
            Color.pink.opacity(0.75),
            Color.purple.opacity(0.8),
            Color.teal.opacity(0.75),
            Color.red.opacity(0.7),
            Color.indigo.opacity(0.8),
            Color.mint.opacity(0.75),
            Color.cyan.opacity(0.8)
        ]
        
        // 科目名から一貫性のあるカラーを生成
        var hash = 0
        for char in subject ?? "" {
            hash = ((hash << 5) &+ hash) &+ Int(char.asciiValue ?? 0)
        }
        
        return colors[abs(hash) % colors.count]
    }
    
    // 時間帯を整形して表示
    private func formatTimeSlot(_ timeSlot: String?) -> String {
        guard let timeSlot = timeSlot else { return "時間未定" }
        
        let components = timeSlot.split(separator: "-")
        if components.count == 2 {
            return "\(components[0].trimmingCharacters(in: .whitespaces))～\(components[1].trimmingCharacters(in: .whitespaces))"
        }
        return timeSlot
    }
    
    // 日付をフォーマット
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
    }
    
    // 曜日を取得
    private func getWeekday(_ date: Date) -> Int {
        let calendar = Calendar.current
        return calendar.component(.weekday, from: date)
    }
    
    // 現在時刻に最も近い授業を強調表示するかどうかを判断
    private func shouldHighlight(_ timeSlot: String?) -> Bool {
        guard let timeSlot = timeSlot else { return false }
        
        let now = Date()
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)
        let currentTime = hour * 60 + minute
        
        let components = timeSlot.split(separator: "-")
        if components.count == 2 {
            let startStr = components[0].trimmingCharacters(in: .whitespaces)
            let startComponents = startStr.split(separator: ":")
            if startComponents.count == 2,
               let startHour = Int(startComponents[0]),
               let startMinute = Int(startComponents[1]) {
                let startTime = startHour * 60 + startMinute
                
                let endStr = components[1].trimmingCharacters(in: .whitespaces)
                let endComponents = endStr.split(separator: ":")
                if endComponents.count == 2,
                   let endHour = Int(endComponents[0]),
                   let endMinute = Int(endComponents[1]) {
                    let endTime = endHour * 60 + endMinute
                    
                    // 現在時刻が授業の30分前から終了時間までの間なら強調表示
                    return currentTime >= (startTime - 30) && currentTime <= endTime
                }
            }
        }
        return false
    }
    
    var body: some View {
        let weekday = getWeekday(entry.date)
        let themeColor = themeColorForWeekday(weekday)
        
        VStack(spacing: 0) {
            // ヘッダー部分 - 日付と曜日
            HStack {
                Text("\(formatDate(entry.date))(\(weekdayNames[weekday - 1]))")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(themeColor)
                    )
                
                Spacer()
                
                Text("今日の時間割")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.trailing, 4)
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 4)
            
            // メインコンテンツ - 時間割一覧
            if entry.timetableItems.isEmpty {
                Spacer()
                VStack(spacing: 6) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 24))
                        .foregroundColor(.secondary)
                    
                    Text("今日の授業はありません")
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(UIColor.systemBackground).opacity(0.6))
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(entry.timetableItems, id: \.self) { item in
                            let isHighlighted = shouldHighlight(item.startTime)
                            
                            HStack(alignment: .center, spacing: 8) {
                                // 時間表示
                                VStack(alignment: .leading) {
                                    Text(item.period ?? "")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    
                                    Text(formatTimeSlot(item.startTime))
                                        .font(.caption)
                                        .foregroundColor(isHighlighted ? .primary : .secondary)
                                        .fontWeight(isHighlighted ? .semibold : .regular)
                                }
                                .frame(width: 60, alignment: .leading)
                                
                                // 科目情報
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.subject ?? "未定")
                                        .font(.system(size: 15, weight: isHighlighted ? .bold : .semibold))
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                    
                                    HStack(spacing: 4) {
                                        if let teacher = item.teacher, !teacher.isEmpty {
                                            HStack(spacing: 2) {
                                                Image(systemName: "person")
                                                    .font(.system(size: 9))
                                                Text(teacher)
                                                    .font(.caption2)
                                            }
                                            .foregroundColor(.secondary)
                                        }
                                        
                                        if let room = item.room, !room.isEmpty {
                                            HStack(spacing: 2) {
                                                Image(systemName: "mappin.circle")
                                                    .font(.system(size: 9))
                                                Text(room)
                                                    .font(.caption2)
                                            }
                                            .foregroundColor(.secondary)
                                        }
                                    }
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(
                                            colorForSubject(item.subject ?? "")
                                                .opacity(isHighlighted ? 0.3 : 0.15)
                                        )
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(
                                            colorForSubject(item.subject ?? ""),
                                            lineWidth: isHighlighted ? 1.5 : 0.5
                                        )
                                )
                            }
                            .padding(.horizontal, 12)
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .background(Color(UIColor.systemBackground).opacity(0.2))
    }
}
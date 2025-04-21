import WidgetKit
import SwiftUI

struct TimetableWidgetEntryView: View {
    var entry: TimetableWidgetEntry
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
        for char in subject {
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
    
    // 授業の状態（これから、進行中、終了）を判断
    private func getClassStatus(_ timeSlot: String?) -> ClassStatus {
        guard let timeSlot = timeSlot else { return .upcoming }
        
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
                    
                    if currentTime < startTime {
                        return .upcoming
                    } else if currentTime <= endTime {
                        return .inProgress
                    } else {
                        return .completed
                    }
                }
            }
        }
        return .upcoming
    }
    
    // 授業の状態を表すenum
    enum ClassStatus {
        case upcoming, inProgress, completed
        
        var icon: String {
            switch self {
            case .upcoming: return "clock"
            case .inProgress: return "person.wave.2.fill"
            case .completed: return "checkmark.circle"
            }
        }
        
        var color: Color {
            switch self {
            case .upcoming: return Color.blue
            case .inProgress: return Color.green
            case .completed: return Color.gray.opacity(0.6)
            }
        }
        
        var opacity: Double {
            switch self {
            case .upcoming: return 1.0
            case .inProgress: return 1.0
            case .completed: return 0.6
            }
        }
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
                        RoundedRectangle(cornerRadius: 10)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [themeColor, themeColor.opacity(0.7)]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .shadow(color: themeColor.opacity(0.3), radius: 2, x: 0, y: 1)
                    )
                
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.caption)
                    Text("今日の時間割")
                        .font(.caption)
                }
                .foregroundColor(.secondary)
                .padding(.trailing, 4)
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 6)
            
            // メインコンテンツ - 時間割一覧
            if entry.timetableItems.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "calendar.badge.exclamationmark")
                        .font(.system(size: 28))
                        .foregroundColor(themeColor)
                    
                    Text("今日の授業はありません")
                        .font(.callout)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(20)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                Spacer()
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 10) {
                        ForEach(Array(entry.timetableItems.enumerated()), id: \.element.hashValue) { index, item in
                            let classStatus = getClassStatus(item.startTime)
                            
                            HStack(alignment: .center, spacing: 10) {
                                // 時間表示
                                VStack(alignment: .center, spacing: 2) {
                                    Text(item.period ?? "")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(colorForSubject(item.subject ?? ""))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 2)
                                        .background(
                                            RoundedRectangle(cornerRadius: 6)
                                                .fill(colorForSubject(item.subject ?? "").opacity(0.15))
                                        )
                                    
                                    Text(formatTimeSlot(item.startTime))
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                        .fontWeight(.medium)
                                }
                                .frame(width: 65, alignment: .center)
                                
                                // 授業の状態インジケーター
                                Rectangle()
                                    .fill(classStatus.color)
                                    .frame(width: 3, height: family == .systemSmall ? 30 : 40)
                                    .cornerRadius(1.5)
                                
                                // 科目情報
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(item.subject ?? "未定")
                                        .font(.system(size: family == .systemSmall ? 14 : 15, weight: .bold))
                                        .foregroundColor(classStatus == .completed ? .secondary : .primary)
                                        .lineLimit(1)
                                        .opacity(classStatus.opacity)
                                    
                                    if family != .systemSmall || index == 0 {
                                        HStack(spacing: 8) {
                                            if let teacher = item.teacher, !teacher.isEmpty {
                                                HStack(spacing: 3) {
                                                    Image(systemName: "person.fill")
                                                        .font(.system(size: 8))
                                                    Text(teacher)
                                                        .font(.system(size: 10))
                                                        .lineLimit(1)
                                                }
                                                .foregroundColor(.secondary)
                                                .opacity(classStatus.opacity)
                                            }
                                            
                                            if let room = item.room, !room.isEmpty {
                                                HStack(spacing: 3) {
                                                    Image(systemName: "mappin.circle.fill")
                                                        .font(.system(size: 8))
                                                    Text(room)
                                                        .font(.system(size: 10))
                                                        .lineLimit(1)
                                                }
                                                .foregroundColor(.secondary)
                                                .opacity(classStatus.opacity)
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(
                                            colorForSubject(item.subject ?? "")
                                                .opacity(classStatus == .inProgress ? 0.25 : 0.1)
                                        )
                                )
                                
                                // ステータスアイコン
                                Image(systemName: classStatus.icon)
                                    .font(.system(size: 12))
                                    .foregroundColor(classStatus.color)
                                    .frame(width: 20)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(UIColor.systemBackground))
                                    .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                            )
                            .padding(.horizontal, 8)
                            .opacity(classStatus == .completed ? 0.8 : 1)
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.bottom, 4)
                }
            }
        }
        .overlay(
            Rectangle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            themeColor.opacity(0.15),
                            Color.clear
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .allowsHitTesting(false)
        )
    }
}

// プレビュー用のコード（既存のままで構いません）
struct TimetableWidgetEntryView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleItems = [
            TimeTableItem(subject: "プログラミング", startTime: "9:00-10:30", teacher: "山田先生", room: "A101", period: "1限目"),
            TimeTableItem(subject: "データベース", startTime: "10:40-12:10", teacher: "鈴木先生", room: "B201", period: "2限目"),
            TimeTableItem(subject: "AI入門", startTime: "13:00-14:30", teacher: "佐藤先生", room: "C301", period: "3限目")
        ]
        
        let entry = TimetableWidgetEntry(date: Date(), timetableItems: sampleItems)
        
        Group {
            TimetableWidgetEntryView(entry: entry)
                .previewContext(WidgetPreviewContext(family: .systemMedium))
                .previewDisplayName("システム 中")
            
            TimetableWidgetEntryView(entry: entry)
                .previewContext(WidgetPreviewContext(family: .systemSmall))
                .previewDisplayName("システム 小")
                
            // ダークモード
            TimetableWidgetEntryView(entry: entry)
                .previewContext(WidgetPreviewContext(family: .systemMedium))
                .environment(\.colorScheme, .dark)
                .previewDisplayName("ダークモード 中")
        }
    }
}
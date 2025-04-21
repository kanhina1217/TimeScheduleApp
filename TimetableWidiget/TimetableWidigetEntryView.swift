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
        case 1: return Color.red // 日曜日
        case 2: return Color.blue // 月曜日
        case 3: return Color.orange // 火曜日
        case 4: return Color.green // 水曜日
        case 5: return Color.yellow // 木曜日
        case 6: return Color.pink // 金曜日
        case 7: return Color.purple // 土曜日
        default: return Color.blue
        }
    }
    
    // 科目名からカラーを取得
    private func colorForSubject(_ subject: String) -> Color {
        let colors: [Color] = [
            .blue,
            .green,
            .orange,
            .pink,
            .purple,
            .teal,
            .red,
            .indigo,
            .mint,
            .cyan
        ]
        
        // 科目名から一貫性のあるカラーを生成
        var hash = 0
        for char in subject {
            hash = ((hash << 5) &+ hash) &+ Int(char.asciiValue ?? 0)
        }
        
        return colors[abs(hash) % colors.count]
    }
    
    // 時間帯を整形して表示（シンプルバージョン）
    private func formatTimeSlot(_ timeSlot: String?) -> String {
        guard let timeSlot = timeSlot else { return "未定" }
        
        let components = timeSlot.split(separator: "-")
        if components.count == 2 {
            let start = components[0].trimmingCharacters(in: .whitespaces)
            let end = components[1].trimmingCharacters(in: .whitespaces)
            
            // 時間のみを表示（短縮バージョン）
            if let startColon = start.firstIndex(of: ":"),
               let endColon = end.firstIndex(of: ":") {
                let startHour = start[..<startColon]
                let endHour = end[..<endColon]
                return "\(startHour)〜\(endHour)"
            }
            
            return "\(start)〜\(end)"
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
    
    // 現在進行中または近い未来の授業かどうかを判断
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
                        // 30分以内に始まる場合は「もうすぐ」
                        if startTime - currentTime <= 30 {
                            return .soon
                        }
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
    
    // 授業の状態
    enum ClassStatus {
        case upcoming, soon, inProgress, completed
        
        var color: Color {
            switch self {
            case .upcoming: return Color.gray
            case .soon: return Color.orange
            case .inProgress: return Color.green
            case .completed: return Color.gray.opacity(0.5)
            }
        }
        
        var textColor: Color {
            switch self {
            case .upcoming: return Color.primary
            case .soon: return Color.orange
            case .inProgress: return Color.green
            case .completed: return Color.secondary
            }
        }
        
        var badge: String? {
            switch self {
            case .inProgress: return "NOW"
            case .soon: return "SOON"
            case .upcoming, .completed: return nil
            }
        }
        
        var opacity: Double {
            switch self {
            case .upcoming: return 0.9
            case .soon: return 1.0
            case .inProgress: return 1.0
            case .completed: return 0.7
            }
        }
    }
    
    var body: some View {
        let weekday = getWeekday(entry.date)
        let themeColor = themeColorForWeekday(weekday)
        
        ZStack {
            // 背景
            Color(UIColor.systemBackground)
                .edgesIgnoringSafeArea(.all)
            
            // 曜日カラーの背景アクセント
            VStack {
                HStack {
                    Rectangle()
                        .fill(themeColor)
                        .frame(width: 5)
                        .edgesIgnoringSafeArea(.leading)
                    Spacer()
                }
                .frame(height: 40)
                Spacer()
            }
            
            VStack(spacing: 4) {
                // ヘッダー
                HStack {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("\(formatDate(entry.date)) (\(weekdayNames[weekday - 1]))")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.primary)
                        
                        Text("時間割")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if !entry.timetableItems.isEmpty {
                        Text("\(entry.timetableItems.count)コマ")
                            .font(.system(size: 12, weight: .bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(themeColor.opacity(0.2))
                            )
                            .foregroundColor(themeColor)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)
                
                // 授業リスト
                if entry.timetableItems.isEmpty {
                    // 授業がない場合
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(.system(size: 36))
                            .foregroundColor(themeColor.opacity(0.8))
                        
                        Text("今日の授業はありません")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 20)
                    Spacer()
                } else {
                    // 授業がある場合
                    LazyVStack(spacing: family == .systemSmall ? 8 : 10) {
                        ForEach(entry.timetableItems.prefix(family == .systemSmall ? 3 : 5), id: \.self) { item in
                            let status = getClassStatus(item.startTime)
                            
                            ClassItemView(
                                item: item,
                                status: status,
                                themeColor: colorForSubject(item.subject ?? ""),
                                family: family
                            )
                            .padding(.horizontal, 16)
                        }
                        
                        // 表示しきれない授業がある場合
                        if (family == .systemSmall && entry.timetableItems.count > 3) ||
                           (family != .systemSmall && entry.timetableItems.count > 5) {
                            HStack {
                                Spacer()
                                Text("他 \(entry.timetableItems.count - (family == .systemSmall ? 3 : 5))コマ")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            .padding(.top, 4)
                        }
                    }
                    .padding(.bottom, 12)
                    
                    Spacer(minLength: 0)
                }
            }
        }
    }
}

// 授業アイテムのサブビュー
struct ClassItemView: View {
    let item: TimeTableItem
    let status: TimetableWidgetEntryView.ClassStatus
    let themeColor: Color
    let family: WidgetFamily
    
    // 時間帯を整形して表示
    private func formatTimeSlot(_ timeSlot: String?) -> String {
        guard let timeSlot = timeSlot else { return "未定" }
        
        let components = timeSlot.split(separator: "-")
        if components.count == 2 {
            let start = components[0].trimmingCharacters(in: .whitespaces)
            let end = components[1].trimmingCharacters(in: .whitespaces)
            return "\(start)～\(end)"
        }
        return timeSlot
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // 時限と時間
            VStack(alignment: .center, spacing: 2) {
                Text(item.period ?? "")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(themeColor)
                    )
                    .shadow(color: themeColor.opacity(0.3), radius: 1, x: 0, y: 1)
                
                if family != .systemSmall {
                    Text(formatTimeSlot(item.startTime))
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: family == .systemSmall ? 40 : 50)
            
            // 科目情報
            VStack(alignment: .leading, spacing: family == .systemSmall ? 0 : 2) {
                HStack(alignment: .center) {
                    Text(item.subject ?? "未定")
                        .font(.system(size: family == .systemSmall ? 13 : 14, weight: .bold))
                        .foregroundColor(status.textColor)
                        .lineLimit(1)
                    
                    if let badge = status.badge {
                        Text(badge)
                            .font(.system(size: 8, weight: .black))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(status.color)
                            )
                            .foregroundColor(.white)
                    }
                    
                    Spacer(minLength: 0)
                }
                
                if family != .systemSmall {
                    HStack(spacing: 8) {
                        if let room = item.room, !room.isEmpty {
                            HStack(spacing: 3) {
                                Image(systemName: "mappin")
                                    .font(.system(size: 8))
                                Text(room)
                                    .font(.system(size: 10))
                                    .lineLimit(1)
                            }
                            .foregroundColor(.secondary)
                        }
                        
                        if let teacher = item.teacher, !teacher.isEmpty {
                            HStack(spacing: 3) {
                                Image(systemName: "person")
                                    .font(.system(size: 8))
                                Text(teacher)
                                    .font(.system(size: 10))
                                    .lineLimit(1)
                            }
                            .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(UIColor.secondarySystemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 1, x: 0, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    status == .inProgress ? themeColor : Color.clear,
                    lineWidth: status == .inProgress ? 1.5 : 0
                )
        )
        .opacity(status.opacity)
        .contentShape(Rectangle())
    }
}

// プレビュー用のコード
struct TimetableWidgetEntryView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleItems = [
            TimeTableItem(subject: "プログラミング", startTime: "9:00-10:30", teacher: "山田先生", room: "A101", period: "1限"),
            TimeTableItem(subject: "データベース", startTime: "10:40-12:10", teacher: "鈴木先生", room: "B201", period: "2限"),
            TimeTableItem(subject: "AI入門", startTime: "13:00-14:30", teacher: "佐藤先生", room: "C301", period: "3限"),
            TimeTableItem(subject: "アルゴリズム", startTime: "14:40-16:10", teacher: "高橋先生", room: "D401", period: "4限"),
            TimeTableItem(subject: "英語コミュニケーション", startTime: "16:20-17:50", teacher: "田中先生", room: "E501", period: "5限")
        ]
        
        let entry = TimetableWidgetEntry(date: Date(), timetableItems: sampleItems)
        
        Group {
            TimetableWidgetEntryView(entry: entry)
                .previewContext(WidgetPreviewContext(family: .systemMedium))
                .previewDisplayName("中サイズ")
            
            TimetableWidgetEntryView(entry: entry)
                .previewContext(WidgetPreviewContext(family: .systemSmall))
                .previewDisplayName("小サイズ")
                
            // ダークモード
            TimetableWidgetEntryView(entry: entry)
                .previewContext(WidgetPreviewContext(family: .systemMedium))
                .environment(\.colorScheme, .dark)
                .previewDisplayName("ダークモード")
            
            // 授業なし
            TimetableWidgetEntryView(entry: TimetableWidgetEntry(date: Date(), timetableItems: []))
                .previewContext(WidgetPreviewContext(family: .systemMedium))
                .previewDisplayName("授業なし")
        }
    }
}
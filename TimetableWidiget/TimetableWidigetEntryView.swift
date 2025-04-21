import WidgetKit
import SwiftUI

struct TimetableWidgetEntryView: View {
    var entry: TimetableWidgetEntry
    @Environment(\.widgetFamily) var family
    @Environment(\.colorScheme) var colorScheme
    
    // デバッグモードのフラグ（実機でデバッグ情報を表示するかどうか）
    #if DEBUG
    private let showDebugInfo = true
    #else
    private let showDebugInfo = false
    #endif
    
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
    
    // 日付をフォーマット
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
    }
    
    // デバッグ用の日付フォーマット
    private func formatDebugDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm:ss"
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
                    
                    // 今日がその曜日なら状態を判定、そうでなければupcoming
                    let today = Calendar.current.component(.weekday, from: now)
                    let entryDay = getWeekday(entry.date)
                    
                    if today != entryDay {
                        return .upcoming // 今日の曜日でなければすべて予定として表示
                    }
                    
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
            
            VStack(spacing: 0) {
                // ヘッダー
                HStack {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("\(weekdayNames[weekday - 1])曜日")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(themeColor)
                        
                        if showDebugInfo {
                            Text("(weekday: \(weekday), items: \(entry.timetableItems.count))")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        } else {
                            Text("時間割")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                        }
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
                .padding(.top, 14)
                .padding(.bottom, 8)
                .background(
                    Rectangle()
                        .fill(themeColor.opacity(0.1))
                        .edgesIgnoringSafeArea(.top)
                )
                
                // 授業リスト
                if entry.timetableItems.isEmpty {
                    // 授業がない場合
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(.system(size: 36))
                            .foregroundColor(themeColor.opacity(0.8))
                        
                        Text("\(weekdayNames[weekday - 1])曜日の授業はありません")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        if showDebugInfo {
                            Text("更新: \(formatDebugDate(entry.date))")
                                .font(.system(size: 10))
                                .foregroundColor(.gray)
                                .padding(.top, 8)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 20)
                    Spacer()
                } else {
                    // 授業がある場合
                    ScrollView {
                        LazyVStack(spacing: family == .systemSmall ? 6 : 8) {
                            ForEach(entry.timetableItems.prefix(family == .systemSmall ? 3 : 6), id: \.self) { item in
                                let status = getClassStatus(item.startTime)
                                
                                ClassItemView(
                                    item: item,
                                    status: status,
                                    themeColor: colorForSubject(item.subject ?? ""),
                                    family: family
                                )
                            }
                            
                            // 表示しきれない授業がある場合
                            if (family == .systemSmall && entry.timetableItems.count > 3) ||
                               (family != .systemSmall && entry.timetableItems.count > 6) {
                                HStack {
                                    Spacer()
                                    Text("他 \(entry.timetableItems.count - (family == .systemSmall ? 3 : 6))コマ")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                }
                                .padding(.top, 4)
                            }
                            
                            // デバッグ情報
                            if showDebugInfo {
                                Text("更新: \(formatDebugDate(entry.date))")
                                    .font(.system(size: 10))
                                    .foregroundColor(.gray)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(.top, 8)
                            }
                        }
                        .padding(.vertical, 8)
                    }
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
        HStack(spacing: 10) {
            // 時限表示
            Text(item.period ?? "")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(themeColor)
                .frame(width: 35, alignment: .center)
            
            // 縦の区切り線
            Rectangle()
                .fill(themeColor.opacity(0.6))
                .frame(width: 2, height: family == .systemSmall ? 30 : 36)
            
            // 科目情報
            VStack(alignment: .leading, spacing: family == .systemSmall ? 1 : 3) {
                HStack(alignment: .center, spacing: 6) {
                    Text(item.subject ?? "未定")
                        .font(.system(size: family == .systemSmall ? 13 : 15, weight: .bold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    if let badge = status.badge {
                        Text(badge)
                            .font(.system(size: 8, weight: .bold))
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
                
                HStack(spacing: 12) {
                    Text(formatTimeSlot(item.startTime))
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    
                    if family != .systemSmall {
                        if let room = item.room, !room.isEmpty {
                            HStack(spacing: 3) {
                                Image(systemName: "mappin")
                                    .font(.system(size: 9))
                                Text(room)
                                    .font(.system(size: 10))
                                    .lineLimit(1)
                            }
                            .foregroundColor(.secondary)
                        }
                        
                        if let teacher = item.teacher, !teacher.isEmpty {
                            HStack(spacing: 3) {
                                Image(systemName: "person")
                                    .font(.system(size: 9))
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
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(UIColor.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(status == .inProgress ? themeColor : Color.clear, lineWidth: 2)
        )
        .padding(.horizontal, 12)
        .opacity(status.opacity)
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
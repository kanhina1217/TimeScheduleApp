import WidgetKit
import SwiftUI

struct TimetableWidgetEntryView: View {
    var entry: TimetableWidgetEntry
    @Environment(\.widgetFamily) var family
    @Environment(\.colorScheme) var colorScheme
    
    // 曜日表示のための配列
    private let weekdayNames = ["日", "月", "火", "水", "木", "金", "土"]
    
    // 曜日を取得
    private func getWeekday(_ date: Date) -> Int {
        let calendar = Calendar.current
        return calendar.component(.weekday, from: date)
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
    
    var body: some View {
        // 今日の曜日を取得
        let weekday = getWeekday(Date())
        
        ZStack {
            // 背景
            Color(UIColor.systemBackground)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 6) {
                // ヘッダー
                HStack {
                    Text("\(weekdayNames[weekday - 1])曜日の時間割")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text("\(entry.timetableItems.count)コマ")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 2)
                
                if entry.timetableItems.isEmpty {
                    // 授業がない場合
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(.system(size: 24))
                            .foregroundColor(.secondary)
                        
                        Text("今日の授業はありません")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    Spacer()
                } else {
                    // 表示件数の制限
                    let maxItems = family == .systemSmall ? 2 : 5
                    let displayItems = entry.timetableItems.prefix(maxItems)
                    
                    // 授業カードを表示
                    if family == .systemSmall {
                        // 小サイズは縦に表示
                        VStack(spacing: 8) {
                            ForEach(Array(displayItems.enumerated()), id: \.element.hashValue) { index, item in
                                ClassCardView(item: item)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.bottom, 8)
                    } else {
                        // 中サイズは横スクロール
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(Array(displayItems.enumerated()), id: \.element.hashValue) { index, item in
                                    ClassCardView(item: item)
                                        .frame(width: 90)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.bottom, 8)
                        }
                    }
                }
            }
        }
    }
}

// 授業カードのサブビュー
struct ClassCardView: View {
    let item: TimeTableItem
    
    // 授業が現在進行中かどうかを判定
    private func isCurrentClass() -> Bool {
        guard let timeSlot = item.startTime else { return false }
        
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
                    
                    return currentTime >= startTime && currentTime <= endTime
                }
            }
        }
        return false
    }
    
    // 科目名からカラーを取得
    private func colorForSubject(_ subject: String?) -> Color {
        guard let subject = subject, !subject.isEmpty else { return .gray }
        
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
        
        var hash = 0
        for char in subject {
            hash = ((hash << 5) &+ hash) &+ Int(char.asciiValue ?? 0)
        }
        
        return colors[abs(hash) % colors.count]
    }
    
    // 時間帯を整形して表示
    private func formatTimeSlot(_ timeSlot: String?) -> String {
        guard let timeSlot = timeSlot else { return "未定" }
        
        let components = timeSlot.split(separator: "-")
        if components.count == 2 {
            let start = components[0].trimmingCharacters(in: .whitespaces)
            let end = components[1].trimmingCharacters(in: .whitespaces)
            return "\(start)〜\(end)"
        }
        return timeSlot
    }
    
    var body: some View {
        let backgroundColor = colorForSubject(item.subject)
        let isActive = isCurrentClass()
        
        VStack(alignment: .center, spacing: 4) {
            // 時間帯
            Text(formatTimeSlot(item.startTime))
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.9))
            
            // 時限
            Text(item.period ?? "")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
            
            // 科目名
            Text(item.subject ?? "未定")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .padding(.horizontal, 2)
            
            // 教室
            if let room = item.room, !room.isEmpty {
                Text(room)
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.9))
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 6)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(backgroundColor.opacity(0.8))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(isActive ? .white : .clear, lineWidth: 2)
        )
    }
}
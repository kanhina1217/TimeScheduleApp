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
    
    // 科目名からカラーを取得
    private func colorForSubject(_ subject: String) -> Color {
        let colors: [Color] = [
            Color.blue.opacity(0.7),
            Color.green.opacity(0.7),
            Color.orange.opacity(0.7),
            Color.pink.opacity(0.7),
            Color.purple.opacity(0.7),
            Color.teal.opacity(0.7),
            Color.yellow.opacity(0.7),
            Color.red.opacity(0.7),
            Color.indigo.opacity(0.7),
            Color.mint.opacity(0.7)
        ]
        
        // 科目名から一貫性のあるカラーを生成
        var hash = 0
        for char in subject {
            hash = ((hash << 5) &+ hash) &+ Int(char.asciiValue ?? 0)
        }
        
        return colors[abs(hash) % colors.count]
    }
    
    // 時間帯を整形して表示
    private func formatTimeSlot(_ timeSlot: String) -> String {
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
    
    var body: some View {
        let weekday = Calendar.current.component(.weekday, from: entry.date)
        let themeColor = themeColorForWeekday(weekday)
        
        ZStack {
            // 背景のデザイン
            VStack(spacing: 0) {
                // ヘッダー部分の背景
                themeColor
                    .frame(height: 44)
                
                // 本文部分の背景
                if colorScheme == .dark {
                    Color(.systemGray6)
                        .opacity(0.95)
                } else {
                    Color(.systemBackground)
                        .opacity(0.95)
                }
            }
            .ignoresSafeArea()
            
            // ウィジェットの内容
            VStack(alignment: .leading, spacing: 0) {
                // ヘッダー部分
                HStack {
                    // アイコンと日付表示を横並びに
                    HStack(spacing: 6) {
                        Image(systemName: "calendar.day.timeline.trailing")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                        
                        // 日付表示
                        let dateString = formatDate(entry.date)
                        let weekdayString = weekdayNames[weekday - 1]
                        
                        Text("\(dateString)（\(weekdayString)）")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    // アプリ名
                    Text("今日の時間割")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.white.opacity(0.3))
                        .cornerRadius(12)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(themeColor)
                
                // コンテンツが空の場合
                if entry.timetableItems.isEmpty {
                    VStack(spacing: 8) {
                        Spacer()
                        
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(.system(size: 36))
                            .foregroundColor(.secondary)
                            .padding(.bottom, 8)
                        
                        Text("本日の授業はありません")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        Text("タップして時間割を確認")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary.opacity(0.8))
                            .padding(.top, 2)
                        
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                }
                // 時間割データがある場合
                else {
                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(entry.timetableItems.sorted { 
                                ($0.startTime ?? "") < ($1.startTime ?? "") 
                            }, id: \.self) { item in
                                TimetableItemView(item: item)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                    }
                }
            }
        }
    }
}

// 時間割アイテム表示用のサブビュー
struct TimetableItemView: View {
    let item: TimeTableItem
    
    // 科目名からカラーを取得
    private func colorForSubject(_ subject: String) -> Color {
        let colors: [Color] = [
            Color.blue.opacity(0.7),
            Color.green.opacity(0.7),
            Color.orange.opacity(0.7),
            Color.pink.opacity(0.7),
            Color.purple.opacity(0.7),
            Color.teal.opacity(0.7),
            Color.yellow.opacity(0.7),
            Color.red.opacity(0.7),
            Color.indigo.opacity(0.7),
            Color.mint.opacity(0.7)
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
        guard let timeSlot = timeSlot else { return "" }
        let components = timeSlot.split(separator: "-")
        if components.count == 2 {
            return "\(components[0].trimmingCharacters(in: .whitespaces))～\(components[1].trimmingCharacters(in: .whitespaces))"
        }
        return timeSlot
    }
    
    var body: some View {
        let subjectColor = colorForSubject(item.subject ?? "")
        
        HStack(alignment: .center, spacing: 0) {
            // 左側のカラーバー
            Rectangle()
                .fill(subjectColor)
                .frame(width: 5)
            
            // 内容部分
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    // 科目名
                    Text(item.subject ?? "授業")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    HStack(spacing: 8) {
                        // 時間
                        if let startTime = item.startTime {
                            HStack(spacing: 3) {
                                Image(systemName: "clock")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                
                                Text(formatTimeSlot(startTime))
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        // 教室
                        if let location = item.location, !location.isEmpty {
                            HStack(spacing: 3) {
                                Image(systemName: "mappin")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                
                                Text(location)
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                Spacer()
                
                // 講義番号（もしあれば）
                if let period = item.period, !period.isEmpty {
                    Text(period)
                        .font(.system(size: 13, weight: .medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(subjectColor.opacity(0.3))
                        .cornerRadius(12)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
        )
    }
}

// プレビュー用のプロバイダー
struct TimetableWidgetEntryView_Previews: PreviewProvider {
    static var previews: some View {
        let entry = TimetableWidgetEntry(date: Date(), timetableItems: [
            TimeTableItem(subject: "プログラミング", startTime: "9:00-10:30", location: "A101", period: "1限"),
            TimeTableItem(subject: "データベース", startTime: "10:40-12:10", location: "B201", period: "2限"),
            TimeTableItem(subject: "ネットワーク", startTime: "13:00-14:30", location: "C301", period: "3限")
        ])
        TimetableWidgetEntryView(entry: entry)
            .previewContext(WidgetPreviewContext(family: .systemMedium))
    }
}
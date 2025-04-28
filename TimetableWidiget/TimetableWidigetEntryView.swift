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
    
    // 科目名からカラーを取得（色情報がない場合のフォールバック）
    private func colorForSubject(_ subject: String, colorHex: String? = nil) -> Color {
        // 色情報が存在する場合はそれを使用
        if let colorHex = colorHex, !colorHex.isEmpty {
            return Color(hex: colorHex) ?? .blue
        }
        
        // 色情報がない場合はデフォルトの青色を返す
        return .blue
    }
    
    // 時限を整数に変換する関数
    private func periodToInt(_ period: String?) -> Int {
        guard let periodStr = period else { return 0 }
        let digits = periodStr.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        return Int(digits) ?? 0
    }
    
    // 指定した時限の授業を取得
    private func classForPeriod(_ period: Int) -> TimeTableItem? {
        return entry.timetableItems.first { item in
            periodToInt(item.period) == period
        }
    }
    
    // 時間帯を整形して表示
    private func formatTimeSlot(_ timeSlot: String?) -> String {
        guard let timeSlot = timeSlot else { return "" }
        
        let components = timeSlot.split(separator: "-")
        if components.count == 2 {
            let start = components[0].trimmingCharacters(in: .whitespaces)
            return start
        }
        return timeSlot
    }
    
    var body: some View {
        // 今日の曜日を取得
        let weekday = getWeekday(Date())
        
        ZStack {
            // 背景
            Color(UIColor.systemBackground)
                .edgesIgnoringSafeArea(.all)
            
            VStack(alignment: .center, spacing: 4) {
                // ヘッダー
                HStack {
                    Text("\(weekdayNames[weekday - 1])曜日")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.top, 6)
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
                    // 表形式で表示
                    VStack(spacing: 2) {
                        // 1行目：時限と時程
                        HStack(spacing: 0) {
                            ForEach(1...5, id: \.self) { period in
                                let item = classForPeriod(period)
                                VStack(spacing: 0) {
                                    Text("\(period)")
                                        .font(.system(size: family == .systemSmall ? 10 : 12, weight: .bold))
                                        .foregroundColor(.primary)
                                    
                                    if let time = item?.startTime {
                                        Text(formatTimeSlot(time))
                                            .font(.system(size: family == .systemSmall ? 8 : 9))
                                            .foregroundColor(.secondary)
                                    } else {
                                        Text("-")
                                            .font(.system(size: family == .systemSmall ? 8 : 9))
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                        .padding(.horizontal, 4)
                        .padding(.bottom, 2)
                        
                        // 2行目：授業セル
                        HStack(spacing: 2) {
                            ForEach(1...5, id: \.self) { period in
                                if let item = classForPeriod(period) {
                                    // 授業があるセル
                                    let backgroundColor = colorForSubject(item.subject ?? "", colorHex: item.color)
                                    
                                    VStack(spacing: 2) {
                                        Text(item.subject ?? "")
                                            .font(.system(size: family == .systemSmall ? 8 : 10, weight: .medium))
                                            .foregroundColor(.white)
                                            .lineLimit(2)
                                            .multilineTextAlignment(.center)
                                        
                                        if let room = item.room, !room.isEmpty {
                                            Text(room)
                                                .font(.system(size: family == .systemSmall ? 7 : 8))
                                                .foregroundColor(.white.opacity(0.9))
                                                .lineLimit(1)
                                        }
                                    }
                                    .padding(.vertical, 3)
                                    .padding(.horizontal, 2)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .background(backgroundColor.opacity(0.8))
                                    .cornerRadius(6)
                                } else {
                                    // 授業がないセル
                                    VStack {
                                        Text("-")
                                            .font(.system(size: 10))
                                            .foregroundColor(.secondary)
                                    }
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(6)
                                }
                            }
                        }
                        .frame(maxHeight: .infinity)
                    }
                    .padding(4)
                }
            }
        }
    }
}

// 16進数文字列からColorを生成する拡張機能
extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else {
            return nil
        }
        
        // 6桁カラーコード (#RRGGBB)
        if hexSanitized.count == 6 {
            let red = Double((rgb & 0xFF0000) >> 16) / 255.0
            let green = Double((rgb & 0x00FF00) >> 8) / 255.0
            let blue = Double(rgb & 0x0000FF) / 255.0
            
            self.init(red: red, green: green, blue: blue)
            return
        }
        
        // 8桁カラーコード (#RRGGBBAA)
        if hexSanitized.count == 8 {
            let red = Double((rgb & 0xFF000000) >> 24) / 255.0
            let green = Double((rgb & 0x00FF0000) >> 16) / 255.0
            let blue = Double((rgb & 0x0000FF00) >> 8) / 255.0
            let alpha = Double(rgb & 0x000000FF) / 255.0
            
            self.init(red: red, green: green, blue: blue, opacity: alpha)
            return
        }
        
        return nil
    }
}

// 時間割のプレビュー
struct TimetableWidgetEntryView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleItems = [
            TimeTableItem(subject: "プログラミング", startTime: "9:00-10:30", teacher: "山田先生", room: "A101", period: "1限", color: "#FF0000"),
            TimeTableItem(subject: "データベース", startTime: "10:40-12:10", teacher: "鈴木先生", room: "B201", period: "2限", color: "#0000FF"),
            TimeTableItem(subject: "AI入門", startTime: "13:00-14:30", teacher: "佐藤先生", room: "C301", period: "3限", color: "#00FF00"),
            TimeTableItem(subject: "情報工学", startTime: "14:40-16:10", teacher: "田中先生", room: "D401", period: "4限", color: "#FF00FF"),
            TimeTableItem(subject: "プロジェクト演習", startTime: "16:20-17:50", teacher: "小林先生", room: "E501", period: "5限", color: "#FFFF00")
        ]
        
        let entry = TimetableWidgetEntry(date: Date(), timetableItems: sampleItems)
        
        TimetableWidgetEntryView(entry: entry)
            .previewContext(WidgetPreviewContext(family: .systemMedium))
            .previewDisplayName("標準サイズ")
        
        TimetableWidgetEntryView(entry: entry)
            .previewContext(WidgetPreviewContext(family: .systemSmall))
            .previewDisplayName("小サイズ")
    }
}
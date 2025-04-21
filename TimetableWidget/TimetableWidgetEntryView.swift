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
        case 1: return Color(.systemRed).opacity(0.8) // 日曜日
        case 2: return Color(.systemBlue).opacity(0.8) // 月曜日
        case 3: return Color(.systemOrange).opacity(0.8) // 火曜日
        case 4: return Color(.systemGreen).opacity(0.8) // 水曜日
        case 5: return Color(.systemYellow).opacity(0.8) // 木曜日
        case 6: return Color(.systemPink).opacity(0.8) // 金曜日
        case 7: return Color(.systemPurple).opacity(0.8) // 土曜日
        default: return Color(.systemBlue).opacity(0.8)
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
            Color.red.opacity(0.7)
        ]
        
        // 科目名から一貫性のあるカラーを生成
        var hash = 0
        for char in subject {
            hash = ((hash << 5) &+ hash) &+ Int(char.asciiValue ?? 0)
        }
        
        return colors[abs(hash) % colors.count]
    }
    
    var body: some View {
        let weekday = Calendar.current.component(.weekday, from: entry.date)
        let themeColor = themeColorForWeekday(weekday)
        
        ZStack {
            // 背景のデザイン
            VStack(spacing: 0) {
                // ヘッダー部分の背景
                themeColor
                    .frame(height: 40)
                
                // 本文部分の背景
                if colorScheme == .dark {
                    Color(.systemGray6)
                } else {
                    Color(.systemBackground)
                }
            }
            .ignoresSafeArea()
            
            // ウィジェットの内容
            VStack(alignment: .leading, spacing: 0) {
                // ヘッダー部分
                HStack {
                    // アイコン
                    Image(systemName: "calendar.day.timeline.leading")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    
                    // 日付表示
                    let dateString = formatDate(entry.date)
                    let weekdayString = weekdayNames[weekday - 1]
                    
                    Text("\(dateString)（\(weekdayString)）")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    // アプリ名
                    Text("今日の時間割")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(themeColor)
                
                // コンテンツが空の場合
                if entry.timetableItems.isEmpty {
                    VStack(spacing: 4) {
                        Spacer()
                        
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(.system(size: 30))
                            .foregroundColor(.secondary)
                            .padding(.bottom, 4)
                        
                        Text("本日の授業はありません")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical)
                } else {
                    // 時間割一覧
                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(entry.timetableItems) { item in
                                timetableItemView(item)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
        }
    }
    
    // 日付のフォーマット
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        return formatter.string(from: date)
    }
    
    // 各時間割項目の表示
    private func timetableItemView(_ item: TimetableWidgetItem) -> some View {
        let itemColor = colorForSubject(item.subjectName)
        
        return HStack(spacing: 10) {
            // 時限と時間
            VStack(spacing: 2) {
                Text(item.period)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 28, height: 28)
                    .background(itemColor)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                
                Text("\(item.startTime)")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .frame(width: 40)
            
            // 区切り線
            RoundedRectangle(cornerRadius: 1)
                .frame(width: 2)
                .foregroundColor(itemColor)
                .padding(.vertical, 2)
            
            // 科目名と教室名
            VStack(alignment: .leading, spacing: 2) {
                Text(item.subjectName)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.primary)
                
                if !item.roomName.isEmpty {
                    Text(item.roomName)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // 終了時間
            Text("\(item.endTime)まで")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .padding(.trailing, 2)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(colorScheme == .dark ? Color(.systemGray5) : Color.white)
                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
        .padding(.horizontal, 8)
        .contentShape(Rectangle())
    }
}

// プレビュー
struct TimetableWidgetEntryView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleItems = [
            TimetableWidgetItem(period: "1", subjectName: "数学", roomName: "2-3教室", startTime: "8:45", endTime: "9:35"),
            TimetableWidgetItem(period: "2", subjectName: "英語", roomName: "3-1教室", startTime: "9:45", endTime: "10:35"),
            TimetableWidgetItem(period: "3", subjectName: "物理", roomName: "理科室", startTime: "10:45", endTime: "11:35"),
            TimetableWidgetItem(period: "4", subjectName: "国語", roomName: "2-3教室", startTime: "11:45", endTime: "12:35")
        ]
        
        Group {
            // ライトモード
            TimetableWidgetEntryView(entry: TimetableWidgetEntry(date: Date(), timetableItems: sampleItems))
                .previewContext(WidgetPreviewContext(family: .systemMedium))
            
            // ダークモード
            TimetableWidgetEntryView(entry: TimetableWidgetEntry(date: Date(), timetableItems: sampleItems))
                .previewContext(WidgetPreviewContext(family: .systemMedium))
                .environment(\.colorScheme, .dark)
            
            // 授業なしのケース
            TimetableWidgetEntryView(entry: TimetableWidgetEntry(date: Date(), timetableItems: []))
                .previewContext(WidgetPreviewContext(family: .systemMedium))
        }
    }
}
import WidgetKit
import SwiftUI

struct TimetableWidgetEntryView: View {
    var entry: TimetableWidgetProvider.Entry
    @Environment(\.widgetFamily) var family
    
    // 曜日表示のための配列
    private let weekdayNames = ["日", "月", "火", "水", "木", "金", "土"]
    
    var body: some View {
        ZStack {
            // 背景
            Color(UIColor.systemBackground)
                .ignoresSafeArea()
            
            // ウィジェットの内容
            VStack(alignment: .leading, spacing: 8) {
                // ヘッダー部分
                HStack {
                    // アプリアイコンまたはカスタムアイコン
                    Image(systemName: "calendar.day.timeline.left")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.blue)
                    
                    // 日付表示
                    let dateString = formatDate(entry.date)
                    let weekday = Calendar.current.component(.weekday, from: entry.date) - 1
                    let weekdayString = weekdayNames[weekday]
                    
                    Text("\(dateString)（\(weekdayString)）")
                        .font(.system(size: 14, weight: .bold))
                    
                    Spacer()
                    
                    // アプリ名
                    Text("時間割")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
                
                // コンテンツが空の場合
                if entry.timetableItems.isEmpty {
                    VStack(spacing: 4) {
                        Spacer()
                        Text("今日の時間割はありません")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    // 時間割一覧
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(entry.timetableItems) { item in
                                timetableItemView(item)
                                
                                // 区切り線（最後のアイテム以外）
                                if item.id != entry.timetableItems.last?.id {
                                    Divider()
                                        .padding(.horizontal, 12)
                                }
                            }
                        }
                        .padding(.bottom, 8)
                    }
                }
            }
        }
    }
    
    // 日付のフォーマット
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"
        return formatter.string(from: date)
    }
    
    // 各時間割項目の表示
    private func timetableItemView(_ item: TimetableWidgetItem) -> some View {
        HStack(spacing: 8) {
            // 時限
            Text(item.period)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Color.blue)
                .clipShape(Circle())
            
            // 科目名と教室名
            VStack(alignment: .leading, spacing: 2) {
                Text(item.subjectName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                
                Text(item.roomName)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // 時間
            Text("\(item.startTime)-\(item.endTime)")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
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
        
        TimetableWidgetEntryView(entry: TimetableWidgetEntry(date: Date(), timetableItems: sampleItems))
            .previewContext(WidgetPreviewContext(family: .systemMedium))
    }
}
import WidgetKit
import SwiftUI

struct TimetableWidgetEntryView : View {
    var entry: TimetableWidgetProvider.Entry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        ZStack {
            Color(UIColor.systemBackground)
                .edgesIgnoringSafeArea(.all)
            
            VStack(alignment: .leading, spacing: 0) {
                // タイトル部分
                HStack {
                    Image(systemName: "calendar")
                        .font(.system(size: 14, weight: .semibold))
                    Text("今日の予定")
                        .font(.system(size: 14, weight: .semibold))
                    Spacer()
                    Text(entry.patternName)
                        .font(.system(size: 11))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(4)
                }
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .padding(.bottom, 6)
                
                // 時間割リスト
                VStack(spacing: family == .systemSmall ? 2 : 4) {
                    ForEach(entry.timetableItems.prefix(family == .systemSmall ? 3 : 5), id: \.period) { item in
                        timetableRow(for: item)
                    }
                    
                    if entry.timetableItems.isEmpty {
                        emptyTimetableRow()
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
                
                Spacer(minLength: 0)
                
                // 反復処理確認エリアを追加
                HStack {
                    Spacer()
                    Text("反復処理を続行")
                        .font(.system(size: 11))
                        .foregroundColor(.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(4)
                    Spacer()
                }
                .padding(.bottom, 6)
                .widgetURL(URL(string: "timeschedule://continue-iteration"))
            }
        }
    }
    
    // 通常時間割行のビュー
    private func timetableRow(for item: TimeTableItem) -> some View {
        HStack(spacing: 6) {
            // 科目カラー表示
            colorTag(for: item.color ?? "0")
            
            // 時限と時間
            VStack(alignment: .leading, spacing: 0) {
                Text(item.period ?? "")
                    .font(.system(size: family == .systemSmall ? 10 : 11, weight: .medium))
                if let startTime = item.startTime {
                    Text(startTime)
                        .font(.system(size: family == .systemSmall ? 9 : 10))
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 40, alignment: .leading)
            
            // 科目名
            VStack(alignment: .leading, spacing: 0) {
                if let subject = item.subject {
                    Text(subject)
                        .font(.system(size: family == .systemSmall ? 12 : 13, weight: .medium))
                        .lineLimit(1)
                } else {
                    Text("授業なし")
                        .font(.system(size: family == .systemSmall ? 12 : 13))
                        .foregroundColor(.secondary)
                }
                
                // 教室情報
                HStack(spacing: 4) {
                    if let room = item.room, !room.isEmpty {
                        Text(room)
                            .font(.system(size: family == .systemSmall ? 9 : 10))
                            .foregroundColor(.secondary)
                    }
                    
                    // 特殊時程の場合に元情報を表示
                    if item.isSpecial, let originalInfo = item.originalInfo {
                        Text("元：\(originalInfo)")
                            .font(.system(size: family == .systemSmall ? 9 : 10))
                            .foregroundColor(.blue)
                    }
                }
            }
            
            Spacer()
        }
        .padding(.vertical, family == .systemSmall ? 4 : 6)
        .padding(.horizontal, family == .systemSmall ? 6 : 8)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(6)
    }
    
    // 空の時間割行ビュー
    private func emptyTimetableRow() -> some View {
        HStack {
            Spacer()
            Text("本日の予定はありません")
                .font(.system(size: family == .systemSmall ? 11 : 12))
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.vertical, family == .systemSmall ? 10 : 12)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(6)
    }
    
    // 科目カラータグ表示
    private func colorTag(for colorString: String) -> some View {
        // 色コード文字列から色を取得
        let color = getSubjectColor(from: colorString)
        
        return Rectangle()
            .fill(color)
            .frame(width: 4, height: family == .systemSmall ? 20 : 24)
            .cornerRadius(2)
    }
    
    // 科目カラー変換
    private func getSubjectColor(from colorString: String) -> Color {
        // 色番号に基づいて色を返す
        // 色番号は0から始まる整数を想定
        guard let colorIndex = Int(colorString), colorIndex >= 0 else {
            return Color.gray // デフォルト色
        }
        
        // 事前定義された色のリスト
        let colors: [Color] = [
            .gray,         // 0: デフォルト
            .blue,         // 1: 青
            .red,          // 2: 赤
            .green,        // 3: 緑
            .orange,       // 4: オレンジ
            .purple,       // 5: 紫
            .pink,         // 6: ピンク
            .yellow,       // 7: 黄色
            .teal,         // 8: ティール
            .indigo        // 9: インディゴ
        ]
        
        // 範囲内の色を返す
        let index = min(colorIndex, colors.count - 1)
        return colors[index]
    }
}
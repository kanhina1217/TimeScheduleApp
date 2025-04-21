import WidgetKit
import SwiftUI
import CoreData

struct TimetableWidgetProvider: TimelineProvider {
    // プレースホルダーエントリー（ウィジェットがロードされる前に表示される）
    func placeholder(in context: Context) -> TimetableWidgetEntry {
        return TimetableWidgetEntry(date: Date(), timetableItems: [])
    }

    // スナップショットエントリー（ウィジェットギャラリーで表示される）
    func getSnapshot(in context: Context, completion: @escaping (TimetableWidgetEntry) -> Void) {
        let entry = TimetableWidgetEntry(date: Date(), timetableItems: sampleTimetableItems())
        completion(entry)
    }

    // タイムラインエントリー（実際のウィジェット表示に使用される）
    func getTimeline(in context: Context, completion: @escaping (Timeline<TimetableWidgetEntry>) -> Void) {
        // コアデータからデータを取得
        let entries = getEntries()
        
        // 更新ポリシー: 次の日の午前0時に更新
        let calendar = Calendar.current
        let midnight = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: Date())!)
        let refreshDate = calendar.date(byAdding: .second, value: 1, to: midnight)!
        
        // タイムラインを作成
        let timeline = Timeline(entries: [entries], policy: .after(refreshDate))
        completion(timeline)
    }
    
    // サンプルデータ（プレビュー用）
    private func sampleTimetableItems() -> [TimetableWidgetItem] {
        return [
            TimetableWidgetItem(period: "1", subjectName: "数学", roomName: "2-3教室", startTime: "8:45", endTime: "9:35"),
            TimetableWidgetItem(period: "2", subjectName: "英語", roomName: "3-1教室", startTime: "9:45", endTime: "10:35"),
            TimetableWidgetItem(period: "3", subjectName: "物理", roomName: "理科室", startTime: "10:45", endTime: "11:35"),
            TimetableWidgetItem(period: "4", subjectName: "国語", roomName: "2-3教室", startTime: "11:45", endTime: "12:35"),
            TimetableWidgetItem(period: "5", subjectName: "音楽", roomName: "音楽室", startTime: "13:25", endTime: "14:15"),
            TimetableWidgetItem(period: "6", subjectName: "保健体育", roomName: "体育館", startTime: "14:25", endTime: "15:15")
        ]
    }
    
    // 実際のデータを取得する関数
    private func getEntries() -> TimetableWidgetEntry {
        // 今日の曜日を取得
        let calendar = Calendar.current
        let today = Date()
        let weekday = calendar.component(.weekday, from: today) - 1 // 0が日曜日、1が月曜日...
        
        // CoreDataから該当曜日の時間割を取得
        let timetableItems = fetchTodayTimetable(weekday: weekday)
        
        return TimetableWidgetEntry(date: today, timetableItems: timetableItems)
    }
    
    // CoreDataから時間割データを取得
    private func fetchTodayTimetable(weekday: Int) -> [TimetableWidgetItem] {
        // 共有コンテナから永続コンテキストを取得
        guard let sharedDefaults = UserDefaults(suiteName: "group.com.yourapp.timetable"),
              let currentPatternID = sharedDefaults.string(forKey: "currentPattern") else {
            return []
        }
        
        // 土日判定（設定によって表示を切り替える）
        if weekday == 0 || weekday == 6 {
            // 土日の設定が無効ならサンプルを返す
            return []
        }
        
        // アプリからエクスポートされたデータを使用
        guard let widgetData = sharedDefaults.array(forKey: "widgetTimetableData") as? [[String: Any]] else {
            return []
        }
        
        // 今日の曜日と一致するデータをフィルタリング
        let todayItems = widgetData.filter { item in
            guard let itemWeekday = item["weekday"] as? Int,
                  let itemPattern = item["patternID"] as? String else {
                return false
            }
            return itemWeekday == weekday && itemPattern == currentPatternID
        }
        
        // ウィジェット表示用アイテムに変換
        return todayItems.compactMap { item -> TimetableWidgetItem? in
            guard let period = item["period"] as? String,
                  let subject = item["subjectName"] as? String,
                  let room = item["roomName"] as? String,
                  let startTime = item["startTime"] as? String,
                  let endTime = item["endTime"] as? String else {
                return nil
            }
            
            return TimetableWidgetItem(
                period: period,
                subjectName: subject,
                roomName: room,
                startTime: startTime,
                endTime: endTime
            )
        }.sorted { Int($0.period) ?? 0 < Int($1.period) ?? 0 } // 時限順で並べ替え
    }
}

// ウィジェットエントリーの構造体
struct TimetableWidgetEntry: TimelineEntry {
    let date: Date
    let timetableItems: [TimetableWidgetItem]
}

// ウィジェット表示用の時間割アイテム
struct TimetableWidgetItem: Identifiable {
    let id = UUID()
    let period: String
    let subjectName: String
    let roomName: String
    let startTime: String
    let endTime: String
}

// ウィジェットのエントリーポイント
@main
struct TimetableWidget: Widget {
    private let kind = "TimetableWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TimetableWidgetProvider()) { entry in
            TimetableWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("今日の時間割")
        .description("今日の時間割と教室を表示します")
        .supportedFamilies([.systemMedium]) // 中サイズのウィジェットをサポート
    }
}
import SwiftUI
import CoreData
import WidgetKit

/// ウィジェットとアプリ間のデータ共有を管理するクラス
class WidgetDataManager {
    static let shared = WidgetDataManager()
    
    // アプリグループ識別子
    private let appGroupIdentifier = "group.com.kanhina.timetable"
    
    private init() {}
    
    // 共有UserDefaultsへのアクセスを強化
    private func getSharedUserDefaults() -> UserDefaults? {
        // 明示的にアプリグループIDを指定してUserDefaultsを取得
        let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier)
        
        if sharedDefaults == nil {
            print("警告: 共有UserDefaultsの取得に失敗しました。アプリグループIDの設定を確認してください。")
            print("アプリグループID: \(appGroupIdentifier)")
        }
        
        return sharedDefaults
    }
    
    /// ウィジェット用にデータをエクスポートする
    func exportDataForWidget(context: NSManagedObjectContext) {
        // UserDefaultsの共有インスタンスを取得
        guard let sharedDefaults = getSharedUserDefaults() else {
            print("共有UserDefaultsにアクセスできません")
            return
        }
        
        // 現在使用中のパターンIDを保存
        if let currentPattern = getCurrentPatternID(context: context) {
            sharedDefaults.set(currentPattern, forKey: "currentPattern")
        }
        
        // 時間割データをエクスポート
        let timetableData = fetchTimetableData(context: context)
        sharedDefaults.set(timetableData, forKey: "widgetTimetableData")
        
        // 保存を確実に行う
        if #available(iOS 13.0, *) {
            // iOS 13以降ではsynchronizeは非推奨ですが、この場合は使用します
            sharedDefaults.synchronize()
        } else {
            sharedDefaults.synchronize()
        }
        
        // ウィジェットの更新を通知
        WidgetCenter.shared.reloadAllTimelines()
        
        print("ウィジェットデータをエクスポートしました: \(timetableData.count)件")
        
        // デバッグ情報の表示
        print("アプリグループID: \(appGroupIdentifier)")
        print("データ保存状態: \(sharedDefaults.array(forKey: "widgetTimetableData") != nil ? "成功" : "失敗")")
    }
    
    /// 現在のパターンIDを取得
    private func getCurrentPatternID(context: NSManagedObjectContext) -> String? {
        // 設定から現在のパターンIDを取得する処理
        // この部分はアプリの設定管理方法によって実装を変更してください
        
        // 例：UserDefaultsから取得する場合
        return UserDefaults.standard.string(forKey: "currentPatternID") ?? "default"
    }
    
    /// 時間割データを取得してエクスポート用に変換
    private func fetchTimetableData(context: NSManagedObjectContext) -> [[String: Any]] {
        var result: [[String: Any]] = []
        
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Timetable")
        
        do {
            if let timetables = try context.fetch(fetchRequest) as? [NSManagedObject] {
                for timetable in timetables {
                    // 必要なデータを抽出
                    if let dayOfWeek = timetable.value(forKey: "dayOfWeek") as? Int16,
                       let period = timetable.value(forKey: "period") as? Int16,
                       let subjectName = timetable.value(forKey: "subjectName") as? String {
                        
                        // 各項目を辞書に格納
                        var itemDict: [String: Any] = [
                            "dayOfWeek": Int(dayOfWeek),  // 0=日曜, 1=月曜, ...として保存
                            "period": String(period),  // 文字列として保存
                            "subjectName": subjectName,
                        ]
                        
                        // パターンIDを取得（リレーションシップから）
                        if let patternRelation = timetable.value(forKey: "pattern") as? NSManagedObject,
                           let patternID = patternRelation.value(forKey: "id") as? UUID {
                            itemDict["patternID"] = patternID.uuidString
                        } else {
                            itemDict["patternID"] = "default"
                        }
                        
                        // 任意の項目は存在する場合のみ追加
                        if let classroom = timetable.value(forKey: "classroom") as? String {
                            itemDict["roomName"] = classroom
                        } else {
                            itemDict["roomName"] = ""
                        }
                        
                        // 教員情報 - CoreDataモデルには存在しないため直接アクセスしない
                        // 代わりに空文字列を設定
                        itemDict["teacher"] = ""
                        
                        // 時間情報を追加
                        let startTime = getStartTimeForPeriod(String(period))
                        let endTime = getEndTimeForPeriod(String(period))
                        itemDict["startTime"] = startTime
                        itemDict["endTime"] = endTime
                        
                        // ウィジェット表示用に一貫した時間形式も追加
                        itemDict["timeSlot"] = "\(startTime)-\(endTime)"
                        
                        result.append(itemDict)
                    }
                }
            }
        } catch {
            print("時間割データの取得に失敗: \(error)")
        }
        
        return result
    }
    
    /// 時限ごとの開始時刻（ハードコードされた値）
    private func getStartTimeForPeriod(_ period: String) -> String {
        switch period {
        case "1": return "8:45"
        case "2": return "9:45"
        case "3": return "10:45"
        case "4": return "11:45"
        case "5": return "13:25"
        case "6": return "14:25"
        case "7": return "15:25"
        default: return ""
        }
    }
    
    /// 時限ごとの終了時刻（ハードコードされた値）
    private func getEndTimeForPeriod(_ period: String) -> String {
        switch period {
        case "1": return "9:35"
        case "2": return "10:35"
        case "3": return "11:35"
        case "4": return "12:35"
        case "5": return "14:15"
        case "6": return "15:15"
        case "7": return "16:15"
        default: return ""
        }
    }
    
    /// 手動でウィジェットを更新する（アプリ内から呼び出し可能）
    func refreshWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    /// デバッグ用：現在のエクスポートされたデータを確認
    func printCurrentWidgetData() {
        guard let sharedDefaults = getSharedUserDefaults(),
              let savedData = sharedDefaults.array(forKey: "widgetTimetableData") as? [[String: Any]] else {
            print("ウィジェットデータがありません")
            return
        }
        
        print("===== ウィジェットデータの内容 =====")
        print("データ件数: \(savedData.count)")
        
        // 曜日ごとのデータカウント
        var dayCounts = [Int: Int]()
        
        for (index, item) in savedData.enumerated() {
            print("項目 #\(index):")
            if let dayOfWeek = item["dayOfWeek"] as? Int {
                let dayNames = ["日", "月", "火", "水", "木", "金", "土"]
                let dayName = dayOfWeek >= 0 && dayOfWeek < dayNames.count ? dayNames[dayOfWeek] : "不明"
                print("  曜日: \(dayName)曜日 (インデックス: \(dayOfWeek))")
                
                // 曜日ごとのカウントを更新
                dayCounts[dayOfWeek] = (dayCounts[dayOfWeek] ?? 0) + 1
            } else {
                print("  曜日: 未設定")
            }
            
            if let period = item["period"] as? String {
                print("  時限: \(period)限目")
            }
            
            if let subject = item["subjectName"] as? String {
                print("  科目: \(subject)")
            }
            
            if let room = item["roomName"] as? String, !room.isEmpty {
                print("  教室: \(room)")
            }
            
            if let timeSlot = item["timeSlot"] as? String {
                print("  時間: \(timeSlot)")
            } else if let startTime = item["startTime"] as? String, let endTime = item["endTime"] as? String {
                print("  時間: \(startTime)-\(endTime)")
            }
            
            print("---")
        }
        
        // 曜日ごとの統計情報
        print("\n===== 曜日別データ件数 =====")
        let dayNames = ["日", "月", "火", "水", "木", "金", "土"]
        for day in 0..<7 {
            let count = dayCounts[day] ?? 0
            print("\(dayNames[day])曜日: \(count)件")
        }
        
        // 現在の曜日情報
        let calendar = Calendar.current
        let today = calendar.component(.weekday, from: Date())
        let japaneseWeekday = today - 1 // 0=日曜日、1=月曜日...
        print("\n現在の曜日: \(dayNames[japaneseWeekday])曜日 (インデックス: \(japaneseWeekday))")
        print("今日の時間割データ: \(dayCounts[japaneseWeekday] ?? 0)件")
    }
    
    /// デバッグ用：曜日の変換テスト
    func testWeekdayConversion() {
        print("\n===== 曜日変換テスト =====")
        let dayNames = ["日", "月", "火", "水", "木", "金", "土"]
        
        // Calendarコンポーネントの曜日とインデックスの対応を確認
        print("Calendar.current.weekday の対応:")
        for i in 1...7 {
            print("Calendar weekday \(i) → インデックス \(i-1) → \(dayNames[i-1])曜日")
        }
        
        // 現在の曜日
        let calendar = Calendar.current
        let now = Date()
        let currentWeekday = calendar.component(.weekday, from: now)
        let japaneseWeekday = currentWeekday - 1
        
        print("\n現在時刻: \(now)")
        print("Calendar.weekday: \(currentWeekday)")
        print("日本式インデックス: \(japaneseWeekday)")
        print("曜日名: \(dayNames[japaneseWeekday])曜日")
    }
}
import SwiftUI
import CoreData
import WidgetKit

/// ウィジェットとアプリ間のデータ共有を管理するクラス
class WidgetDataManager {
    static let shared = WidgetDataManager()
    
    // アプリグループ識別子（本番環境では適切なものに変更してください）
    private let appGroupIdentifier = "group.com.yourapp.timetable"
    
    private init() {}
    
    /// ウィジェット用にデータをエクスポートする
    func exportDataForWidget(context: NSManagedObjectContext) {
        // UserDefaultsの共有インスタンスを取得
        guard let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier) else {
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
        
        // ウィジェットの更新を通知
        WidgetCenter.shared.reloadAllTimelines()
        
        print("ウィジェットデータをエクスポートしました: \(timetableData.count)件")
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
                        
                        // 教員情報があれば追加
                        if let teacher = timetable.value(forKey: "teacher") as? String {
                            itemDict["teacher"] = teacher
                        }
                        
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
        guard let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier),
              let savedData = sharedDefaults.array(forKey: "widgetTimetableData") as? [[String: Any]] else {
            print("ウィジェットデータがありません")
            return
        }
        
        print("===== ウィジェットデータの内容 =====")
        print("データ件数: \(savedData.count)")
        
        for (index, item) in savedData.enumerated() {
            print("項目 #\(index):")
            if let dayOfWeek = item["dayOfWeek"] as? Int {
                let dayName = ["日", "月", "火", "水", "木", "金", "土"][dayOfWeek]
                print("  曜日: \(dayName)(\(dayOfWeek))")
            }
            if let period = item["period"] as? String {
                print("  時限: \(period)限目")
            }
            if let subject = item["subjectName"] as? String {
                print("  科目: \(subject)")
            }
            if let timeSlot = item["timeSlot"] as? String {
                print("  時間: \(timeSlot)")
            }
            print("---")
        }
    }
}
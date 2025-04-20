import Foundation
import CoreData

// モジュール問題を解決するためのダミータイプエイリアス
// 型の曖昧さを解消します
// Pattern と Timetable の型を削除（エラーの原因となるため）
typealias TaskEntity = Task

// エンティティ名のための定数
enum CoreDataEntityName {
    static let pattern = "Pattern"
    static let timetable = "Timetable"
    static let task = "Task"
}

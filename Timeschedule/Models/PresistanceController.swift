import CoreData
import Foundation

// 安全なArray用トランスフォーマー
// NSSecureUnarchiveFromDataTransformerを継承して独自のトランスフォーマーを定義
class ArrayTransformer: NSSecureUnarchiveFromDataTransformer {
    
    // トランスフォーマーの名前
    static let name = NSValueTransformerName(rawValue: "ArrayTransformer")
    
    // NSArrayのサブクラスを変換可能にする
    override static var allowedTopLevelClasses: [AnyClass] {
        return [NSArray.self, NSString.self, NSNumber.self, NSDate.self, NSDictionary.self]
    }
    
    // トランスフォーマーを登録するスタティックメソッド
    public static func register() {
        let transformer = ArrayTransformer()
        ValueTransformer.setValueTransformer(transformer, forName: name)
    }
}

struct PersistenceController {
    // シングルトンインスタンス
    static let shared = PersistenceController()
    
    // CoreDataの永続コンテナ
    let container: NSPersistentContainer
    
    // 初期化処理
    init(inMemory: Bool = false) {
        // カスタムトランスフォーマーの登録
        ArrayTransformer.register()
        
        container = NSPersistentContainer(name: "TimeScheduleData")
        
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // CoreDataの読み込みに失敗した場合の致命的エラー
                fatalError("CoreDataストアの読み込みに失敗: \(error), \(error.userInfo)")
            }
        })
        
        // 自動マージポリシーの設定
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
    
    // プレビュー用のサンプルデータを含むコントローラ
    static var preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        
        // サンプルデータの作成
        createSampleData(in: viewContext)
        
        return result
    }()
    
    // サンプルデータの作成
    private static func createSampleData(in context: NSManagedObjectContext) {
        // 時程パターンのサンプル
        let normalPattern = Pattern(context: context)
        normalPattern.id = UUID()
        normalPattern.name = "通常"
        normalPattern.isDefault = true
        
        // periodTimesにArray型のデータを設定する例
        let periodTimesData: [[String: String]] = [
            ["period": "1", "startTime": "8:30", "endTime": "9:20"],
            ["period": "2", "startTime": "9:30", "endTime": "10:20"],
            ["period": "3", "startTime": "10:40", "endTime": "11:30"],
            ["period": "4", "startTime": "11:40", "endTime": "12:30"],
            ["period": "5", "startTime": "13:20", "endTime": "14:10"],
            ["period": "6", "startTime": "14:20", "endTime": "15:10"]
        ]
        normalPattern.periodTimes = periodTimesData as NSObject
        
        let shortAPattern = Pattern(context: context)
        shortAPattern.id = UUID()
        shortAPattern.name = "短縮A"
        shortAPattern.isDefault = false
        
        // 短縮パターンのperiodTimes
        let shortPeriodTimesData: [[String: String]] = [
            ["period": "1", "startTime": "8:30", "endTime": "9:10"],
            ["period": "2", "startTime": "9:20", "endTime": "10:00"],
            ["period": "3", "startTime": "10:10", "endTime": "10:50"],
            ["period": "4", "startTime": "11:00", "endTime": "11:40"],
            ["period": "5", "startTime": "12:20", "endTime": "13:00"],
            ["period": "6", "startTime": "13:10", "endTime": "13:50"]
        ]
        shortAPattern.periodTimes = shortPeriodTimesData as NSObject
        
        // 教科のサンプル
        let mathSubject = Subject(context: context)
        mathSubject.id = UUID()
        mathSubject.name = "数学"
        mathSubject.color = "blue"
        mathSubject.textbook = "数学I"
        
        let engSubject = Subject(context: context)
        engSubject.id = UUID()
        engSubject.name = "英語"
        engSubject.color = "red"
        engSubject.textbook = "コミュニケーション英語I"
        
        // 時間割のサンプル（月曜日）
        let mondayPeriod1 = Timetable(context: context)
        mondayPeriod1.id = UUID()
        mondayPeriod1.dayOfWeek = 0 // 月曜日
        mondayPeriod1.period = 1
        mondayPeriod1.subjectName = "数学"
        mondayPeriod1.classroom = "3A教室"
        mondayPeriod1.color = "blue"
        mondayPeriod1.relationship = normalPattern
        
        let mondayPeriod2 = Timetable(context: context)
        mondayPeriod2.id = UUID()
        mondayPeriod2.dayOfWeek = 0 // 月曜日
        mondayPeriod2.period = 2
        mondayPeriod2.subjectName = "英語"
        mondayPeriod2.classroom = "LL教室"
        mondayPeriod2.color = "red"
        mondayPeriod2.relationship = normalPattern
        
        // 出席サンプル
        let attendance = Attendance(context: context)
        attendance.id = UUID()
        attendance.date = Date()
        attendance.isPresent = true
        
        do {
            try context.save()
        } catch {
            let nsError = error as NSError
            fatalError("サンプルデータの保存エラー: \(nsError), \(nsError.userInfo)")
        }
    }
}
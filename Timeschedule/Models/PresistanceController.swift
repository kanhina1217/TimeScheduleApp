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

// アプリケーション起動時にArrayTransformerを登録するための初期化コード
extension NSValueTransformerName {
    static let arrayTransformerName = NSValueTransformerName(rawValue: "ArrayTransformer")
}

struct PersistenceController {
    // シングルトンインスタンス
    static let shared = PersistenceController()
    
    // CoreDataの永続コンテナ
    let container: NSPersistentContainer
    
    // 初期化処理
    init(inMemory: Bool = false) {
        // まずcontainerプロパティを初期化
        container = NSPersistentContainer(name: "TimeScheduleData")
        
        // その後で他のメソッドを呼び出し
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        
        // カスタムトランスフォーマーを確実に登録（selfが参照可能になった後に呼び出し）
        registerValueTransformers()
        
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // CoreDataの読み込みに失敗した場合の致命的エラー
                fatalError("CoreDataストアの読み込みに失敗: \(error), \(error.userInfo)")
            }
        })
        
        // 自動マージポリシーの設定
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        // リレーションシップのエラーを修正するためのカスタムコード
        setupRelationships()
    }
    
    // カスタムトランスフォーマーを登録
    private func registerValueTransformers() {
        // 既存のトランスフォーマーを確認し、なければ登録
        if ValueTransformer(forName: .arrayTransformerName) == nil {
            ArrayTransformer.register()
        }
    }
    
    // リレーションシップのエラーを修正するための処理
    private func setupRelationships() {
        // ここに必要な場合、リレーションシップを修正するコードを追加
    }
    
    // プレビュー用のサンプルデータを含むコントローラ
    static var preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        
        // サンプルデータの作成
        SampleDataCreator.createSampleData(in: viewContext)
        
        return result
    }()
}

struct SampleDataCreator {
    // サンプルデータの作成
    static func createSampleData(in context: NSManagedObjectContext) {
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
        
        // NSArrayとしてCoreDataに保存
        normalPattern.periodTimes = periodTimesData as NSArray
        
        // 科目のサンプル
        let math = Subject(context: context)
        math.id = UUID()
        math.name = "数学"
        math.color = "blue"
        math.textbook = "数学I・A"
        
        let english = Subject(context: context)
        english.id = UUID()
        english.name = "英語"
        english.color = "red"
        english.textbook = "CROWN English Communication I"
        
        // 時間割のサンプル
        // 月曜日
        let mondayPeriod1 = Timetable(context: context)
        mondayPeriod1.id = UUID()
        mondayPeriod1.dayOfWeek = 0
        mondayPeriod1.period = 1
        mondayPeriod1.subjectName = math.name
        mondayPeriod1.classroom = "3-1"
        mondayPeriod1.color = math.color
        mondayPeriod1.textbook = math.textbook
        mondayPeriod1.pattern = normalPattern
        
        let mondayPeriod2 = Timetable(context: context)
        mondayPeriod2.id = UUID()
        mondayPeriod2.dayOfWeek = 0
        mondayPeriod2.period = 2
        mondayPeriod2.subjectName = english.name
        mondayPeriod2.classroom = "3-1"
        mondayPeriod2.color = english.color
        mondayPeriod2.textbook = english.textbook
        mondayPeriod2.pattern = normalPattern
        
        // タスクのサンプル
        let mathHomework = Task(context: context)
        mathHomework.id = UUID()
        mathHomework.title = "数学の宿題"
        mathHomework.subjectName = math.name
        mathHomework.color = math.color
        mathHomework.dueDate = Date().addingTimeInterval(86400) // 1日後
        mathHomework.priority = 2
        mathHomework.note = "教科書p.25-30の問題を解く"
        mathHomework.isCompleted = false
        mathHomework.timetable = mondayPeriod1
        
        // 出席のサンプル
        let attendance = Attendance(context: context)
        attendance.id = UUID()
        attendance.date = Date()
        attendance.isPresent = true
        attendance.note = "体調良好"
        
        do {
            try context.save()
        } catch {
            let nsError = error as NSError
            fatalError("サンプルデータの保存に失敗: \(nsError), \(nsError.userInfo)")
        }
    }
}
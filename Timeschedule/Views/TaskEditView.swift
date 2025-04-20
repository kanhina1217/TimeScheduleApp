import SwiftUI
import CoreData

struct TaskEditView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) private var presentationMode
    
    // 編集対象のタスク（nilの場合は新規作成）
    var task: Task?
    
    // フォーム入力用の状態変数
    @State private var title = ""
    @State private var subjectName = ""
    @State private var color = "blue"
    @State private var dueDate = Date()
    @State private var hasDueDate = false
    @State private var priority: TaskEnums.Priority = .normal
    @State private var note = ""
    @State private var taskType: TaskEnums.TaskType = .homework // TaskEnums名前空間を使用
    
    // 科目選択用の状態変数
    @State private var isSelectingSubject = false
    @State private var showingSubjectPicker = false
    @State private var subjects: [SubjectInfo] = []
    
    // 色の選択肢
    private let colorOptions = [
        "red": "赤",
        "blue": "青",
        "green": "緑",
        "yellow": "黄",
        "purple": "紫",
        "orange": "オレンジ",
        "gray": "グレー"
    ]
    
    // 時間割から取得した科目情報を格納する構造体
    struct SubjectInfo: Identifiable, Hashable {
        let id = UUID()
        let name: String
        let color: String
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(name)
        }
        
        static func ==(lhs: SubjectInfo, rhs: SubjectInfo) -> Bool {
            return lhs.name == rhs.name
        }
    }
    
    // 標準イニシャライザ
    init(task: Task? = nil) {
        self.task = task
    }
    
    // 科目名と色を指定して初期化するイニシャライザ
    init(initialSubject: String, initialColor: String = "blue", taskType: TaskEnums.TaskType = .homework) {
        self.task = nil
        _subjectName = State(initialValue: initialSubject)
        _color = State(initialValue: initialColor)
        _taskType = State(initialValue: taskType)
    }
    
    // 科目名のみを指定して初期化するイニシャライザ
    init(initialSubjectName: String) {
        self.task = nil
        _subjectName = State(initialValue: initialSubjectName)
        _color = State(initialValue: "blue") // デフォルトの色を設定
    }
    
    // 科目情報を事前に取得する代わりに、onAppear時に処理するように修正
    private func setupInitialSubjectColor(_ subjectName: String) {
        // 時間割から科目情報を取得して色を設定する処理
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Timetable")
        fetchRequest.predicate = NSPredicate(format: "subjectName == %@", subjectName)
        fetchRequest.fetchLimit = 1
        
        do {
            if let results = try viewContext.fetch(fetchRequest) as? [NSManagedObject],
               let timetable = results.first,
               let foundColor = timetable.value(forKey: "color") as? String {
                self.color = foundColor
            }
        } catch {
            print("科目色の検索に失敗しました: \(error)")
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                // タスクタイプ選択セクション (新規追加)
                Section(header: Text("予定タイプ")) {
                    Picker("タイプ", selection: $taskType) {
                        ForEach(TaskEnums.TaskType.allCases, id: \.self) { type in
                            HStack {
                                Image(systemName: type.icon)
                                Text(type.title)
                            }.tag(type)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .onChange(of: taskType) { oldValue, newValue in
                        // タイプが変更されたら、デフォルトの色を設定
                        if color == oldValue.defaultColor {
                            color = newValue.defaultColor
                        }
                    }
                }
                
                // タスク基本情報
                Section(header: Text("基本情報")) {
                    TextField(taskType == .homework ? "課題タイトル" : "テスト内容", text: $title)
                    
                    HStack {
                        if isSelectingSubject {
                            // 既存の科目から選択
                            Picker("科目", selection: $subjectName) {
                                Text("未選択").tag("")
                                ForEach(subjects) { subject in
                                    Text(subject.name).tag(subject.name)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                            .onChange(of: subjectName) { oldValue, newValue in
                                // 科目名が変更されたら、対応する色も自動的に設定
                                if let selectedSubject = subjects.first(where: { $0.name == newValue }) {
                                    color = selectedSubject.color
                                }
                            }
                        } else {
                            // 直接入力
                            TextField("科目名", text: $subjectName)
                        }
                        
                        // 入力方法切り替えボタン
                        Button(action: {
                            if !isSelectingSubject {
                                // 科目一覧を読み込む
                                loadSubjects()
                            }
                            isSelectingSubject.toggle()
                        }) {
                            Image(systemName: isSelectingSubject ? "keyboard" : "list.bullet")
                                .foregroundColor(.blue)
                        }
                    }
                    
                    // 色選択
                    Picker("色", selection: $color) {
                        ForEach(colorOptions.sorted(by: { $0.value < $1.value }), id: \.key) { key, value in
                            HStack {
                                Circle()
                                    .fill(colorFromString(key))
                                    .frame(width: 20, height: 20)
                                Text(value)
                            }.tag(key)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                
                // 期限設定
                Section(header: Text(taskType == .homework ? "提出期限" : "テスト日時")) {
                    Toggle(taskType == .homework ? "期限を設定" : "日時を設定", isOn: $hasDueDate)
                    
                    if hasDueDate {
                        DatePicker(
                            taskType == .homework ? "期日" : "日時",
                            selection: $dueDate,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                    }
                }
                
                // 優先度設定
                Section(header: Text("優先度")) {
                    Picker("優先度", selection: $priority) {
                        ForEach(TaskEnums.Priority.allCases, id: \.self) { priority in
                            HStack {
                                Circle()
                                    .fill(priority.color)
                                    .frame(width: 10, height: 10)
                                Text(priority.title)
                            }
                            .tag(priority)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                // メモ入力
                Section(header: Text(taskType == .homework ? "メモ" : "テスト範囲・メモ")) {
                    TextEditor(text: $note)
                        .frame(height: 100)
                }
            }
            .navigationTitle(getNavigationTitle())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveTask()
                        presentationMode.wrappedValue.dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                loadTaskData()
            }
        }
    }
    
    // ナビゲーションタイトルを取得する
    private func getNavigationTitle() -> String {
        if task == nil {
            return taskType == .homework ? "新規課題" : "新規テスト"
        } else {
            return taskType == .homework ? "課題を編集" : "テストを編集"
        }
    }
    
    // 色名から色オブジェクトを取得するヘルパーメソッド
    private func colorFromString(_ colorName: String) -> Color {
        switch colorName.lowercased() {
        case "red": return .red
        case "blue": return .blue
        case "green": return .green
        case "yellow": return .yellow
        case "purple": return .purple
        case "orange": return .orange
        default: return .gray
        }
    }
    
    // タスクデータを読み込む
    private func loadTaskData() {
        if let task = task {
            title = task.title ?? ""
            subjectName = task.subjectName ?? ""
            color = task.color ?? "blue"
            
            if let date = task.dueDate {
                dueDate = date
                hasDueDate = true
            } else {
                hasDueDate = false
            }
            
            // taskTypeプロパティを安全に参照
            if let typeString = task.taskType, let type = TaskEnums.TaskType(rawValue: typeString) {
                taskType = type
            } else {
                taskType = .homework // デフォルト値
            }
            
            priority = task.priorityEnum
            note = task.note ?? ""
        }
    }
    
    // 既存の科目一覧を読み込む（時間割から）
    private func loadSubjects() {
        // 時間割から科目情報を取得する
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Timetable")
        fetchRequest.predicate = NSPredicate(format: "subjectName != nil")
        
        do {
            if let timetables = try viewContext.fetch(fetchRequest) as? [NSManagedObject] {
                var subjectDict = [String: String]() // 科目名をキー、色を値とする辞書
                
                for timetable in timetables {
                    if let subjectName = timetable.value(forKey: "subjectName") as? String,
                       !subjectName.isEmpty {
                        let color = timetable.value(forKey: "color") as? String ?? "blue"
                        subjectDict[subjectName] = color
                    }
                }
                
                // 辞書から重複のない科目情報の配列を作成
                subjects = subjectDict.map { SubjectInfo(name: $0.key, color: $0.value) }
                    .sorted { $0.name < $1.name }
            }
        } catch {
            print("科目情報の読み込みに失敗しました: \(error)")
        }
    }
    
    // タスクを保存する
    private func saveTask() {
        var taskToSave: Task
        
        if let existingTask = task {
            // 既存のタスクを更新
            taskToSave = existingTask
        } else {
            // 新規タスクを作成
            taskToSave = Task(context: viewContext)
            taskToSave.id = UUID()
            taskToSave.createdAt = Date() // もし定義されている場合
        }
        
        // タスク情報を設定
        taskToSave.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        taskToSave.subjectName = subjectName
        taskToSave.color = color
        taskToSave.dueDate = hasDueDate ? dueDate : nil
        taskToSave.priority = priority.rawValue
        taskToSave.isCompleted = false
        taskToSave.note = note
        taskToSave.taskType = taskType.rawValue // 安全に設定
        taskToSave.updatedAt = Date() // もし定義されている場合
        
        // 保存を実行
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            print("タスクの保存中にエラーが発生しました: \(nsError), \(nsError.userInfo)")
        }
    }
}

struct TaskEditView_Previews: PreviewProvider {
    static var previews: some View {
        TaskEditView(task: Task.preview)
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}

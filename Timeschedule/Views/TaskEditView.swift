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
    @State private var colorIndex = 0 // 数値インデックスに変更
    @State private var dueDate = Date()
    @State private var hasDueDate = false
    @State private var priority: Task.Priority = .normal
    @State private var note = ""
    @State private var taskType: Task.TaskType = .homework // Task名前空間を使用
    
    // 科目選択用の状態変数
    @State private var isSelectingSubject = false
    @State private var showingSubjectPicker = false
    @State private var subjects: [SubjectInfo] = []
    
    // 色のパレット - TimetableWidigetEntryViewと統一
    private let colorPalette: [Color] = [
        Color.blue,
        Color.red, 
        Color.green,
        Color.orange, 
        Color.purple, 
        Color.yellow,
        Color.pink,
        Color.gray,
        Color(red: 0.6, green: 0.4, blue: 0.2), // ブラウン
        Color(red: 0.0, green: 0.8, blue: 0.8), // ターコイズ
        Color(red: 0.0, green: 0.5, blue: 0.5)  // ティール
    ]
    
    // 色の選択肢 - インデックスと日本語名のマッピング
    private let colorOptions: [Int: String] = [
        0: "青",
        1: "赤",
        2: "緑",
        3: "オレンジ",
        4: "紫",
        5: "黄",
        6: "ピンク",
        7: "グレー",
        8: "ブラウン",
        9: "ターコイズ",
        10: "ティール"
    ]
    
    // 時間割から取得した科目情報を格納する構造体
    struct SubjectInfo: Identifiable, Hashable {
        let id = UUID()
        let name: String
        let colorIndex: Int // 数値インデックスに変更
        
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
    
    // 科目名と色インデックスを指定して初期化するイニシャライザ
    init(initialSubject: String, initialColorIndex: Int = 0, taskType: Task.TaskType = .homework) {
        self.task = nil
        _subjectName = State(initialValue: initialSubject)
        _colorIndex = State(initialValue: initialColorIndex)
        _taskType = State(initialValue: taskType)
    }
    
    // 科目名のみを指定して初期化するイニシャライザ
    init(initialSubjectName: String) {
        self.task = nil
        _subjectName = State(initialValue: initialSubjectName)
        _colorIndex = State(initialValue: 0) // デフォルトの色インデックスを設定
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
                // 文字列から数値インデックスへの変換
                self.colorIndex = colorIndexFromString(foundColor)
            }
        } catch {
            print("科目色の検索に失敗しました: \(error)")
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                // タスクタイプ選択セクション
                Section(header: Text("予定タイプ")) {
                    VStack(alignment: .leading, spacing: 4) {
                        Picker("", selection: $taskType) {
                            ForEach(Task.TaskType.allCases, id: \.self) { type in
                                Text(type.title).tag(type)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .onChange(of: taskType) { oldValue, newValue in
                            // タイプが変更されたら、デフォルトの色インデックスを設定
                            if colorIndex == taskTypeToDefaultColorIndex(oldValue) {
                                colorIndex = taskTypeToDefaultColorIndex(newValue)
                            }
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
                                    colorIndex = selectedSubject.colorIndex
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
                    Picker("色", selection: $colorIndex) {
                        ForEach(0..<colorPalette.count, id: \.self) { index in
                            HStack {
                                Circle()
                                    .fill(colorPalette[index])
                                    .frame(width: 20, height: 20)
                                Text(colorOptions[index] ?? "\(index)")
                            }.tag(index)
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
                    VStack(alignment: .leading, spacing: 4) {
                        Picker("", selection: $priority) {
                            ForEach(Task.Priority.allCases, id: \.self) { priority in
                                Text(priority.title).tag(priority)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
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
    
    // インデックスから色オブジェクトを取得するヘルパーメソッド
    private func colorFromIndex(_ index: Int) -> Color {
        if index >= 0 && index < colorPalette.count {
            return colorPalette[index]
        }
        return colorPalette[0] // デフォルトは青
    }
    
    // 文字列から色インデックスを取得するヘルパーメソッド
    private func colorIndexFromString(_ colorString: String) -> Int {
        // 数値の場合はそのままインデックスとして使用
        if let index = Int(colorString), index >= 0 && index < colorPalette.count {
            return index
        }
        
        // 従来の色名からインデックスへの変換
        switch colorString.lowercased() {
        case "red": return 1
        case "blue": return 0
        case "green": return 2
        case "orange": return 3
        case "purple": return 4
        case "yellow": return 5
        case "pink": return 6
        case "gray": return 7
        case "brown": return 8
        case "turquoise": return 9
        case "teal": return 10
        default: return 0 // デフォルトは青
        }
    }
    
    // タスクタイプからデフォルトの色インデックスに変換
    private func taskTypeToDefaultColorIndex(_ type: Task.TaskType) -> Int {
        switch type {
        case .homework: return 0 // 青
        case .exam: return 1 // 赤
        }
    }
    
    // 科目一覧を読み込む
    private func loadSubjects() {
        subjects = []
        
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Timetable")
        fetchRequest.predicate = NSPredicate(value: true)
        
        do {
            let results = try viewContext.fetch(fetchRequest)
            
            // 一意な科目名と対応する色を抽出
            var uniqueSubjects = Set<String>()
            var subjectInfos: [SubjectInfo] = []
            
            for timetable in results {
                if let name = timetable.value(forKey: "subjectName") as? String,
                   !name.isEmpty,
                   !uniqueSubjects.contains(name) {
                    uniqueSubjects.insert(name)
                    
                    // 色文字列からインデックスに変換
                    var colorIdx = 0
                    if let colorString = timetable.value(forKey: "color") as? String {
                        colorIdx = colorIndexFromString(colorString)
                    }
                    
                    subjectInfos.append(SubjectInfo(name: name, colorIndex: colorIdx))
                }
            }
            
            subjects = subjectInfos.sorted(by: { $0.name < $1.name })
        } catch {
            print("科目の読み込みに失敗しました: \(error)")
        }
    }
    
    // タスクデータの読み込み
    private func loadTaskData() {
        if let task = task {
            title = task.title ?? ""
            subjectName = task.subjectName ?? ""
            
            // 色文字列からインデックスに変換
            if let colorString = task.color {
                colorIndex = colorIndexFromString(colorString)
            }
            
            // taskTypeの読み込み
            if let typeStr = task.taskType {
                taskType = Task.TaskType(rawValue: typeStr) ?? .homework
            } else {
                taskType = .homework
            }
            
            if let taskDueDate = task.dueDate {
                dueDate = taskDueDate
                hasDueDate = true
            } else {
                hasDueDate = false
            }
            
            // priorityの読み込み
            if let priorityEnum = Task.Priority(rawValue: task.priority) {
                priority = priorityEnum
            } else {
                priority = .normal
            }
            
            note = task.note ?? ""
        } else if !subjectName.isEmpty {
            // 科目名が指定されている場合、科目に適した色を設定
            setupInitialSubjectColor(subjectName)
        }
    }
    
    // タスクの保存処理
    private func saveTask() {
        let taskToSave = task ?? Task(context: viewContext)
        
        taskToSave.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        taskToSave.subjectName = subjectName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 色インデックスを文字列として保存
        taskToSave.color = String(colorIndex)
        
        // taskTypeの保存
        taskToSave.taskType = taskType.rawValue
        
        taskToSave.dueDate = hasDueDate ? dueDate : nil
        
        // priorityの保存
        taskToSave.priority = priority.rawValue
        
        taskToSave.note = note
        
        // タイムスタンプの更新
        // timestamp -> updatedAt に変更
        if let id = taskToSave.id {
            taskToSave.updatedAt = Date()
        } else {
            taskToSave.id = UUID()
            taskToSave.createdAt = Date()
            taskToSave.updatedAt = Date()
        }
        
        // 課題情報を保存
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            print("タスク保存エラー: \(nsError), \(nsError.userInfo)")
        }
    }
}

struct TaskEditView_Previews: PreviewProvider {
    static var previews: some View {
        TaskEditView(task: Task.preview)
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}

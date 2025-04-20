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
    @State private var priority: Task.Priority = .normal
    @State private var note = ""
    
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
    init(initialSubject: String, initialColor: String = "blue") {
        self.task = nil
        _subjectName = State(initialValue: initialSubject)
        _color = State(initialValue: initialColor)
    }
    
    // 科目名のみを指定して初期化するイニシャライザ
    init(initialSubjectName: String) {
        self.task = nil
        _subjectName = State(initialValue: initialSubjectName)
        
        // 科目名に対応する色を検索するためにTaskEditViewの初期化後に実行
        DispatchQueue.main.async {
            self.loadSubjects()
            // 読み込んだ科目一覧から対応する色を検索
            if let subject = self.subjects.first(where: { $0.name == initialSubjectName }) {
                self.color = subject.color
            }
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                // タスク基本情報
                Section(header: Text("基本情報")) {
                    TextField("タイトル", text: $title)
                    
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
                            .onChange(of: subjectName) { newValue in
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
                Section(header: Text("期限")) {
                    Toggle("期限を設定", isOn: $hasDueDate)
                    
                    if hasDueDate {
                        DatePicker(
                            "期日",
                            selection: $dueDate,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                    }
                }
                
                // 優先度設定
                Section(header: Text("優先度")) {
                    Picker("優先度", selection: $priority) {
                        ForEach(Task.Priority.allCases, id: \.self) { priority in
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
                Section(header: Text("メモ")) {
                    TextEditor(text: $note)
                        .frame(height: 100)
                }
            }
            .navigationTitle(task == nil ? "新規課題" : "課題を編集")
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
        // 編集モードの場合は既存データを読み込む
        if let task = task {
            title = task.title ?? ""
            subjectName = task.subjectName ?? ""
            color = task.color ?? "blue"
            hasDueDate = task.dueDate != nil
            if let dueDate = task.dueDate {
                self.dueDate = dueDate
            }
            priority = task.priorityEnum
            note = task.note ?? ""
        }
        
        // 科目一覧を読み込む
        loadSubjects()
    }
    
    // 既存の科目一覧を読み込む（時間割から）
    private func loadSubjects() {
        // NSFetchRequestResultからTimetableへの型キャストを行う
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Timetable")
        fetchRequest.predicate = NSPredicate(format: "subjectName != nil")
        
        do {
            let timetables = try viewContext.fetch(fetchRequest) as? [Timetable]
            var subjectDict = [String: String]() // 科目名をキー、色を値とする辞書
            
            for timetable in timetables ?? [] {
                if let subjectName = timetable.subjectName, !subjectName.isEmpty {
                    subjectDict[subjectName] = timetable.color ?? "blue"
                }
            }
            
            // 辞書から重複のない科目情報の配列を作成
            subjects = subjectDict.map { SubjectInfo(name: $0.key, color: $0.value) }
                .sorted { $0.name < $1.name }
            
        } catch {
            print("科目情報の読み込みに失敗しました: \(error)")
        }
    }
    
    // タスクを保存する
    private func saveTask() {
        withAnimation {
            let taskToSave = task ?? Task(context: viewContext)
            
            // データを設定
            taskToSave.id = taskToSave.id ?? UUID()
            taskToSave.title = title
            taskToSave.subjectName = subjectName
            taskToSave.color = color
            taskToSave.dueDate = hasDueDate ? dueDate : nil
            taskToSave.isCompleted = task?.isCompleted ?? false
            taskToSave.priority = priority.rawValue
            taskToSave.note = note
            taskToSave.createdAt = taskToSave.createdAt ?? Date()
            taskToSave.updatedAt = Date()
            
            // 保存を実行
            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                print("タスクの保存中にエラーが発生しました: \(nsError), \(nsError.userInfo)")
            }
        }
    }
}

struct TaskEditView_Previews: PreviewProvider {
    static var previews: some View {
        TaskEditView(task: Task.preview)
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
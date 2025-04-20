import SwiftUI
import CoreData

struct TaskManagementView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    // タスクのFetchRequest
    @FetchRequest
    private var tasks: FetchedResults<Task>
    
    // 状態変数
    @State private var showingAddSheet = false
    @State private var showingFilterSheet = false
    @State private var selectedTask: Task?
    @State private var searchText = ""
    @State private var showTaskTypeSheet = false // タスク追加時のタイプ選択シート用
    
    // フィルタと並べ替えのオプション
    @State private var filterOption = FilterOption.all
    @State private var sortOption = SortOption.dueDate
    @State private var showCompletedTasks = true
    @State private var selectedSubject: String?
    @State private var selectedTaskType: TaskTypeFilter = .all // 追加：課題/テストフィルター
    
    // 標準イニシャライザ
    init() {
        // デフォルトのFetchRequest設定
        let request: NSFetchRequest<Task> = Task.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \Task.dueDate, ascending: true),
            NSSortDescriptor(keyPath: \Task.priority, ascending: false),
            NSSortDescriptor(keyPath: \Task.title, ascending: true)
        ]
        
        _tasks = FetchRequest(fetchRequest: request)
    }
    
    // 科目でフィルタリングするイニシャライザ
    init(filterSubject: String) {
        // 指定された科目でフィルタリングするFetchRequest設定
        let request: NSFetchRequest<Task> = Task.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \Task.dueDate, ascending: true),
            NSSortDescriptor(keyPath: \Task.priority, ascending: false),
            NSSortDescriptor(keyPath: \Task.title, ascending: true)
        ]
        
        _tasks = FetchRequest(fetchRequest: request)
        _selectedSubject = State(initialValue: filterSubject)
    }
    
    // タスクタイプフィルター
    enum TaskTypeFilter: String, CaseIterable, Identifiable {
        case all = "すべて"
        case homework = "課題"
        case exam = "テスト"
        
        var id: String { self.rawValue }
        
        var icon: String {
            switch self {
            case .all: return "doc"
            case .homework: return "doc.text"
            case .exam: return "doc.questionmark"
            }
        }
    }
    
    // フィルタオプション
    enum FilterOption: String, CaseIterable, Identifiable {
        case all = "すべて"
        case today = "今日"
        case tomorrow = "明日"
        case thisWeek = "今週"
        case overdue = "期限超過"
        case noDate = "期限なし"
        
        var id: String { self.rawValue }
    }
    
    // ソートオプション
    enum SortOption: String, CaseIterable, Identifiable {
        case dueDate = "期限"
        case priority = "優先度"
        case subject = "科目名"
        case title = "タイトル"
        
        var id: String { self.rawValue }
    }
    
    // 科目一覧
    private var subjects: [String] {
        var subjectSet = Set<String>()
        for task in tasks where task.subjectName != nil && !task.subjectName!.isEmpty {
            subjectSet.insert(task.subjectName!)
        }
        return Array(subjectSet).sorted()
    }
    
    // フィルタリング後のタスク
    private var filteredTasks: [Task] {
        tasks.filter { task in
            // 検索テキストでフィルタリング
            let matchesSearch = searchText.isEmpty || 
                (task.title?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                (task.subjectName?.localizedCaseInsensitiveContains(searchText) ?? false)
            
            // 完了状態でフィルタリング
            let matchesCompletion = showCompletedTasks || !task.isCompleted
            
            // 科目でフィルタリング
            let matchesSubject = selectedSubject == nil || task.subjectName == selectedSubject
            
            // タスクタイプでフィルタリング
            let matchesTaskType: Bool
            switch selectedTaskType {
            case .all:
                matchesTaskType = true
            case .homework:
                matchesTaskType = task.taskTypeEnum == .homework
            case .exam:
                matchesTaskType = task.taskTypeEnum == .exam
            }
            
            // 期限でフィルタリング
            var matchesFilter = true
            if filterOption != .all {
                let calendar = Calendar.current
                let now = Date()
                
                switch filterOption {
                case .today:
                    matchesFilter = task.dueDate != nil && calendar.isDateInToday(task.dueDate!)
                case .tomorrow:
                    matchesFilter = task.dueDate != nil && calendar.isDateInTomorrow(task.dueDate!)
                case .thisWeek:
                    if let dueDate = task.dueDate {
                        let endOfWeek = calendar.date(byAdding: .day, value: 7, to: now)!
                        matchesFilter = dueDate <= endOfWeek && dueDate >= now
                    } else {
                        matchesFilter = false
                    }
                case .overdue:
                    matchesFilter = task.dueDate != nil && task.dueDate! < now
                case .noDate:
                    matchesFilter = task.dueDate == nil
                default:
                    matchesFilter = true
                }
            }
            
            return matchesSearch && matchesCompletion && matchesSubject && matchesTaskType && matchesFilter
        }
        .sorted { task1, task2 in
            switch sortOption {
            case .dueDate:
                // 期限なしは最後に表示
                if task1.dueDate == nil && task2.dueDate == nil { return task1.title ?? "" < task2.title ?? "" }
                if task1.dueDate == nil { return false }
                if task2.dueDate == nil { return true }
                return task1.dueDate! < task2.dueDate!
            case .priority:
                return task1.priority > task2.priority
            case .subject:
                return (task1.subjectName ?? "") < (task2.subjectName ?? "")
            case .title:
                return (task1.title ?? "") < (task2.title ?? "")
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // 検索バー
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("検索", text: $searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal)
                
                // フィルター・並べ替え表示エリア
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        // 期限フィルター
                        Button(action: {
                            showingFilterSheet = true
                        }) {
                            HStack {
                                Image(systemName: "line.3.horizontal.decrease.circle")
                                Text(filterOption.rawValue)
                                Image(systemName: "chevron.down")
                                    .font(.caption)
                            }
                            .padding(8)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                        
                        // 課題/テストフィルター
                        Picker("タイプ", selection: $selectedTaskType) {
                            ForEach(TaskTypeFilter.allCases) { taskType in
                                HStack {
                                    Image(systemName: taskType.icon)
                                    Text(taskType.rawValue)
                                }.tag(taskType)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .frame(width: 220)
                        
                        // 科目フィルター（選択時のみ表示）
                        if let selectedSubject = selectedSubject {
                            HStack {
                                Text(selectedSubject)
                                Button(action: {
                                    self.selectedSubject = nil
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.caption)
                                }
                            }
                            .padding(8)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal)
                }
                
                // タスク一覧
                if filteredTasks.isEmpty {
                    // タスクがない場合
                    VStack(spacing: 20) {
                        Spacer()
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("タスクがありません")
                            .font(.title)
                            .foregroundColor(.gray)
                        Text("右上の+ボタンから新しいタスクを追加できます")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Spacer()
                    }
                } else {
                    // タスク一覧表示
                    List {
                        ForEach(filteredTasks) { task in
                            taskRow(for: task)
                                .swipeActions(edge: .leading) {
                                    Button {
                                        toggleTaskCompletion(task)
                                    } label: {
                                        Label(task.isCompleted ? "未完了" : "完了", 
                                              systemImage: task.isCompleted ? "arrow.uturn.backward" : "checkmark")
                                    }
                                    .tint(task.isCompleted ? .orange : .green)
                                }
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        deleteTask(task)
                                    } label: {
                                        Label("削除", systemImage: "trash")
                                    }
                                }
                        }
                    }
                }
            }
            .navigationTitle(getNavigationTitle())
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showTaskTypeSheet = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Section("表示") {
                            Toggle(isOn: $showCompletedTasks) {
                                Label("完了したタスクを表示", systemImage: "checkmark.circle")
                            }
                        }
                        
                        Section("並べ替え") {
                            Picker("並べ替え", selection: $sortOption) {
                                ForEach(SortOption.allCases) { option in
                                    Label(option.rawValue, systemImage: sortOptionIcon(option))
                                        .tag(option)
                                }
                            }
                        }
                        
                        if !subjects.isEmpty {
                            Section("科目フィルター") {
                                Button {
                                    selectedSubject = nil
                                } label: {
                                    HStack {
                                        Text("すべて")
                                        if selectedSubject == nil {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                                
                                ForEach(subjects, id: \.self) { subject in
                                    Button {
                                        selectedSubject = subject
                                    } label: {
                                        HStack {
                                            Text(subject)
                                            if selectedSubject == subject {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down.circle")
                    }
                }
            }
            .sheet(isPresented: $showTaskTypeSheet) {
                taskTypeSelectionSheet
            }
            .sheet(item: $selectedTask) { task in
                TaskEditView(task: task)
                    .environment(\.managedObjectContext, viewContext)
            }
            .sheet(isPresented: $showingFilterSheet) {
                filterView
            }
        }
    }
    
    // ナビゲーションタイトルを取得
    private func getNavigationTitle() -> String {
        switch selectedTaskType {
        case .all:
            return "課題とテスト"
        case .homework:
            return "課題一覧"
        case .exam:
            return "テスト予定"
        }
    }
    
    // タスクタイプ選択シート
    private var taskTypeSelectionSheet: some View {
        NavigationView {
            List {
                // 課題タイプ選択項目
                ForEach(TaskEnums.TaskType.allCases, id: \.self) { taskType in
                    Button(action: {
                        showTaskTypeSheet = false
                        
                        // タスク作成画面を表示（遅延実行で重なりを防止）
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showingAddSheet = true
                            
                            // 科目が選択されている場合は、その科目でタスクを作成
                            if let subject = selectedSubject {
                                let defaultColor = taskType == .homework ? "blue" : "red"
                                selectedTask = createNewTask(subject: subject, taskType: taskType, color: defaultColor)
                            } else {
                                // 科目が選択されていない場合、新規タスク作成画面を表示
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    // 科目なしで新規作成
                                    selectedTask = createNewTask(subject: "", taskType: taskType, color: taskType.defaultColor)
                                }
                            }
                        }
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: taskType.icon)
                                .frame(width: 30, height: 30)
                                .foregroundColor(.white)
                                .background(
                                    Circle()
                                        .fill(taskType == .homework ? Color.blue : Color.red)
                                )
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(taskType == .homework ? "課題を追加" : "テストを追加")
                                    .font(.headline)
                                
                                Text(taskType == .homework ? "提出物やレポートなどの課題" : "テストや試験の予定")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }
            }
            .navigationTitle("予定タイプを選択")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("キャンセル") {
                        showTaskTypeSheet = false
                    }
                }
            }
        }
    }
    
    // 新規タスク作成
    private func createNewTask(subject: String, taskType: TaskEnums.TaskType, color: String) -> Task {
        let newTask = Task(context: viewContext)
        newTask.id = UUID()
        newTask.subjectName = subject
        newTask.taskType = taskType.rawValue
        newTask.color = color
        newTask.createdAt = Date()
        newTask.updatedAt = Date()
        return newTask
    }
    
    // タスク行の表示
    private func taskRow(for task: Task) -> some View {
        Button(action: {
            selectedTask = task
        }) {
            HStack(alignment: .center) {
                // 完了状態
                Button(action: {
                    toggleTaskCompletion(task)
                }) {
                    Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(task.isCompleted ? .green : .gray)
                        .font(.title2)
                }
                .buttonStyle(BorderlessButtonStyle())
                
                // タスク情報
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        // アイコン（課題かテストかを表示）
                        Image(systemName: task.taskTypeEnum.icon)
                            .foregroundColor(task.taskTypeEnum == .homework ? .blue : .red)
                            .font(.caption)
                        
                        // 優先度表示
                        Circle()
                            .fill(task.priorityEnum.color)
                            .frame(width: 8, height: 8)
                        
                        // タイトル
                        Text(task.title ?? "無題")
                            .font(.headline)
                            .foregroundColor(task.isCompleted ? .secondary : .primary)
                            .strikethrough(task.isCompleted)
                    }
                    
                    HStack(spacing: 6) {
                        // 科目名
                        if let subjectName = task.subjectName, !subjectName.isEmpty {
                            Text(subjectName)
                                .font(.caption)
                                .padding(4)
                                .background(task.subjectColor.opacity(0.2))
                                .cornerRadius(4)
                        }
                        
                        // 期限表示
                        if task.dueDate != nil {
                            HStack(spacing: 2) {
                                Image(systemName: task.dueDateStatus.icon)
                                    .font(.caption)
                                    .foregroundColor(task.dueDateStatus.color)
                                
                                Text(task.formattedDueDate)
                                    .font(.caption)
                                    .foregroundColor(task.dueDateStatus.color)
                            }
                        }
                    }
                }
                
                Spacer()
                
                // 詳細表示アイコン
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(BorderlessButtonStyle())
    }
    
    // フィルター画面
    private var filterView: some View {
        NavigationView {
            List {
                Section(header: Text("期限")) {
                    ForEach(FilterOption.allCases) { option in
                        Button(action: {
                            filterOption = option
                            showingFilterSheet = false
                        }) {
                            HStack {
                                Text(option.rawValue)
                                Spacer()
                                if filterOption == option {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .foregroundColor(.primary)
                    }
                }
                
                Section(header: Text("予定タイプ")) {
                    ForEach(TaskTypeFilter.allCases) { type in
                        Button(action: {
                            selectedTaskType = type
                            showingFilterSheet = false
                        }) {
                            HStack {
                                Image(systemName: type.icon)
                                    .foregroundColor(type == .homework ? .blue : (type == .exam ? .red : .primary))
                                Text(type.rawValue)
                                Spacer()
                                if selectedTaskType == type {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .foregroundColor(.primary)
                    }
                }
                
                Section(header: Text("表示オプション")) {
                    Toggle("完了したタスクを表示", isOn: $showCompletedTasks)
                }
                
                if !subjects.isEmpty {
                    Section(header: Text("科目")) {
                        Button(action: {
                            selectedSubject = nil
                            showingFilterSheet = false
                        }) {
                            HStack {
                                Text("すべて")
                                Spacer()
                                if selectedSubject == nil {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .foregroundColor(.primary)
                        
                        ForEach(subjects, id: \.self) { subject in
                            Button(action: {
                                selectedSubject = subject
                                showingFilterSheet = false
                            }) {
                                HStack {
                                    Text(subject)
                                    Spacer()
                                    if selectedSubject == subject {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                            .foregroundColor(.primary)
                        }
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("フィルター")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") {
                        showingFilterSheet = false
                    }
                }
            }
        }
    }
    
    // 並べ替えオプションのアイコン
    private func sortOptionIcon(_ option: SortOption) -> String {
        switch option {
        case .dueDate: return "calendar"
        case .priority: return "exclamationmark.circle"
        case .subject: return "book"
        case .title: return "textformat"
        }
    }
    
    // タスクの完了状態を切り替える
    private func toggleTaskCompletion(_ task: Task) {
        withAnimation {
            task.toggleCompletion()
            saveContext()
        }
    }
    
    // タスクを削除する
    private func deleteTask(_ task: Task) {
        withAnimation {
            viewContext.delete(task)
            saveContext()
        }
    }
    
    // コンテキストの変更を保存
    private func saveContext() {
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            print("保存エラー: \(nsError), \(nsError.userInfo)")
        }
    }
}

// PreviewProvider
struct TaskManagementView_Previews: PreviewProvider {
    static var previews: some View {
        TaskManagementView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}

// Identifiable拡張
extension Task: Identifiable {}
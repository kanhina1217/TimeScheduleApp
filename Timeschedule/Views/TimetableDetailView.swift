import SwiftUI
import CoreData

struct TimetableDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) var presentationMode
    
    // 現在の時間割データ（編集時に使用）
    var existingTimetable: Timetable?
    
    // 新規作成時のデフォルト値
    var defaultDay: Int
    var defaultPeriod: Int
    var defaultPattern: Pattern
    
    // 編集用の状態変数
    @State private var subjectName: String = ""
    @State private var classroom: String = ""
    @State private var task: String = ""
    @State private var textbook: String = ""
    @State private var selectedColor: String = "blue"
    
    // 利用可能な色の配列
    private let availableColors = ["red", "blue", "green", "yellow", "purple", "gray"]
    
    // 初期化処理
    init(timetable: Timetable?, day: Int, period: Int, pattern: Pattern) {
        self.existingTimetable = timetable
        self.defaultDay = day
        self.defaultPeriod = period
        self.defaultPattern = pattern
    }
    
    var body: some View {
        NavigationView {
            Form {
                // 基本情報セクション
                Section(header: Text("基本情報")) {
                    TextField("教科名", text: $subjectName)
                    TextField("教室", text: $classroom)
                }
                
                // 詳細情報セクション
                Section(header: Text("詳細情報")) {
                    TextField("課題", text: $task)
                    TextField("教科書", text: $textbook)
                }
                
                // 色選択セクション
                Section(header: Text("色")) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: 10) {
                        ForEach(availableColors, id: \.self) { color in
                            colorCell(color)
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                // 削除ボタンセクション（既存データの場合のみ表示）
                if existingTimetable != nil {
                    Section {
                        Button(action: deleteTimetable) {
                            Text("削除")
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                }
            }
            .navigationTitle(existingTimetable != nil ? "時間割の編集" : "時間割の追加")
            .navigationBarItems(
                leading: Button("キャンセル") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("保存") {
                    saveTimetable()
                }
            )
            .onAppear {
                loadTimetableData()
            }
        }
    }
    
    // 色選択セル
    private func colorCell(_ color: String) -> some View {
        let uiColor: Color = {
            switch color {
            case "red": return .red
            case "blue": return .blue
            case "green": return .green
            case "yellow": return .yellow
            case "purple": return .purple
            default: return .gray
            }
        }()
        
        return Circle()
            .fill(uiColor.opacity(0.7))
            .frame(width: 40, height: 40)
            .overlay(
                Circle()
                    .stroke(Color.primary, lineWidth: selectedColor == color ? 3 : 0)
            )
            .onTapGesture {
                selectedColor = color
            }
    }
    
    // 既存データの読み込み
    private func loadTimetableData() {
        if let timetable = existingTimetable {
            subjectName = timetable.subjectName ?? ""
            classroom = timetable.classroom ?? ""
            task = timetable.task ?? ""
            textbook = timetable.textbook ?? ""
            selectedColor = timetable.color ?? "blue"
        }
    }
    
    // 時間割データの保存
    private func saveTimetable() {
        withAnimation {
            // 新規作成または既存レコードの更新
            let timetable = existingTimetable ?? Timetable(context: viewContext)
            
            // 既存データがない場合のみIDと基本情報を設定
            if existingTimetable == nil {
                timetable.id = UUID()
                timetable.dayOfWeek = Int16(defaultDay)
                timetable.period = Int16(defaultPeriod)
                timetable.relationship = defaultPattern
            }
            
            // 共通の更新処理
            timetable.subjectName = subjectName
            timetable.classroom = classroom
            timetable.task = task
            timetable.textbook = textbook
            timetable.color = selectedColor
            
            // 保存
            do {
                try viewContext.save()
                presentationMode.wrappedValue.dismiss()
            } catch {
                let nsError = error as NSError
                print("時間割の保存エラー: \(nsError), \(nsError.userInfo)")
            }
        }
    }
    
    // 時間割データの削除
    private func deleteTimetable() {
        withAnimation {
            if let timetable = existingTimetable {
                viewContext.delete(timetable)
                
                do {
                    try viewContext.save()
                    presentationMode.wrappedValue.dismiss()
                } catch {
                    let nsError = error as NSError
                    print("時間割の削除エラー: \(nsError), \(nsError.userInfo)")
                }
            }
        }
    }
}

struct TimetableDetailView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        let pattern = Pattern(context: context)
        pattern.id = UUID()
        pattern.name = "通常"
        pattern.isDefault = true
        
        return TimetableDetailView(timetable: nil, day: 0, period: 1, pattern: pattern)
            .environment(\.managedObjectContext, context)
    }
}
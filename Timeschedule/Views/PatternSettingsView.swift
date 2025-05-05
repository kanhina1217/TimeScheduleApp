import SwiftUI
import CoreData

struct PatternSettingsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) var presentationMode
    
    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(keyPath: \Pattern.isDefault, ascending: false),
            NSSortDescriptor(keyPath: \Pattern.name, ascending: true)
        ],
        animation: .default)
    private var patterns: FetchedResults<Pattern>
    
    var body: some View {
        NavigationView {
            List {
                ForEach(patterns, id: \.self) { pattern in
                    NavigationLink(destination:
                        PatternDetailView(pattern: pattern)
                            .environment(\.managedObjectContext, viewContext)
                    ) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(pattern.name ?? "不明なパターン")
                                    .font(.headline)
                                if pattern.isDefault {
                                    Text("デフォルト")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                            Text("\(pattern.periodCount)時限")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                    }
                }
                .onDelete(perform: deletePatterns)
            }
            .navigationTitle("時程パターン")
            .navigationBarItems(trailing:
                NavigationLink(destination:
                    PatternDetailView(pattern: nil)
                        .environment(\.managedObjectContext, viewContext)
                ) {
                    Image(systemName: "plus")
                }
            )
        }
    }
    
    private func deletePatterns(offsets: IndexSet) {
        withAnimation {
            offsets.map { patterns[$0] }.forEach(viewContext.delete)
            
            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                print("パターン削除エラー: \(nsError), \(nsError.userInfo)")
            }
        }
    }
}

// 時程パターンの詳細/編集画面
struct PatternDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) var presentationMode
    
    var existingPattern: Pattern?
    
    @State private var patternName: String = ""
    @State private var isDefault: Bool = false
    @State private var useWeekdays: Bool = true  // 月～金を使用
    @State private var useSaturday: Bool = false // 土曜を使用
    @State private var useSunday: Bool = false   // 日曜を使用
    @State private var periodTimes: [[String: String]] = [
        ["period": "1", "startTime": "8:30", "endTime": "9:20"],
        ["period": "2", "startTime": "9:30", "endTime": "10:20"],
        ["period": "3", "startTime": "10:40", "endTime": "11:30"],
        ["period": "4", "startTime": "11:40", "endTime": "12:30"],
        ["period": "5", "startTime": "13:20", "endTime": "14:10"],
        ["period": "6", "startTime": "14:20", "endTime": "15:10"]
    ]
    @State private var startTimes: [Date] = []
    @State private var endTimes: [Date] = []
    
    init(pattern: Pattern?) {
        self.existingPattern = pattern
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("基本情報")) {
                    TextField("パターン名", text: $patternName)
                    Toggle("デフォルトパターン", isOn: $isDefault)
                }
                
                Section(header: Text("使用する曜日")) {
                    Toggle("平日（月～金）", isOn: $useWeekdays)
                    Toggle("土曜日", isOn: $useSaturday)
                    Toggle("日曜日", isOn: $useSunday)
                }
                
                Section(header: Text("時限設定")) {
                    ForEach(0..<startTimes.count, id: \.self) { index in
                        HStack {
                            Text("\(index + 1)限")
                                .font(.headline)
                                .frame(width: 40)
                            
                            DatePicker("", selection: Binding(
                                get: { startTimes[index] },
                                set: { startTimes[index] = $0 }
                            ), displayedComponents: .hourAndMinute)
                            .labelsHidden()
                            
                            Text("-")
                            
                            DatePicker("", selection: Binding(
                                get: { endTimes[index] },
                                set: { endTimes[index] = $0 }
                            ), displayedComponents: .hourAndMinute)
                            .labelsHidden()
                            
                            if startTimes.count > 1 {
                                Button(action: {
                                    removePeriod(at: index)
                                }) {
                                    Image(systemName: "minus.circle")
                                        .foregroundColor(.red)
                                }
                            }
                        }
                    }
                    
                    Button(action: addPeriod) {
                        Label("時限を追加", systemImage: "plus.circle")
                    }
                }
                
                if existingPattern != nil {
                    Section {
                        Button(action: deletePattern) {
                            Text("削除")
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                }
            }
            .navigationTitle(existingPattern != nil ? "パターンの編集" : "新規パターン")
            .navigationBarItems(
                leading: Button("キャンセル") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("保存") {
                    savePattern()
                }
            )
            .onAppear {
                loadPatternData()
            }
        }
    }
    
    // 新しい時限を追加
    private func addPeriod() {
        if let lastEnd = endTimes.last {
            let newStart = lastEnd.addingTimeInterval(10 * 60)
            let newEnd = newStart.addingTimeInterval(50 * 60)
            startTimes.append(newStart)
            endTimes.append(newEnd)
        } else {
            // デフォルトフォールバック：現在時刻から1時間
            let now = Date()
            let newStart = now
            let newEnd = now.addingTimeInterval(50 * 60)
            startTimes.append(newStart)
            endTimes.append(newEnd)
        }
    }
    
    // 時限を削除
    private func removePeriod(at index: Int) {
        startTimes.remove(at: index)
        endTimes.remove(at: index)
    }
    
    // パターンデータの読み込み
    private func loadPatternData() {
        let formatter = DateFormatter()
        formatter.dateFormat = "H:mm"
        if let pattern = existingPattern {
            // 既存パターン編集時
            patternName = pattern.name ?? ""
            isDefault = pattern.isDefault
            let times: [[String: String]]
            if let t = pattern.periodTimes as? [[String: String]] {
                times = t
            } else {
                times = pattern.periodTimeArray
            }
            startTimes = times.compactMap { formatter.date(from: $0["startTime"] ?? "") }
            endTimes = times.compactMap { formatter.date(from: $0["endTime"] ?? "") }
        } else {
            // 新規作成時：デフォルト設定を読み込む
            startTimes = periodTimes.compactMap { formatter.date(from: $0["startTime"] ?? "") }
            endTimes = periodTimes.compactMap { formatter.date(from: $0["endTime"] ?? "") }
        }
    }
    
    // パターンの保存
    private func savePattern() {
        withAnimation {
            let pattern = existingPattern ?? Pattern(context: viewContext)
            
            if existingPattern == nil {
                pattern.id = UUID()
            }
            
            pattern.name = patternName
            pattern.isDefault = isDefault
            
            // パターンを保存する前に文字列に変換
            let formatter = DateFormatter()
            formatter.dateFormat = "H:mm"
            var timesArray: [[String: String]] = []
            for i in 0..<startTimes.count {
                let start = formatter.string(from: startTimes[i])
                let end = formatter.string(from: endTimes[i])
                timesArray.append(["period": "\(i+1)", "startTime": start, "endTime": end])
            }
            pattern.periodTimes = timesArray as NSObject
            
            // 曜日設定は今後のバージョンで使用するためのみに保存
            // 実際の使用曜日は別の場所で管理する可能性がある
            
            // 他のパターンのデフォルト状態を更新
            if isDefault {
                updateOtherPatternsDefaultState(except: pattern)
            }
            
            do {
                try viewContext.save()
                presentationMode.wrappedValue.dismiss()
            } catch {
                let nsError = error as NSError
                print("パターン保存エラー: \(nsError), \(nsError.userInfo)")
            }
        }
    }
    
    // 他のパターンのデフォルト状態を更新
    private func updateOtherPatternsDefaultState(except currentPattern: Pattern) {
        let request: NSFetchRequest<Pattern> = Pattern.fetchRequest()
        request.predicate = NSPredicate(format: "self != %@", currentPattern)
        
        do {
            let patterns = try viewContext.fetch(request)
            for pattern in patterns {
                if pattern.isDefault {
                    pattern.isDefault = false
                }
            }
        } catch {
            print("パターン取得エラー: \(error)")
        }
    }
    
    // パターンの削除
    private func deletePattern() {
        withAnimation {
            if let pattern = existingPattern {
                viewContext.delete(pattern)
                
                do {
                    try viewContext.save()
                    presentationMode.wrappedValue.dismiss()
                } catch {
                    let nsError = error as NSError
                    print("パターン削除エラー: \(nsError), \(nsError.userInfo)")
                }
            }
        }
    }
}
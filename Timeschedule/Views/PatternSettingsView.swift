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
    
    @State private var showingAddPatternSheet = false
    @State private var selectedPattern: Pattern?
    
    var body: some View {
        NavigationView {
            List {
                ForEach(patterns, id: \.self) { pattern in
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
                        
                        // 時限数
                        Text("\(pattern.periodCount)時限")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedPattern = pattern
                        showingAddPatternSheet = true
                    }
                }
                .onDelete(perform: deletePatterns)
            }
            .navigationTitle("時程パターン")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        selectedPattern = nil
                        showingAddPatternSheet = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }
            }
            .sheet(isPresented: $showingAddPatternSheet) {
                PatternDetailView(pattern: selectedPattern)
                    .environment(\.managedObjectContext, viewContext)
            }
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
    @State private var periodTimes: [[String: String]] = [
        ["period": "1", "startTime": "8:30", "endTime": "9:20"],
        ["period": "2", "startTime": "9:30", "endTime": "10:20"],
        ["period": "3", "startTime": "10:40", "endTime": "11:30"],
        ["period": "4", "startTime": "11:40", "endTime": "12:30"],
        ["period": "5", "startTime": "13:20", "endTime": "14:10"],
        ["period": "6", "startTime": "14:20", "endTime": "15:10"]
    ]
    
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
                
                Section(header: Text("時限設定")) {
                    ForEach(0..<periodTimes.count, id: \.self) { index in
                        HStack {
                            Text("\(index + 1)限")
                                .font(.headline)
                                .frame(width: 40)
                            
                            TextField("開始", text: Binding(
                                get: { periodTimes[index]["startTime"] ?? "" },
                                set: { periodTimes[index]["startTime"] = $0 }
                            ))
                            .keyboardType(.numbersAndPunctuation)
                            
                            Text("-")
                            
                            TextField("終了", text: Binding(
                                get: { periodTimes[index]["endTime"] ?? "" },
                                set: { periodTimes[index]["endTime"] = $0 }
                            ))
                            .keyboardType(.numbersAndPunctuation)
                            
                            // 削除ボタン追加
                            if periodTimes.count > 1 {
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
        let newIndex = periodTimes.count + 1
        let newPeriod = [
            "period": "\(newIndex)",
            "startTime": "00:00",
            "endTime": "00:00"
        ]
        periodTimes.append(newPeriod)
    }
    
    // 時限を削除
    private func removePeriod(at index: Int) {
        periodTimes.remove(at: index)
    }
    
    // パターンデータの読み込み
    private func loadPatternData() {
        if let pattern = existingPattern {
            patternName = pattern.name ?? ""
            isDefault = pattern.isDefault
            
            // periodTimesデータを正しく取得
            if let times = pattern.periodTimes as? [[String: String]] {
                periodTimes = times
            } else {
                // periodTimeArrayは非オプショナルなので直接使用
                let times = pattern.periodTimeArray
                if !times.isEmpty {
                    periodTimes = times
                }
            }
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
            pattern.periodTimes = periodTimes as NSObject
            
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
import Foundation

// Pattern.periodTimesのための安全なValue Transformer
@objc(PeriodTimesValueTransformer)
class PeriodTimesValueTransformer: NSSecureUnarchiveFromDataTransformer {
    
    // 許可されるクラスを指定
    override static var allowedTopLevelClasses: [AnyClass] {
        // 配列、文字列、数値、日付、辞書をサポート
        return [NSArray.self, NSString.self, NSNumber.self, NSDate.self, NSDictionary.self]
    }
    
    // Value Transformerを登録するためのヘルパーメソッド
    static func register() {
        let transformer = PeriodTimesValueTransformer()
        ValueTransformer.setValueTransformer(
            transformer, 
            forName: NSValueTransformerName("PeriodTimesValueTransformer")
        )
    }
}

// 名前を簡単に参照するための拡張
extension NSValueTransformerName {
    static let periodTimesTransformerName = NSValueTransformerName(rawValue: "PeriodTimesValueTransformer")
}

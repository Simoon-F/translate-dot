import Foundation

enum L10n {
    static func string(_ key: String, defaultValue: String) -> String {
        Bundle.main.localizedString(forKey: key, value: defaultValue, table: nil)
    }

    static func formatted(
        _ key: String,
        defaultValue: String,
        _ arguments: any CVarArg...
    ) -> String {
        String(
            format: string(key, defaultValue: defaultValue),
            locale: Locale.current,
            arguments: arguments
        )
    }
}

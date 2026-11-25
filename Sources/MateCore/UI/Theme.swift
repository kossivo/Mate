import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

public enum MateTheme {
    public static let primaryAccent = Color.blue
    public static let secondaryAccent = Color.indigo

    #if canImport(UIKit)
    public static let background = Color(uiColor: .systemBackground)
    public static let secondaryBackground = Color(uiColor: .secondarySystemBackground)
    public static let tertiaryBackground = Color(uiColor: .tertiarySystemBackground)
    #elseif canImport(AppKit)
    public static let background = Color(nsColor: .windowBackgroundColor)
    public static let secondaryBackground = Color(nsColor: .controlBackgroundColor)
    public static let tertiaryBackground = Color(nsColor: .underPageBackgroundColor)
    #endif

    public static let cornerRadius: CGFloat = 16
    public static let padding: CGFloat = 16

    public static func priorityColor(_ priority: TaskPriority) -> Color {
        switch priority {
        case .urgent: return .red
        case .high: return .orange
        case .medium: return .blue
        case .low: return .gray
        }
    }
}

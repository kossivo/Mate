import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

public enum MateTheme {
    // Pure OLED & Obsidian Luxury Palette (NikeLab / Apple Pro aesthetic)
    public static let pureBlack = Color(red: 0, green: 0, blue: 0)
    public static let cardBackground = Color(red: 18/255, green: 18/255, blue: 20/255)
    public static let elevatedCard = Color(red: 26/255, green: 26/255, blue: 30/255)
    public static let microBorder = Color(red: 38/255, green: 38/255, blue: 42/255)
    public static let hairlineDivider = Color.white.opacity(0.06)
    
    // Stark White & Cool Silver Accents
    public static let opticWhite = Color.white
    public static let silverMuted = Color(red: 142/255, green: 142/255, blue: 147/255)
    public static let slateDim = Color(red: 99/255, green: 99/255, blue: 102/255)
    
    // Assistant Glow / Accent
    public static let assistantPulse = Color(red: 59/255, green: 130/255, blue: 246/255)
    public static let assistantGlow = Color(red: 147/255, green: 197/255, blue: 253/255)

    #if canImport(UIKit)
    public static let background = pureBlack
    public static let secondaryBackground = cardBackground
    public static let tertiaryBackground = elevatedCard
    #elseif canImport(AppKit)
    public static let background = pureBlack
    public static let secondaryBackground = cardBackground
    public static let tertiaryBackground = elevatedCard
    #endif

    public static let cornerRadius: CGFloat = 18
    public static let padding: CGFloat = 16

    public static func priorityColor(_ priority: TaskPriority) -> Color {
        switch priority {
        case .urgent: return Color(red: 255/255, green: 69/255, blue: 58/255) // Stark Crimson
        case .high: return Color(red: 255/255, green: 159/255, blue: 10/255) // Apple Amber
        case .medium: return opticWhite
        case .low: return silverMuted
        }
    }
}

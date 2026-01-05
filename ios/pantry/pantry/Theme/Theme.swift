import SwiftUI

/// Centralized theme definitions for Pantry's warm, kitchen-inspired visual design.
enum PantryTheme {
    // MARK: - Colors

    /// Kitchen-inspired color palette with light/dark mode support.
    /// Colors are defined in Assets.xcassets for automatic appearance switching.
    enum Colors {
        /// Main background - warm cream in light, deep charcoal in dark
        static let background = Color("Cream")

        /// Card/surface background - clean white in light, warm gray in dark
        static let cardBackground = Color("Linen")

        /// Primary accent - warm terracotta for buttons, selections
        static let accent = Color("Terracotta")

        /// Secondary accent - muted sage for "Easy" badges, positive states
        static let secondaryAccent = Color("Sage")

        /// Primary text - rich espresso brown
        static let primaryText = Color("Espresso")

        /// Secondary text - warm walnut for labels, hints
        static let secondaryText = Color("Walnut")

        /// Tertiary text - light oat for placeholders, disabled
        static let tertiaryText = Color("Oat")

        /// Highlight color - soft butter for selected states
        static let highlight = Color("Butter")
    }

    // MARK: - Typography

    /// Typography scale using New York (serif) for warmth and SF Pro for readability.
    enum Typography {
        /// Large titles - serif for editorial feel
        static let largeTitle = Font.system(.largeTitle, design: .serif)

        /// Screen titles - serif with semibold weight
        static let title = Font.system(.title2, design: .serif).weight(.semibold)

        /// Section headlines - serif
        static let headline = Font.system(.headline, design: .serif)

        /// Body text - default sans-serif for readability
        static let body = Font.system(.body)

        /// Secondary labels - sans-serif
        static let subheadline = Font.system(.subheadline)

        /// Small text - sans-serif
        static let caption = Font.system(.caption)
    }

    // MARK: - Dimensions

    /// Corner radius values
    enum Radius {
        static let card: CGFloat = 16
        static let badge: CGFloat = 8
        static let button: CGFloat = 12
    }

    /// Spacing values
    enum Spacing {
        static let cardPadding: CGFloat = 20
        static let cardSpacing: CGFloat = 16
        static let sectionSpacing: CGFloat = 24
        static let screenPadding: CGFloat = 20
    }
}

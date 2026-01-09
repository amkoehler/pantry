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

        /// Primary accent - warm terracotta for selections, secondary buttons
        static let accent = Color("Terracotta")

        /// CTA accent - deeper terracotta for primary action buttons
        static let accentCTA = Color("TerracottaCTA")

        /// Secondary accent - muted sage for "Easy" badges, positive states
        static let secondaryAccent = Color("Sage")

        /// Destructive/urgent accent - warm paprika for destructive actions
        static let destructive = Color("Paprika")

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
    /// Uses explicit sizes for precise control across devices.
    enum Typography {
        /// Display: Hero moments only (onboarding, empty states) - 34pt serif bold
        static let display = Font.system(size: 34, weight: .bold, design: .serif)

        /// Title: Screen headers, meal names - 22pt serif semibold
        static let title = Font.system(size: 22, weight: .semibold, design: .serif)

        /// Headline: Section headers, day labels - 17pt sans semibold
        static let headline = Font.system(size: 17, weight: .semibold, design: .default)

        /// Body: Descriptions, secondary info - 17pt sans regular
        static let body = Font.system(size: 17, weight: .regular, design: .default)

        /// Subheadline: Metadata, timestamps - 15pt sans regular
        static let subheadline = Font.system(size: 15, weight: .regular, design: .default)

        /// Caption: Badges, tertiary info - 13pt sans medium
        static let caption = Font.system(size: 13, weight: .medium, design: .default)

        /// Badge: Prep time, tags - 12pt rounded semibold (friendlier feel)
        static let badge = Font.system(size: 12, weight: .semibold, design: .rounded)
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

    // MARK: - Shadows

    /// Shadow configurations for depth
    enum Shadows {
        /// Card shadow values - dark mode is subtle since cards have color separation
        static func cardShadow(for colorScheme: ColorScheme) -> some View {
            Group {
                if colorScheme == .dark {
                    // Dark mode: subtle, tight shadow
                    Color.black.opacity(0.15)
                        .blur(radius: 4)
                        .offset(y: 2)
                } else {
                    // Light mode: soft, slightly diffuse shadow
                    Color.black.opacity(0.06)
                        .blur(radius: 6)
                        .offset(y: 2)
                }
            }
        }
    }
}

// MARK: - View Extensions

extension View {
    /// Applies themed card shadow based on color scheme
    /// Dark mode: subtle, tight shadow - cards already have color separation
    /// Light mode: soft, slightly diffuse shadow for depth
    func pantryCardShadow(colorScheme: ColorScheme) -> some View {
        self.background(
            PantryTheme.Colors.cardBackground
                .clipShape(RoundedRectangle(cornerRadius: PantryTheme.Radius.card))
                .shadow(
                    color: colorScheme == .dark
                        ? Color.black.opacity(0.15)
                        : Color.black.opacity(0.06),
                    radius: colorScheme == .dark ? 4 : 6,
                    y: 2
                )
        )
    }

    /// Applies badge text styling with subtle letter-spacing
    func badgeStyle() -> some View {
        self
            .font(PantryTheme.Typography.badge)
            .tracking(0.3)
    }
}

import Foundation

enum ThemeRegistry {
    static let defaultID = "default"
    static let all: [ThemeDefinition] = [
        DefaultTheme.make(),
        GlanceWebTheme.make()
    ] + GlancePresetThemes.makeDefinitions()
}

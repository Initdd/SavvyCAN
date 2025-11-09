pragma Singleton
import QtQuick
import QtQuick.Controls

QtObject {
    id: themeManager
    
    // Detect if we're in dark mode
    readonly property bool isDarkMode: {
        // Qt 6 provides palette.window to detect system theme
        // We can check if the window color is dark
        var windowColor = palette.window
        var luminance = (0.299 * windowColor.r + 0.587 * windowColor.g + 0.114 * windowColor.b)
        return luminance < 0.5
    }
    
    // System palette for automatic color detection
    property SystemPalette palette: SystemPalette {
        colorGroup: SystemPalette.Active
    }
    
    // Background colors
    readonly property color backgroundColor: isDarkMode ? "#1e1e1e" : "#ffffff"
    readonly property color secondaryBackgroundColor: isDarkMode ? "#252526" : "#f0f0f0"
    readonly property color alternateBackgroundColor: isDarkMode ? "#2d2d30" : "#f5f5f5"
    readonly property color surfaceColor: isDarkMode ? "#2d2d30" : "#ffffff"
    
    // Text colors
    readonly property color textColor: isDarkMode ? "#e0e0e0" : "#333333"
    readonly property color secondaryTextColor: isDarkMode ? "#a0a0a0" : "#666666"
    readonly property color tertiaryTextColor: isDarkMode ? "#808080" : "#999999"
    readonly property color placeholderTextColor: isDarkMode ? "#707070" : "#999999"
    
    // Border colors
    readonly property color borderColor: isDarkMode ? "#3e3e42" : "#cccccc"
    readonly property color lightBorderColor: isDarkMode ? "#2d2d30" : "#e0e0e0"
    
    // Accent and status colors
    // NOTE: If you change accentColor, also update the Material theme settings in main.cpp
    // (QT_QUICK_CONTROLS_MATERIAL_ACCENT and QT_QUICK_CONTROLS_MATERIAL_PRIMARY)
    readonly property color accentColor: "#3daee9"
    readonly property color highlightColor: isDarkMode ? "rgba(61, 174, 233, 0.3)" : "rgba(61, 174, 233, 0.3)"
    readonly property color successColor: "#4caf50"
    readonly property color errorColor: "#f44336"
    readonly property color warningColor: "#ff9800"
    readonly property color infoColor: "#2196f3"
    
    // Button colors
    readonly property color buttonColor: isDarkMode ? "#3e3e42" : "#e0e0e0"
    readonly property color buttonHoverColor: isDarkMode ? "#4e4e52" : "#d0d0d0"
    readonly property color buttonPressedColor: isDarkMode ? "#5e5e62" : "#c0c0c0"
    readonly property color buttonTextColor: textColor
    
    // Input colors
    readonly property color inputBackgroundColor: isDarkMode ? "#1e1e1e" : "#ffffff"
    readonly property color inputBorderColor: borderColor
    readonly property color inputFocusBorderColor: accentColor
    
    // Direction colors (for Rx/Tx indicators)
    readonly property color rxColor: isDarkMode ? "#4fc3f7" : "#0066cc"
    readonly property color txColor: isDarkMode ? "#ffb74d" : "#cc6600"
    
    // Connection status colors
    readonly property color connectedColor: successColor
    readonly property color disconnectedColor: errorColor
    
    // Special UI colors
    readonly property color groupBoxBackground: isDarkMode ? "#2d2d30" : "#fafafa"
    readonly property color tabBarBackground: isDarkMode ? "#2d2d30" : "#f0f0f0"
    readonly property color dialogBackground: isDarkMode ? "#252526" : "#ffffff"
    
    // Frame list colors
    readonly property color frameEvenRow: isDarkMode ? "#2d2d30" : "#ffffff"
    readonly property color frameOddRow: isDarkMode ? "#252526" : "#f5f5f5"
    readonly property color frameBorder: lightBorderColor
    
    // Sender item colors
    readonly property color senderEnabledBorder: successColor
    readonly property color senderDisabledBorder: borderColor
}

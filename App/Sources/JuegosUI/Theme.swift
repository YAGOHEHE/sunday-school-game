import SwiftUI
import JuegosCore
import CoreText
#if os(macOS)
import AppKit
#else
import UIKit
#endif

// CONTRATO COMPARTIDO (Opus): sistema visual. Tokens de diseno/ y del brief. Úsalos en vez de colores sueltos.

public enum Theme {
    // MARK: Neutros (adaptativos claro/oscuro)
    public static let background = Color(light: 0xF5F3EE, dark: 0x0B0B0F)
    public static let surface    = Color(light: 0xFFFFFF, dark: 0x1C1C24)
    public static let border     = Color(light: 0xECE8DF, dark: 0x2A2A35)
    public static let ink        = Color(light: 0x1F1D2B, dark: 0xF5F3EE)
    public static let secondary  = Color(light: 0x5E5B6B, dark: 0xA8A5B5)

    // Fijos (no cambian con el modo) para superficies que siempre son oscuras/claras (proyector, plantillas).
    public static let darkBackground = Color(hex: 0x0B0B0F)
    public static let darkSurface    = Color(hex: 0x1C1C24)
    public static let darkBorder     = Color(hex: 0x2A2A35)
    public static let lightBackground = Color(hex: 0xFFFFFF)
    public static let inkFixed       = Color(hex: 0x1F1D2B)
    public static let secondaryFixed = Color(hex: 0x5E5B6B)

    // Valores por defecto de las variables {{...}} de los mockups.
    public static let accentPlanificar = Color(hex: 0x6D3FD0)
    public static let ringReloj        = Color(hex: 0x34D399)

    // MARK: Tipografía
    /// Fredoka si está registrada; si no, sistema redondeada.
    public static func font(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        if fredokaAvailable { return .custom("Fredoka", size: size).weight(weight) }
        return .system(size: size, weight: weight, design: .rounded)
    }
    /// Texto en chino: Noto Sans SC si está registrada; si no, PingFang SC.
    public static func fontZH(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        let family = notoAvailable ? "Noto Sans SC" : "PingFang SC"
        return .custom(family, size: size).weight(weight)
    }

    static let fredokaAvailable: Bool = {
        registerBundledFonts()
        return fontFamilyExists("Fredoka")
    }()
    static let notoAvailable = fontFamilyExists("Noto Sans SC")

    /// Registra las fuentes empaquetadas (Resources/Fonts) para este proceso.
    /// Dentro del .app el bundle está en Contents/Resources; en `swift run`, Bundle.module.
    static func registerBundledFonts() {
        let name = "JuegosDominical_JuegosUI.bundle"
        let bundle: Bundle? = Bundle.main.resourceURL
            .flatMap { Bundle(url: $0.appendingPathComponent(name)) }
            ?? Bundle(url: Bundle.main.bundleURL.appendingPathComponent(name))
        let fontsURL = (bundle ?? Bundle.module).url(forResource: "Fonts", withExtension: nil)
        guard let dir = fontsURL,
              let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return }
        for url in files where ["ttf", "otf"].contains(url.pathExtension.lowercased()) {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }

    private static func fontFamilyExists(_ family: String) -> Bool {
        #if os(macOS)
        return NSFontManager.shared.availableFontFamilies.contains(family)
        #else
        return UIFont.familyNames.contains(family)
        #endif
    }

    /// Lado mínimo de cualquier control pulsable.
    public static let minTap: CGFloat = 44
    public static let cornerRadius: CGFloat = 16
}

// MARK: - Colores de categoría

extension GameCategory {
    /// Color principal (texto blanco encima pasa AA).
    public var color: Color {
        switch self {
        case .energia: return Color(hex: 0xC2410C)
        case .mente: return Color(hex: 0x6D3FD0)
        case .equipo: return Color(hex: 0x15803D)
        case .expresion: return Color(hex: 0xBE185D)
        case .conocerse: return Color(hex: 0x1D4ED8)
        }
    }
    /// Tinte claro de fondo.
    public var tint: Color {
        switch self {
        case .energia: return Color(hex: 0xFFE8D9)
        case .mente: return Color(hex: 0xEEE6FD)
        case .equipo: return Color(hex: 0xDDF5E6)
        case .expresion: return Color(hex: 0xFDE2EC)
        case .conocerse: return Color(hex: 0xE0EAFE)
        }
    }
    /// Variante para fondo oscuro.
    public var onDark: Color {
        switch self {
        case .energia: return Color(hex: 0xFF8A3D)
        case .mente: return Color(hex: 0xA78BFA)
        case .equipo: return Color(hex: 0x34D399)
        case .expresion: return Color(hex: 0xF472B6)
        case .conocerse: return Color(hex: 0x60A5FA)
        }
    }
    /// Tinte adaptativo: claro en modo claro, color oscurecido en modo oscuro.
    public var adaptiveTint: Color {
        switch self {
        case .energia: return Color(light: 0xFFE8D9, dark: 0x3A2316)
        case .mente: return Color(light: 0xEEE6FD, dark: 0x2A2142)
        case .equipo: return Color(light: 0xDDF5E6, dark: 0x16301F)
        case .expresion: return Color(light: 0xFDE2EC, dark: 0x3A1828)
        case .conocerse: return Color(light: 0xE0EAFE, dark: 0x18233F)
        }
    }
}

// MARK: - Helpers de color

extension Color {
    public init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }

    /// "#RRGGBB" o "RRGGBB". nil si no es válido.
    public init?(hexString: String) {
        var s = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return nil }
        self.init(hex: v)
    }

    public init(light: UInt32, dark: UInt32) {
        #if os(macOS)
        self.init(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return NSColor(Color(hex: isDark ? dark : light))
        })
        #else
        self.init(uiColor: UIColor { traits in
            UIColor(Color(hex: traits.userInterfaceStyle == .dark ? dark : light))
        })
        #endif
    }
}

extension TemplateBackground {
    /// Color de fondo de la plantilla. `category` = color de la categoría (o de la tarjeta activa si se pasa `flash`).
    public func color(category: GameCategory, flash: Color? = nil) -> Color {
        switch self {
        case .category: return flash ?? category.color
        case .dark: return Theme.darkBackground
        case .light: return Theme.lightBackground
        case .custom(let hex): return Color(hexString: hex) ?? category.color
        }
    }
    /// true si el texto encima debe ser blanco.
    public var prefersLightText: Bool {
        switch self {
        case .light: return false
        default: return true
        }
    }
}

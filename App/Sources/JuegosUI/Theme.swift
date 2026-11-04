import SwiftUI
import JuegosCore
import CoreText
#if os(macOS)
import AppKit
#else
import UIKit
#endif

// CONTRATO COMPARTIDO (Opus): sistema visual «Pizarra» (diseno/80-Pizarra-Planificar.html).
// Paleta del icono: tablero magenta, acento amarillo, papel blanco, tinta. Úsalos en vez de colores sueltos.
// Los tokens del tablero son FIJOS (no se invierten en modo oscuro): la pizarra es un diseño, no una UI neutra.

public enum Theme {
    // MARK: Tablero (la ventana) — magenta del icono, texto blanco encima.
    /// Fondo de la ventana/columnas: el tablero magenta.
    public static let background = Color(hex: 0xBE185D)
    /// Texto/iconos sobre el tablero.
    public static let onBoard    = Color(hex: 0xFFFFFF)
    /// Líneas discontinuas que separan columnas (blanco a baja opacidad).
    public static let boardLine  = Color.white.opacity(0.30)
    /// Panel translúcido para controles que van sobre el tablero (buscador, selector de idioma).
    public static let boardPanel = Color.black.opacity(0.18)

    // MARK: Acento — amarillo del icono. Texto encima = tinta.
    public static let accent   = Color(hex: 0xFFD43B)
    public static let onAccent = Color(hex: 0x1F1D2B)

    // MARK: Superficie — tarjetas de papel. Tinta y texto secundario del brief.
    public static let surface   = Color(hex: 0xFFFFFF)
    public static let ink       = Color(hex: 0x1F1D2B)
    public static let secondary = Color(hex: 0x6B6458)
    /// Papel cálido (recuadros, fila seleccionada).
    public static let paper     = Color(hex: 0xFFFCF2)
    /// Hairline casi invisible sobre papel blanco (la sombra dura hace el contorno).
    public static let border    = Color(hex: 0x1F1D2B, opacity: 0.10)
    /// Sombra dura desplazada de las tarjetas (negro ~0.28, radio 0).
    public static let cardShadow = Color.black.opacity(0.28)

    // Fijos para superficies que siempre son oscuras/claras (proyector, plantillas de modo juego).
    public static let darkBackground = Color(hex: 0x0B0B0F)
    public static let darkSurface    = Color(hex: 0x1C1C24)
    public static let darkBorder     = Color(hex: 0x2A2A35)
    public static let lightBackground = Color(hex: 0xFFFFFF)
    public static let inkFixed       = Color(hex: 0x1F1D2B)
    public static let secondaryFixed = Color(hex: 0x6B6458)

    // Acento secundario del planificador (enlaces, filtro activo): morado del icono (= categoría «mente»).
    public static let accentPlanificar = Color(hex: 0x6D3FD0)
    /// Magenta de relleno del botón «Jugar».
    public static let primaryMagenta   = Color(hex: 0xBE185D)
    public static let ringReloj        = Color(hex: 0x34D399)

    // MARK: Tipografía
    /// Fredoka si está registrada; si no, sistema redondeada.
    /// Fredoka (variable) llega hasta 700/Bold: no simulamos pesos más gruesos, los recortamos a Bold.
    public static func font(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        if fredokaAvailable { return .custom("Fredoka", size: size).weight(capWeight(weight)) }
        return .system(size: size, weight: weight, design: .rounded)
    }
    /// Recorta pesos por encima de 700 (Bold) para Fredoka, que no tiene glifos más gruesos.
    private static func capWeight(_ w: Font.Weight) -> Font.Weight {
        switch w { case .heavy, .black: return .bold; default: return w }
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
    /// Esquina de las tarjetas de papel «Pizarra» (poco redondeada: 4–6).
    public static let cornerRadius: CGFloat = 5
}

// MARK: - Colores de categoría

extension GameCategory {
    /// Color principal «Pizarra» (paleta del icono). Texto blanco encima pasa AA (salvo amarillo/tinta, que usan tinta/blanco).
    /// El icono solo tiene 4 tonos fuertes + tinta: «conocerse» usa la tinta a propósito; «biblia» reutiliza el oro (tono cálido).
    public var color: Color {
        switch self {
        case .energia: return Color(hex: 0xF2A900)
        case .mente: return Color(hex: 0x6D3FD0)
        case .equipo: return Color(hex: 0x15803D)
        case .expresion: return Color(hex: 0xBE185D)
        case .conocerse: return Color(hex: 0x1F1D2B)
        case .biblia: return Color(hex: 0xF2A900)
        }
    }
    /// Tinte claro de fondo (papel teñido para el chip del icono), derivado del tono de la categoría.
    public var tint: Color {
        switch self {
        case .energia: return Color(hex: 0xFDEBC2)
        case .mente: return Color(hex: 0xE7DEFA)
        case .equipo: return Color(hex: 0xD6F0DF)
        case .expresion: return Color(hex: 0xF7D9E6)
        case .conocerse: return Color(hex: 0xE6E4EA)
        case .biblia: return Color(hex: 0xFDEBC2)
        }
    }
    /// Variante clara para fondos oscuros (modo juego sobre plantilla oscura).
    public var onDark: Color {
        switch self {
        case .energia: return Color(hex: 0xFFC94D)
        case .mente: return Color(hex: 0xA78BFA)
        case .equipo: return Color(hex: 0x34D399)
        case .expresion: return Color(hex: 0xF472B6)
        case .conocerse: return Color(hex: 0xC9C6D2)
        case .biblia: return Color(hex: 0xFFC94D)
        }
    }
    /// Tinte del chip del icono. Fijo (el tablero «Pizarra» no se invierte en modo oscuro).
    public var adaptiveTint: Color { tint }

    /// Color de texto legible sobre el relleno `color`: tinta sobre el oro, blanco sobre el resto.
    public var onColor: Color {
        switch self {
        case .energia, .biblia: return Theme.onAccent
        default: return .white
        }
    }

    /// true si el relleno `color` es claro (oro): el texto encima debe ir en tinta, no en blanco.
    public var isLightFill: Bool {
        switch self { case .energia, .biblia: return true; default: return false }
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

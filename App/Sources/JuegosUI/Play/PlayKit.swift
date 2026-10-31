import SwiftUI
import JuegosCore

// MARK: - Paleta de la plantilla

/// Colores derivados del fondo de la plantilla. Las tres vistas (Palabra, Reloj, Tarjeta) los leen del entorno.
struct PlayPalette {
    var bg: Color = Theme.darkBackground
    var fg: Color = .white
    var fg2: Color = .white.opacity(0.7)
    var panel: Color = Color.black.opacity(0.22)
    var line: Color = .white.opacity(0.6)
    var primary: Color = Theme.inkFixed      // botón principal
    var onPrimary: Color = .white
    var accent: Color = .white               // color de categoría legible sobre este fondo
    var cardAccent: Color = Theme.inkFixed   // texto 中文 sobre tarjeta blanca
    var isLight = false
    var isColored = false                    // fondo de color (categoría / tarjeta / personalizado medio)
    /// Fondo del recuadro donde se muestran herramientas «de pestaña» (texto blanco).
    var toolBox: Color { isLight ? Theme.darkBackground : (isColored ? Color.black.opacity(0.25) : Theme.darkSurface) }

    static func make(template: PlayTemplate, category: GameCategory, flash: Color? = nil, cardAccent: Color? = nil) -> PlayPalette {
        var p = PlayPalette()
        let bgColor = template.background.color(category: category, flash: flash)
        p.bg = bgColor
        p.cardAccent = cardAccent ?? category.color
        var mode: Int   // 0 coloreado, 1 oscuro, 2 claro
        switch template.background {
        case .category: mode = 0
        case .dark: mode = 1
        case .light: mode = 2
        case .custom(let hex):
            let lum = luminance(hex)
            mode = lum < 0.18 ? 1 : (lum > 0.6 ? 2 : 0)
        }
        switch mode {
        case 0:
            p.isColored = true
            p.accent = bgColor
        case 1:
            p.fg = Color(hex: 0xF2F1F7); p.fg2 = Color(hex: 0xA09FB0)
            p.panel = Theme.darkSurface; p.line = Theme.darkBorder
            p.primary = Color(hex: 0xF2F1F7); p.onPrimary = Color(hex: 0x0B0B0F)
            p.accent = category.onDark
        default:
            p.isLight = true
            p.fg = Theme.inkFixed; p.fg2 = Theme.secondaryFixed
            p.panel = Color(hex: 0xF5F3EE); p.line = Color(hex: 0xDAD5C9)
            p.primary = Theme.inkFixed; p.onPrimary = .white
            p.accent = category.color
        }
        return p
    }

    private static func luminance(_ hex: String) -> Double {
        var s = hex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return 0.3 }
        let r = Double((v >> 16) & 0xFF) / 255, g = Double((v >> 8) & 0xFF) / 255, b = Double(v & 0xFF) / 255
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }
}

private struct PlayPaletteKey: EnvironmentKey { static let defaultValue = PlayPalette() }
extension EnvironmentValues {
    var playPalette: PlayPalette {
        get { self[PlayPaletteKey.self] }
        set { self[PlayPaletteKey.self] = newValue }
    }
}

/// Colores de las tarjetas de color (fondo del escenario / muestra de la leyenda / texto sobre blanco).
enum FlashPalette {
    static func stage(_ n: String?) -> Color? {
        switch n {
        case "red": return Color(hex: 0xC92A2A)
        case "yellow": return Color(hex: 0xA16207)
        case "blue": return Color(hex: 0x1D4ED8)
        case "green": return Color(hex: 0x15803D)
        case "purple": return Color(hex: 0x6D3FD0)
        case "orange": return Color(hex: 0xC2410C)
        default: return nil
        }
    }
    static func swatch(_ n: String?) -> Color {
        switch n {
        case "yellow": return Color(hex: 0xF0B90B)
        case "red": return Color(hex: 0xC92A2A)
        case "blue": return Color(hex: 0x1D4ED8)
        default: return Color.flash(n)
        }
    }
    static func text(_ n: String?) -> Color? {
        switch n {
        case "red": return Color(hex: 0x9B1C1C)
        case "yellow": return Color(hex: 0x854D0E)
        case "blue": return Color(hex: 0x1E3A8A)
        case "green": return Color(hex: 0x166534)
        case "purple": return Color(hex: 0x5B21B6)
        case "orange": return Color(hex: 0x9A3412)
        default: return nil
        }
    }
}

// MARK: - Botones

struct PlayButtonStyle: ButtonStyle {
    enum Kind { case solid(Color, Color), outline(Color), tint(Color, Color) }
    var kind: Kind
    var big = false
    var capsule = true
    var radius: CGFloat = 14
    @Environment(\.isEnabled) private var enabled

    func makeBody(configuration: Configuration) -> some View {
        let h: CGFloat = big ? 56 : 46
        let label = configuration.label
            .font(Theme.font(big ? 19 : 15, .semibold)).lineLimit(1)
            .padding(.horizontal, big ? 26 : 18)
            .frame(minWidth: Theme.minTap, minHeight: h)
        Group {
            switch kind {
            case .solid(let bg, let fg):
                label.foregroundStyle(fg).background(shape.fill(bg))
            case .outline(let c):
                label.foregroundStyle(c).background(shape.strokeBorder(c.opacity(0.7), lineWidth: 2))
            case .tint(let bg, let fg):
                label.foregroundStyle(fg).background(shape.fill(bg))
            }
        }
        .contentShape(Rectangle())
        .opacity(enabled ? (configuration.isPressed ? 0.75 : 1) : 0.4)
        .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }

    private var shape: AnyInsettableShape { capsule ? AnyInsettableShape(Capsule()) : AnyInsettableShape(RoundedRectangle(cornerRadius: radius)) }
}

struct AnyInsettableShape: InsettableShape {
    private let pathFn: @Sendable (CGRect) -> Path
    private let insetFn: @Sendable (CGFloat) -> AnyInsettableShape
    init<S: InsettableShape>(_ s: S) {
        pathFn = { s.path(in: $0) }
        insetFn = { AnyInsettableShape(s.inset(by: $0)) }
    }
    func path(in rect: CGRect) -> Path { pathFn(rect) }
    func inset(by amount: CGFloat) -> AnyInsettableShape { insetFn(amount) }
}

extension PlayPalette {
    func solid(big: Bool = false) -> PlayButtonStyle {
        PlayButtonStyle(kind: .solid(primary, onPrimary), big: big, capsule: isColored)
    }
    func outline(big: Bool = false) -> PlayButtonStyle {
        PlayButtonStyle(kind: .outline(isColored ? .white : fg), big: big, capsule: isColored)
    }
    func tint(big: Bool = false) -> PlayButtonStyle {
        PlayButtonStyle(kind: .tint(panel, fg), big: big, capsule: isColored)
    }
    func accentSolid(big: Bool = false) -> PlayButtonStyle {
        PlayButtonStyle(kind: .solid(isColored ? .white : accent, isColored ? bg : (isLight ? .white : onPrimary)), big: big, capsule: isColored)
    }
}

// MARK: - Texto bilingüe grande (respeta el selector de idioma y bilingualColumns)

struct BiBlock: View {
    @Environment(AppModel.self) private var model
    let l: L
    var esSize: CGFloat
    var zhSize: CGFloat? = nil
    var esColor: Color
    var zhColor: Color
    var columns = false
    var center = true
    var esWeight: Font.Weight = .bold
    var zhWeight: Font.Weight = .heavy
    var lineLimit: Int? = 2
    var minScale: CGFloat = 0.3

    private var zhS: CGFloat { zhSize ?? esSize * 0.64 }
    private var align: HorizontalAlignment { center ? .center : .leading }
    private var talign: TextAlignment { center ? .center : .leading }

    private func es() -> some View {
        Text(l.es.isEmpty ? l.zh : l.es).font(Theme.font(esSize, esWeight)).foregroundStyle(esColor)
            .multilineTextAlignment(talign).lineLimit(lineLimit).minimumScaleFactor(minScale)
    }
    private func zh(_ size: CGFloat) -> some View {
        Text(l.zh.isEmpty ? l.es : l.zh).font(Theme.fontZH(size, zhWeight)).foregroundStyle(zhColor)
            .multilineTextAlignment(talign).lineLimit(lineLimit).minimumScaleFactor(minScale)
    }

    var body: some View {
        switch model.language {
        case .es: es()
        case .zh: zh(max(zhS, esSize * 0.9))
        case .both:
            if l.es.isEmpty || l.zh.isEmpty || l.es == l.zh { es() }
            else if columns {
                HStack(alignment: .top, spacing: esSize * 0.9) {
                    es().frame(maxWidth: .infinity, alignment: center ? .center : .leading)
                    Rectangle().fill(zhColor.opacity(0.3)).frame(width: 1)
                    zh(zhS).frame(maxWidth: .infinity, alignment: center ? .center : .leading)
                }
                .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(alignment: align, spacing: esSize * 0.04) { es(); zh(zhS) }
            }
        }
    }
}

/// Texto de UI corto: «ES · 中文» según el idioma.
struct LT: View {
    @Environment(AppModel.self) private var model
    let l: L
    init(_ l: L) { self.l = l }
    init(_ es: String, _ zh: String) { self.l = L(es, zh) }
    var body: some View { Text(model.t(l.es, l.zh)) }
}

func timeOfDay(_ d: Date) -> String {
    let f = DateFormatter(); f.dateFormat = "HH:mm"; return f.string(from: d)
}

// MARK: - Herramienta de pestaña dentro de un recuadro (texto blanco)

struct ToolBox: View {
    @Environment(\.playPalette) private var pal
    let index: Int
    var presenting: Bool
    var body: some View {
        ToolBody(index: index, presenting: presenting)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(RoundedRectangle(cornerRadius: 28).fill(pal.toolBox))
            .environment(\.colorScheme, .dark)
    }
}

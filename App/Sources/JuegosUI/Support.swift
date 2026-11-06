import SwiftUI
import AVFoundation
import JuegosCore
#if os(macOS)
import AppKit
#else
import AudioToolbox
import UIKit
#endif

// MARK: - Estilo

// GameCategory.color / .tint / .onDark → Theme.swift

extension ToolKind {
    public var label: L {
        switch self {
        case .timer: return L("Temporizador", "计时器")
        case .stopwatch: return L("Cronómetro", "秒表")
        case .scoreboard: return L("Marcador", "计分板")
        case .deck: return L("Mazo", "卡牌")
        case .generator: return L("Generador", "随机")
        case .reference: return L("Referencia", "参考")
        case .boom: return L("¡Boom!", "Boom!")
        case .caller: return L("Llamador", "口令")
        case .colorFlash: return L("Color", "颜色")
        case .identity: return L("Identidades", "身份")
        case .codeSequence: return L("Código", "密码")
        case .map: return L("Mapa", "地图")
        }
    }
    public var symbol: String {
        switch self {
        case .timer: return "timer"
        case .stopwatch: return "stopwatch"
        case .scoreboard: return "list.number"
        case .deck: return "rectangle.stack"
        case .generator: return "dice"
        case .reference: return "tablecells"
        case .boom: return "burst"
        case .caller: return "megaphone"
        case .colorFlash: return "paintpalette"
        case .identity: return "person.crop.rectangle.stack"
        case .codeSequence: return "hand.tap"
        case .map: return "map"
        }
    }
}

extension Color {
    static func flash(_ name: String?) -> Color {
        switch name {
        case "red": return Color(red: 0.90, green: 0.18, blue: 0.20)
        case "yellow": return Color(red: 0.98, green: 0.80, blue: 0.10)
        case "blue": return Color(red: 0.12, green: 0.45, blue: 0.95)
        case "green": return Color(red: 0.12, green: 0.70, blue: 0.35)
        case "purple": return Color(red: 0.55, green: 0.30, blue: 0.85)
        case "orange": return Color(red: 0.98, green: 0.55, blue: 0.10)
        default: return Color.gray
        }
    }
}

func bigFont(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
    Theme.font(size, weight)
}

// MARK: - Texto bilingüe

public struct BiText: View {
    @Environment(AppModel.self) private var model
    let l: L
    var size: CGFloat
    var weight: Font.Weight
    var align: HorizontalAlignment
    var secondaryOpacity: Double

    public init(_ l: L, size: CGFloat = 15, weight: Font.Weight = .regular,
                align: HorizontalAlignment = .leading, secondaryOpacity: Double = 0.6) {
        self.l = l; self.size = size; self.weight = weight; self.align = align
        self.secondaryOpacity = secondaryOpacity
    }

    private var textAlign: TextAlignment {
        switch align { case .center: return .center; case .trailing: return .trailing; default: return .leading }
    }

    public var body: some View {
        switch model.language {
        case .es: Text(l.text(.es)).font(Theme.font(size, weight)).multilineTextAlignment(textAlign)
        case .zh: Text(l.text(.zh)).font(Theme.fontZH(size, weight)).multilineTextAlignment(textAlign)
        case .both:
            VStack(alignment: align, spacing: max(1, size * 0.08)) {
                Text(l.es.isEmpty ? l.zh : l.es).font(l.es.isEmpty ? Theme.fontZH(size, weight) : Theme.font(size, weight))
                if !l.es.isEmpty, !l.zh.isEmpty, l.zh != l.es {
                    Text(l.zh).font(Theme.fontZH(size * 0.8, weight == .regular ? .regular : .medium)).opacity(secondaryOpacity)
                }
            }
            .multilineTextAlignment(textAlign)
        }
    }
}

/// Texto de UI bilingüe corto (para etiquetas).
struct T: View {
    @Environment(AppModel.self) private var model
    let es: String; let zh: String
    init(_ es: String, _ zh: String) { self.es = es; self.zh = zh }
    var body: some View { Text(model.t(es, zh)) }
}

extension Theme {
    /// Verde de «Quedan X min» (= categoría Equipo).
    static let ok = GameCategory.equipo.color
    /// Aviso de «te pasas X min»: ámbar del icono (evitamos el rojo, fuera de la paleta Pizarra).
    static let danger = Color(hex: 0xF2A900)
    static let fieldBorder = Theme.border
    /// Chip/segmento neutro: papel cálido.
    static let chipNeutral = Theme.paper
}

/// Color de texto de una categoría sobre su tinte (papel teñido): tinta sobre el oro, el tono de la categoría en el resto.
func categoryInk(_ c: GameCategory, _ scheme: ColorScheme) -> Color {
    switch c { case .energia, .biblia: return Theme.ink; default: return c.color }
}

struct PillButtonStyle: ButtonStyle {
    var color: Color = Theme.accentPlanificar
    var big: Bool = false
    var filled: Bool = true
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(bigFont(big ? 26 : 15, .semibold)).lineLimit(1).fixedSize(horizontal: true, vertical: false)
            .foregroundStyle(filled ? Color.white : color)
            .padding(.horizontal, big ? 28 : 14)
            .padding(.vertical, big ? 16 : 8)
            .frame(minHeight: Theme.minTap)
            .background(
                Capsule().fill(filled ? color : color.opacity(0.18))
            )
            .opacity(enabled ? (configuration.isPressed ? 0.75 : 1) : 0.4)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}

// MARK: - Estilo «Pizarra» (tarjetas de papel, cinta washi, líneas discontinuas, wordmark)

extension Int {
    /// Rotación «nota pegada» alterna (±0.2–0.4°) según la posición de la tarjeta.
    var pizarraTilt: Double { [-0.4, 0.3, -0.2, 0.4, -0.3][((self % 5) + 5) % 5] }
}

extension View {
    /// Tarjeta de papel: esquina poco redondeada + sombra DURA desplazada (radio 0) + leve rotación.
    /// La sombra va SOLO en la forma del fondo (si se aplicara al contenedor, el texto proyectaría su propia sombra).
    func pizarraCard(radius: CGFloat = Theme.cornerRadius,
                     tilt: Double = 0,
                     fill: Color = Theme.surface,
                     shadow: Color = Theme.cardShadow,
                     dx: CGFloat = 2, dy: CGFloat = 3) -> some View {
        self.background(
            RoundedRectangle(cornerRadius: radius).fill(fill)
                .shadow(color: shadow, radius: 0, x: dx, y: dy)
        )
        .rotationEffect(.degrees(tilt))
    }

    /// Línea discontinua blanca en el borde indicado (separa columnas del tablero).
    func boardDivider(_ edge: HorizontalEdge) -> some View {
        overlay(alignment: edge == .leading ? .leading : .trailing) {
            VLine().stroke(Theme.boardLine, style: StrokeStyle(lineWidth: 1, dash: [6, 4])).frame(width: 1)
        }
    }
}

/// Línea vertical (para dibujarla discontinua).
struct VLine: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path(); p.move(to: CGPoint(x: r.midX, y: r.minY)); p.addLine(to: CGPoint(x: r.midX, y: r.maxY)); return p
    }
}

/// Cinta «washi»: rectángulo del color de la categoría, girado unos grados, arriba a la izquierda de una tarjeta.
struct WashiTape: View {
    var color: Color
    var rotation: Double = -4
    var body: some View {
        Rectangle().fill(color)
            .frame(width: 44, height: 14)
            .rotationEffect(.degrees(rotation))
            .shadow(color: Theme.cardShadow.opacity(0.45), radius: 0, x: 1, y: 1)
    }
}

/// Wordmark de la cabecera: «¡Juguemos!» (amarillo) + «玩» (blanco).
struct Wordmark: View {
    var size: CGFloat = 30
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("¡Juguemos!").font(Theme.font(size, .bold)).foregroundStyle(Theme.accent)
            Text("玩").font(Theme.fontZH(size * 0.72, .black)).foregroundStyle(Theme.onBoard)
        }
        .accessibilityElement().accessibilityLabel("¡Juguemos!")
    }
}

// MARK: - Sonido y voz

enum Sound {
    static func ding() {
        #if os(macOS)
        NSSound(named: "Glass")?.play()
        #else
        AudioServicesPlaySystemSound(1005)
        #endif
    }
}

@MainActor
final class Speaker {
    static let shared = Speaker()
    private let synth = AVSpeechSynthesizer()
    func say(_ l: L, mode: LanguageMode) {
        let zh = mode == .zh
        let text = zh ? (l.zh.isEmpty ? l.es : l.zh) : (l.es.isEmpty ? l.zh : l.es)
        guard !text.isEmpty else { return }
        synth.stopSpeaking(at: .immediate)
        let u = AVSpeechUtterance(string: text)
        u.voice = AVSpeechSynthesisVoice(language: zh ? "zh-CN" : "es-ES")
        synth.speak(u)
    }
    func stop() { synth.stopSpeaking(at: .immediate) }
}

func formatTime(_ t: Double, tenths: Bool = false) -> String {
    let v = max(0, t)
    let total = Int(v)
    let m = total / 60, s = total % 60
    if tenths { return String(format: "%02d:%02d.%d", m, s, Int((v - Double(total)) * 10)) }
    return String(format: "%02d:%02d", m, s)
}

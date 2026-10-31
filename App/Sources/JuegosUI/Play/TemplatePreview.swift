import SwiftUI
import JuegosCore

/// Previsualización de una plantilla con un juego: render del modo proyector (presenting: true)
/// con su propio PlayController, a 1280×800 escalado para caber en el espacio disponible.
public struct TemplatePreview: View {
    let game: Game
    let template: PlayTemplate
    @State private var controller = PlayController()

    public init(game: Game, template: PlayTemplate) { self.game = game; self.template = template }

    private static let canvas = CGSize(width: 1280, height: 800)

    /// Juego con las herramientas que la plantilla necesita y que le faltan (solo para la vista previa).
    private var previewGame: Game {
        var g = game
        for k in template.requiredTools where !g.tools.contains(where: { $0.kind == k }) {
            g.tools.append(Self.sampleSpec(k))
        }
        return g
    }

    private static func sampleSpec(_ k: ToolKind) -> ToolSpec {
        let sample = [CardGroup(name: L("Ejemplos", "示例"), cards: [
            Card(front: L("Ejemplo uno", "示例一"), back: L("Respuesta de ejemplo", "示例答案")),
            Card(front: L("Ejemplo dos", "示例二"), back: L("Otra respuesta", "另一个答案")),
            Card(front: L("Ejemplo tres", "示例三"), back: L("Una más", "再来一个"))])]
        switch k {
        case .scoreboard: return ToolSpec(kind: k, teams: 2)
        case .timer: return ToolSpec(kind: k, seconds: 300)
        case .boom: return ToolSpec(kind: k, multiple: 7)
        case .codeSequence: return ToolSpec(kind: k, length: 4)
        case .colorFlash:
            let cards = [("red", "Rojo", "红色", "Cantarlo", "唱出来"), ("yellow", "Amarillo", "黄色", "Otro idioma", "用外语"),
                         ("blue", "Azul", "蓝色", "Solo mímica", "只用动作")].map {
                Card(front: L($0.1, $0.2), back: L($0.3, $0.4), color: $0.0)
            }
            return ToolSpec(kind: k, groups: [CardGroup(name: L("Reglas", "规则"), cards: cards)])
        case .deck, .generator, .caller, .identity, .reference: return ToolSpec(kind: k, groups: sample)
        case .stopwatch: return ToolSpec(kind: k)
        }
    }

    public var body: some View {
        let game = previewGame
        GeometryReader { geo in
            let scale = max(0.05, min(geo.size.width / Self.canvas.width, geo.size.height / Self.canvas.height))
            ZStack {
                if controller.game?.id == self.game.id {
                    PlayScene(game: game, template: template, fullscreen: false) {
                        VStack(spacing: 0) {
                            PlayHeader(game: game, template: template, presenting: true)
                            TemplateBody(game: game, template: template, presenting: true).padding(.bottom, 12)
                        }
                    }
                }
            }
            .environment(controller)
            .frame(width: Self.canvas.width, height: Self.canvas.height)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.gray.opacity(0.5), lineWidth: 3))
            .scaleEffect(scale, anchor: .center)
            .frame(width: geo.size.width, height: geo.size.height)
            .allowsHitTesting(false)
        }
        .onAppear { if controller.game?.id != self.game.id { controller.play(previewGame) } }
        .onChange(of: previewGame) { _, g in controller.play(g) }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityLabel("Vista previa de la plantilla \(template.name.es)")
    }
}

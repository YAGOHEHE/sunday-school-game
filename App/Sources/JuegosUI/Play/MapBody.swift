import SwiftUI
import Observation
import JuegosCore
#if os(macOS)
import AppKit
#else
import UIKit
#endif

// MARK: - Estado del juego del mapa

struct RoundResult: Equatable { var winner: Int?; var dA: CGFloat; var dB: CGFloat }

/// Estado del juego «Mapa»: lista de lugares con posición, puntos de los jugadores y puntuación.
/// Lo comparten la ventana de control y el proyector (mismo almacén en PlayController).
@MainActor @Observable
final class MapState: ToolState {
    /// Proporción ancho/alto por defecto (pergamino dibujado en Canvas) cuando no hay lámina de imagen.
    static let defaultAspect: CGFloat = 0.80

    /// Lámina de imagen opcional; si es nil se dibuja el pergamino en Canvas.
    let plate: MapPlate?
    /// Proporción ancho/alto de la lámina en uso; sale de la plate (por defecto 0.80). La distancia y el encaje la usan.
    let aspect: CGFloat

    let places: [Card]
    private var order: [Int] = []
    private var pos = 0

    var index = -1
    var marks: [CGPoint] = []      // posiciones normalizadas (0…1) sobre la lámina
    var activePlayer = 0
    var revealed = false
    var scores = [0, 0]
    var result: RoundResult?

    init(groups: [CardGroup], plate: MapPlate? = nil) {
        self.plate = plate
        self.aspect = plate.map { CGFloat($0.aspect) } ?? Self.defaultAspect
        places = groups.flatMap(\.cards).filter { $0.x != nil && $0.y != nil }
        order = Array(places.indices).shuffled()
    }

    var hasPlaces: Bool { !places.isEmpty }
    var current: Card? { places.indices.contains(index) ? places[index] : nil }
    var target: CGPoint? {
        guard let c = current, let x = c.x, let y = c.y else { return nil }
        return CGPoint(x: x, y: y)
    }
    var remaining: Int { max(0, order.count - pos) }

    func startIfNeeded() { if index == -1 { nextPlace() } }

    func nextPlace() {
        marks = []; activePlayer = 0; revealed = false; result = nil
        guard !order.isEmpty else { return }
        if pos >= order.count { order.shuffle(); pos = 0 }
        index = order[pos]; pos += 1
    }

    func place(at p: CGPoint) {
        guard !revealed, index != -1 else { return }
        let q = CGPoint(x: min(1, max(0, p.x)), y: min(1, max(0, p.y)))
        while marks.count <= activePlayer { marks.append(q) }
        marks[activePlayer] = q
        activePlayer = marks.count < 2 ? marks.count : (activePlayer == 0 ? 1 : 0)
    }

    func setActive(_ i: Int) { activePlayer = max(0, min(1, i)) }
    func clear() { marks = []; activePlayer = 0; revealed = false; result = nil }

    func reveal() {
        guard index != -1, let t = target, !revealed else { return }
        revealed = true
        guard marks.count >= 2 else { result = nil; return }
        let dA = dist(marks[0], t), dB = dist(marks[1], t)
        let eps: CGFloat = 0.012
        if abs(dA - dB) < eps { scores[0] += 1; scores[1] += 1; result = RoundResult(winner: nil, dA: dA, dB: dB) }
        else if dA < dB { scores[0] += 1; result = RoundResult(winner: 0, dA: dA, dB: dB) }
        else { scores[1] += 1; result = RoundResult(winner: 1, dA: dA, dB: dB) }
    }

    func resetScores() { scores = [0, 0] }

    private func dist(_ p: CGPoint, _ q: CGPoint) -> CGFloat {
        let dx = (p.x - q.x) * aspect, dy = p.y - q.y
        return sqrt(dx * dx + dy * dy)
    }

    func primary() {
        if index == -1 { nextPlace() }
        else if !revealed { reveal() }
        else { nextPlace() }
    }
}

// MARK: - Paleta del mapa

private enum Parch {
    static let mat = Color(hex: 0x241F17)      // mantel oscuro en las bandas del letterbox
    static let paper1 = Color(hex: 0xECDDBA)   // placeholder y carteles
    static let edge = Color(hex: 0xB89A60)
    static let ink = Color(hex: 0x5A4A2E)
    static let inkSoft = Color(hex: 0x806F4C)
    static let gold = Color(hex: 0xC6891A)
    static let a = Color(hex: 0x11786F)    // jugador 1 (verde azulado)
    static let b = Color(hex: 0xB23A48)    // jugador 2 (granate)
}

// MARK: - Vista del juego del mapa

struct MapGameView: View {
    @Environment(AppModel.self) private var model
    var state: MapState
    var presenting: Bool

    var body: some View {
        VStack(spacing: presenting ? 10 : 12) {
            banner
            GeometryReader { geo in
                let rect = plate(in: geo.size)
                ZStack {
                    Parch.mat   // mantel oscuro en las bandas del letterbox
                    // Lámina de imagen (la imagen ya trae borde y decoración); sin plate, un marco neutro.
                    if let plate = state.plate {
                        plateImage(plate, rect: rect)
                    } else {
                        placeholderPlate(rect: rect)
                    }
                    Canvas { ctx, _ in drawOverlay(&ctx, rect: rect) }
                        .allowsHitTesting(false)
                    ForEach(Array(state.marks.indices), id: \.self) { i in
                        MapPin(number: i + 1, color: i == 0 ? Parch.a : Parch.b,
                               winner: state.revealed && state.result?.winner == i)
                            .position(P(state.marks[i], rect))
                            .allowsHitTesting(false)
                    }
                    if state.revealed, let t = state.target {
                        StarMark().position(P(t, rect)).allowsHitTesting(false)
                    }
                }
                .contentShape(Rectangle())
                .gesture(SpatialTapGesture().onEnded { v in
                    guard !presenting else { return }
                    let n = norm(v.location, rect)
                    guard n.x > -0.03, n.x < 1.03, n.y > -0.03, n.y < 1.03 else { return }
                    withAnimation(.spring(duration: 0.25)) { state.place(at: n) }
                })
            }
            if state.revealed { resultCartouche }
            if !presenting { controls }
        }
        .onAppear { if !presenting { state.startIfNeeded() } }
    }

    // MARK: Cabecera y pie

    private var banner: some View {
        HStack(spacing: 14) {
            Image(systemName: "mappin.and.ellipse").font(.system(size: presenting ? 30 : 24, weight: .bold))
                .foregroundStyle(Parch.b)
            VStack(alignment: .leading, spacing: 2) {
                Text(model.t(state.revealed ? "Estaba aquí" : "Coloca este lugar",
                             state.revealed ? "正确位置在这里" : "找出这个地点"))
                    .font(Theme.font(presenting ? 18 : 15, .semibold)).foregroundStyle(Parch.inkSoft)
                if let c = state.current {
                    BiText(c.front, size: presenting ? 40 : 30, weight: .heavy, align: .leading)
                        .foregroundStyle(Parch.ink)
                } else {
                    Text(model.t("Pulsa «Empezar»", "点击“开始”")).font(Theme.font(presenting ? 34 : 26, .heavy))
                        .foregroundStyle(Parch.ink)
                }
            }
            Spacer(minLength: 8)
            scoreChip(0); scoreChip(1)
        }
        .padding(.horizontal, 10)
    }

    private func scoreChip(_ i: Int) -> some View {
        let c = i == 0 ? Parch.a : Parch.b
        let active = !state.revealed && state.activePlayer == i && !presenting
        return VStack(spacing: 1) {
            Text(model.t("Jugador \(i + 1)", "玩家 \(i + 1)")).font(Theme.font(12, .semibold)).foregroundStyle(.white.opacity(0.9))
            Text("\(state.scores[i])").font(Theme.font(presenting ? 30 : 24, .heavy)).monospacedDigit().foregroundStyle(.white)
        }
        .frame(minWidth: 72).padding(.vertical, 6).padding(.horizontal, 10)
        .background(RoundedRectangle(cornerRadius: 14).fill(c))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white, lineWidth: active ? 3 : 0))
        .shadow(color: active ? c.opacity(0.6) : .clear, radius: 6)
    }

    private var resultCartouche: some View {
        HStack(spacing: 12) {
            Image(systemName: "star.fill").foregroundStyle(Parch.gold)
            VStack(alignment: .leading, spacing: 2) {
                if let r = state.result {
                    Text(r.winner == nil ? model.t("¡Empate! Punto para los dos", "平手！两人各得一分")
                                         : model.t("Gana el Jugador \(r.winner! + 1)", "玩家 \(r.winner! + 1) 获胜"))
                        .font(Theme.font(presenting ? 20 : 17, .bold))
                        .foregroundStyle(r.winner == nil ? Parch.ink : (r.winner == 0 ? Parch.a : Parch.b))
                }
                if let b = state.current?.back {
                    BiText(b, size: presenting ? 16 : 14, weight: .regular, align: .leading).foregroundStyle(Parch.inkSoft)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 16).fill(Parch.paper1))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Parch.edge, lineWidth: 1.5))
        .padding(.horizontal, 10)
    }

    private var controls: some View {
        HStack(spacing: 10) {
            playerButton(0); playerButton(1)
            Spacer(minLength: 0)
            mapButton(state.revealed ? L("Siguiente lugar", "下一个") : L("Revelar", "揭晓"),
                      system: state.revealed ? "arrow.right" : "eye",
                      filled: true, disabled: !state.revealed && state.marks.isEmpty) {
                if state.revealed { withAnimation { state.nextPlace() } } else { withAnimation { state.reveal() } }
            }
            mapButton(L("Borrar", "清除"), system: "arrow.uturn.backward", filled: false,
                      disabled: state.marks.isEmpty || state.revealed) { withAnimation { state.clear() } }
            Menu {
                Button { withAnimation { state.resetScores() } } label: { Label("Puntos a cero · 分数清零", systemImage: "arrow.counterclockwise") }
            } label: { Image(systemName: "ellipsis.circle").font(.system(size: 22)) }
                .menuStyle(.borderlessButton).fixedSize().tint(Parch.ink)
                .accessibilityLabel(Text("Opciones del mapa"))
        }
        .padding(.horizontal, 10)
    }

    private func playerButton(_ i: Int) -> some View {
        let c = i == 0 ? Parch.a : Parch.b
        let active = state.activePlayer == i && !state.revealed
        return Button { state.setActive(i) } label: {
            HStack(spacing: 6) {
                ZStack { Circle().fill(.white.opacity(0.9)).frame(width: 18, height: 18); Text("\(i + 1)").font(Theme.font(12, .heavy)).foregroundStyle(c) }
                Text(model.t("Jugador \(i + 1)", "玩家 \(i + 1)")).font(Theme.font(14, .semibold))
            }
            .foregroundStyle(active ? .white : c)
            .padding(.vertical, 9).padding(.horizontal, 12)
            .background(Capsule().fill(active ? c : c.opacity(0.14)))
            .overlay(Capsule().strokeBorder(c.opacity(active ? 0 : 0.5), lineWidth: 1.5))
        }
        .buttonStyle(.plain).disabled(state.revealed)
        .accessibilityLabel(Text("Turno del jugador \(i + 1)"))
    }

    private func mapButton(_ l: L, system: String, filled: Bool, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) { Image(systemName: system); LT(l) }
                .font(Theme.font(15, .semibold))
                .foregroundStyle(filled ? .white : Parch.ink)
                .padding(.vertical, 10).padding(.horizontal, 16)
                .background(Capsule().fill(filled ? Parch.ink : Parch.paper1))
                .overlay(Capsule().strokeBorder(Parch.edge, lineWidth: filled ? 0 : 1.5))
        }
        .buttonStyle(.plain).disabled(disabled).opacity(disabled ? 0.45 : 1)
    }

    // MARK: Geometría

    private func plate(in size: CGSize) -> CGRect {
        let a = state.aspect
        var w = size.width, h = size.height
        if w / h > a { w = h * a } else { h = w / a }
        w *= 0.995; h *= 0.995
        return CGRect(x: (size.width - w) / 2, y: (size.height - h) / 2, width: w, height: h)
    }
    private func P(_ n: CGPoint, _ r: CGRect) -> CGPoint { CGPoint(x: r.minX + n.x * r.width, y: r.minY + n.y * r.height) }
    private func norm(_ p: CGPoint, _ r: CGRect) -> CGPoint {
        CGPoint(x: (p.x - r.minX) / max(1, r.width), y: (p.y - r.minY) / max(1, r.height))
    }

    /// Dibuja la lámina de imagen encajada en `rect` con su proporción exacta (sin recortar ni deformar).
    @ViewBuilder
    private func plateImage(_ plate: MapPlate, rect: CGRect) -> some View {
        if let img = MapImageLoader.image(named: plate.image) {
            img.resizable()
                .frame(width: rect.width, height: rect.height)
                .clipShape(RoundedRectangle(cornerRadius: rect.width * 0.012))
                .position(x: rect.midX, y: rect.midY)
                .allowsHitTesting(false)
        } else {
            // Si la imagen no está disponible, un marco neutro (los pines siguen funcionando).
            placeholderPlate(rect: rect)
        }
    }

    /// Marco neutro para un mapa sin lámina de imagen (los pines y la estrella siguen funcionando).
    private func placeholderPlate(rect: CGRect) -> some View {
        RoundedRectangle(cornerRadius: rect.width * 0.012)
            .fill(Parch.paper1)
            .overlay(RoundedRectangle(cornerRadius: rect.width * 0.012).strokeBorder(Parch.edge, lineWidth: 1.5))
            .frame(width: rect.width, height: rect.height)
            .position(x: rect.midX, y: rect.midY)
            .allowsHitTesting(false)
    }
}

// MARK: - Carga de láminas de imagen (Resources/Maps en el bundle de JuegosUI)

enum MapImageLoader {
    @MainActor private static var cache: [String: Image] = [:]

    /// Bundle de recursos de JuegosUI, tanto en `swift run` (Bundle.module) como dentro del .app
    /// (Contents/Resources/JuegosDominical_JuegosUI.bundle). Mismo criterio que Theme.registerBundledFonts.
    private static var uiBundle: Bundle {
        let name = "JuegosDominical_JuegosUI.bundle"
        if let url = Bundle.main.resourceURL?.appendingPathComponent(name), let b = Bundle(url: url) { return b }
        if let b = Bundle(url: Bundle.main.bundleURL.appendingPathComponent(name)) { return b }
        return .module
    }

    @MainActor
    static func image(named name: String) -> Image? {
        if let cached = cache[name] { return cached }
        // El recurso vive en la subcarpeta Maps dentro del bundle.
        let base = (name as NSString).deletingPathExtension
        let ext = (name as NSString).pathExtension
        let url = uiBundle.url(forResource: name, withExtension: nil, subdirectory: "Maps")
            ?? uiBundle.url(forResource: base, withExtension: ext.isEmpty ? nil : ext, subdirectory: "Maps")
            ?? uiBundle.url(forResource: name, withExtension: nil)
        guard let url else { return nil }
        #if os(macOS)
        guard let ns = NSImage(contentsOf: url) else { return nil }
        let img = Image(nsImage: ns)
        #else
        guard let data = try? Data(contentsOf: url), let ui = UIImage(data: data) else { return nil }
        let img = Image(uiImage: ui)
        #endif
        cache[name] = img
        return img
    }
}

// MARK: - Marcadores superpuestos (SwiftUI)

private struct MapPin: View {
    var number: Int
    var color: Color
    var winner: Bool
    var body: some View {
        ZStack {
            Image(systemName: "mappin.circle.fill")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(.white, color)
                .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
            Text("\(number)").font(Theme.font(12, .heavy)).foregroundStyle(color).offset(y: -1)
        }
        .overlay(alignment: .top) {
            if winner { Image(systemName: "crown.fill").font(.system(size: 13)).foregroundStyle(Parch.gold).offset(y: -14) }
        }
        .offset(y: -13)   // la punta cae sobre el punto
    }
}

private struct StarMark: View {
    @State private var pulse = false
    var body: some View {
        Image(systemName: "star.fill")
            .font(.system(size: 26, weight: .black))
            .foregroundStyle(Parch.gold)
            .shadow(color: .black.opacity(0.4), radius: 2)
            .scaleEffect(pulse ? 1.15 : 0.9)
            .onAppear { withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) { pulse = true } }
    }
}

// MARK: - Overlay: líneas punteadas de cada marca al lugar real (al revelar)

private extension MapGameView {
    func drawOverlay(_ ctx: inout GraphicsContext, rect r: CGRect) {
        guard state.revealed, let t = state.target else { return }
        let tp = P(t, r)
        for m in state.marks {
            var line = Path(); line.move(to: P(m, r)); line.addLine(to: tp)
            ctx.stroke(line, with: .color(Parch.ink.opacity(0.55)),
                       style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [5, 5]))
        }
    }
}

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

// MARK: - Paleta del pergamino

private enum Parch {
    static let mat = Color(hex: 0x241F17)
    static let paper1 = Color(hex: 0xECDDBA)
    static let paper2 = Color(hex: 0xDBC594)
    static let edge = Color(hex: 0xB89A60)
    static let ink = Color(hex: 0x5A4A2E)
    static let inkSoft = Color(hex: 0x806F4C)
    static let sea = Color(hex: 0xB3C6C1)
    static let water = Color(hex: 0x86A9C4)
    static let mtnLight = Color(hex: 0xD8C28E)
    static let mtnShade = Color(hex: 0xB3975C)
    static let snow = Color(hex: 0xF3EEDC)
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
                    if let plate = state.plate {
                        // Lámina de imagen: la imagen ya trae borde y decoración; no se dibuja el Canvas del pergamino.
                        Parch.mat   // mantel oscuro en las bandas del letterbox
                        plateImage(plate, rect: rect)
                    } else {
                        Canvas { ctx, _ in drawMap(&ctx, rect: rect) }
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
            RoundedRectangle(cornerRadius: rect.width * 0.012)
                .fill(Parch.paper1)
                .overlay(RoundedRectangle(cornerRadius: rect.width * 0.012).strokeBorder(Parch.edge, lineWidth: 1.5))
                .frame(width: rect.width, height: rect.height)
                .position(x: rect.midX, y: rect.midY)
                .allowsHitTesting(false)
        }
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

// MARK: - Dibujo del pergamino

private extension MapGameView {
    func pt(_ x: Double, _ y: Double, _ r: CGRect) -> CGPoint { CGPoint(x: r.minX + x * r.width, y: r.minY + y * r.height) }

    /// Texto en el lienzo con color aplicado por `shading` (evita cadenas de modificadores sobre Text).
    func label(_ ctx: inout GraphicsContext, _ s: String, _ font: Font, _ color: Color, at p: CGPoint) {
        var t = ctx.resolve(Text(s).font(font)); t.shading = .color(color); ctx.draw(t, at: p)
    }

    func drawOverlay(_ ctx: inout GraphicsContext, rect r: CGRect) {
        guard state.revealed, let t = state.target else { return }
        let tp = P(t, r)
        for m in state.marks {
            var line = Path(); line.move(to: P(m, r)); line.addLine(to: tp)
            ctx.stroke(line, with: .color(Parch.ink.opacity(0.55)),
                       style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [5, 5]))
        }
    }

    func drawMap(_ ctx: inout GraphicsContext, rect r: CGRect) {
        // Mantel oscuro alrededor de la lámina.
        let full = CGRect(x: 0, y: 0, width: r.maxX + r.minX, height: r.maxY + r.minY)
        ctx.fill(Path(full), with: .color(Parch.mat))

        let paper = Path(roundedRect: r, cornerRadius: r.width * 0.02)
        ctx.fill(paper, with: .linearGradient(Gradient(colors: [Parch.paper1, Parch.paper2]),
                                              startPoint: CGPoint(x: r.minX, y: r.minY),
                                              endPoint: CGPoint(x: r.maxX, y: r.maxY)))
        ctx.drawLayer { layer in
            layer.clip(to: paper)
            drawSea(&layer, r)
            drawManchas(&layer, r)
            drawRivers(&layer, r)
            drawMountains(&layer, r)
            drawDecor(&layer, r)
            drawEdgeLabels(&layer, r)
            drawVignette(&layer, r)
        }
        drawFrame(&ctx, r)
        drawCompass(&ctx, r)
        drawTitle(&ctx, r)
    }

    // Línea de costa (de norte a sur); el mar queda a la izquierda (oeste).
    private var coast: [CGPoint] {
        [ (0.64,0.00),(0.60,0.12),(0.54,0.28),(0.52,0.36),(0.49,0.42),(0.45,0.465),(0.42,0.49),
          (0.389,0.551),(0.367,0.582),(0.349,0.598),(0.327,0.620),(0.30,0.70),(0.26,0.82),(0.21,0.94),(0.18,1.0) ]
            .map { CGPoint(x: $0.0, y: $0.1) }
    }

    func drawSea(_ ctx: inout GraphicsContext, _ r: CGRect) {
        var p = Path()
        p.move(to: pt(0, 0, r))
        p.addLine(to: pt(coast[0].x, 0, r))
        for c in coast { p.addLine(to: pt(c.x, c.y, r)) }
        p.addLine(to: pt(0, 1, r)); p.closeSubpath()
        ctx.fill(p, with: .color(Parch.sea))
        // Costa.
        var line = Path(); line.move(to: pt(coast[0].x, coast[0].y, r))
        for c in coast.dropFirst() { line.addLine(to: pt(c.x, c.y, r)) }
        ctx.stroke(line, with: .color(Parch.ink), lineWidth: max(1.2, r.width * 0.004))
        // Olas.
        let waves: [(Double, Double, Double)] = [(0.10,0.12,0.14),(0.08,0.20,0.10),(0.14,0.30,0.12),
                                                 (0.07,0.46,0.10),(0.12,0.58,0.12),(0.08,0.72,0.10),(0.10,0.86,0.12)]
        for (x, y, w) in waves {
            var wv = Path()
            wv.move(to: pt(x, y, r))
            wv.addQuadCurve(to: pt(x + w / 2, y, r), control: pt(x + w / 4, y - 0.014, r))
            wv.addQuadCurve(to: pt(x + w, y, r), control: pt(x + w * 0.75, y + 0.014, r))
            ctx.stroke(wv, with: .color(Parch.ink.opacity(0.3)), lineWidth: 1.2)
        }
        // Barca de vela (sin criaturas).
        drawBoat(&ctx, at: pt(0.19, 0.30, r), s: r.width * 0.05)
    }

    func drawBoat(_ ctx: inout GraphicsContext, at o: CGPoint, s: CGFloat) {
        var hull = Path()
        hull.move(to: CGPoint(x: o.x - s * 0.5, y: o.y))
        hull.addQuadCurve(to: CGPoint(x: o.x + s * 0.5, y: o.y), control: CGPoint(x: o.x, y: o.y + s * 0.45))
        hull.closeSubpath()
        ctx.fill(hull, with: .color(Parch.ink.opacity(0.75)))
        var mast = Path(); mast.move(to: CGPoint(x: o.x, y: o.y)); mast.addLine(to: CGPoint(x: o.x, y: o.y - s * 0.7))
        ctx.stroke(mast, with: .color(Parch.ink), lineWidth: 1.3)
        var sail = Path()
        sail.move(to: CGPoint(x: o.x + 1, y: o.y - s * 0.68)); sail.addLine(to: CGPoint(x: o.x + s * 0.42, y: o.y - s * 0.08))
        sail.addLine(to: CGPoint(x: o.x + 1, y: o.y - s * 0.08)); sail.closeSubpath()
        ctx.fill(sail, with: .color(Parch.paper1.opacity(0.95)))
        ctx.stroke(sail, with: .color(Parch.ink), lineWidth: 1)
    }

    func drawRivers(_ ctx: inout GraphicsContext, _ r: CGRect) {
        // Mar de Galilea y mar Muerto.
        let gal = CGRect(x: pt(0.55, 0.415, r).x, y: pt(0.55, 0.415, r).y,
                         width: r.width * 0.055, height: r.height * 0.06)
        let dead = CGRect(x: pt(0.532, 0.565, r).x, y: pt(0.532, 0.565, r).y,
                          width: r.width * 0.038, height: r.height * 0.11)
        for e in [gal, dead] {
            let el = Path(ellipseIn: e)
            ctx.fill(el, with: .color(Parch.water))
            ctx.stroke(el, with: .color(Parch.ink), lineWidth: 1.2)
        }
        // Río Jordán (Hermón → Galilea → mar Muerto), ondulado.
        func river(_ a: CGPoint, _ b: CGPoint) {
            var p = Path(); p.move(to: a)
            let mid = CGPoint(x: (a.x + b.x) / 2 + r.width * 0.02, y: (a.y + b.y) / 2)
            p.addQuadCurve(to: b, control: mid)
            ctx.stroke(p, with: .color(Parch.water), lineWidth: max(1.6, r.width * 0.006))
            ctx.stroke(p, with: .color(Parch.ink.opacity(0.5)), lineWidth: 0.8)
        }
        river(pt(0.60, 0.37, r), pt(0.576, 0.415, r))
        river(pt(0.576, 0.475, r), pt(0.549, 0.565, r))
    }

    func drawMountains(_ ctx: inout GraphicsContext, _ r: CGRect) {
        // (x, y base, ancho rel, alto rel, nieve)
        let ranges: [(Double, Double, Double, Double, Bool)] = [
            (0.60,0.375,0.085,0.075,true),   // Hermón (nevado)
            (0.455,0.47,0.05,0.04,false),    // Carmelo
            (0.531,0.475,0.045,0.038,false), // Tabor
            (0.475,0.52,0.06,0.05,false),    // sierra central norte
            (0.49,0.565,0.07,0.055,false),   // montes de Judá
            (0.465,0.63,0.055,0.045,false),  // colinas del sur
            (0.615,0.585,0.06,0.05,false),   // meseta de Moab (este)
            (0.215,0.95,0.09,0.075,false),   // Sinaí (sur)
        ]
        for (x, y, w, h, snow) in ranges { drawRange(&ctx, cx: x, base: y, w: w, h: h, snow: snow, r: r) }
    }

    func drawRange(_ ctx: inout GraphicsContext, cx: Double, base: Double, w: Double, h: Double, snow: Bool, r: CGRect) {
        let humps = 3
        for k in 0..<humps {
            let off = (Double(k) - Double(humps - 1) / 2) * w * 0.62
            let scale = k == 1 ? 1.0 : 0.72
            peak(&ctx, apex: pt(cx + off, base - h * scale, r),
                 left: pt(cx + off - w * 0.55 * scale, base, r),
                 right: pt(cx + off + w * 0.55 * scale, base, r), snow: snow && k == 1, r: r)
        }
    }

    func peak(_ ctx: inout GraphicsContext, apex: CGPoint, left: CGPoint, right: CGPoint, snow: Bool, r: CGRect) {
        var tri = Path(); tri.move(to: left); tri.addLine(to: apex); tri.addLine(to: right); tri.closeSubpath()
        ctx.fill(tri, with: .color(Parch.mtnLight))
        var shade = Path(); shade.move(to: apex); shade.addLine(to: right)
        shade.addLine(to: CGPoint(x: (apex.x + right.x) / 2, y: (apex.y + right.y) / 2)); shade.closeSubpath()
        ctx.fill(shade, with: .color(Parch.mtnShade.opacity(0.8)))
        ctx.stroke(tri, with: .color(Parch.ink), lineWidth: 1.2)
        if snow {
            let sh = (apex.y - left.y) * 0.32
            var cap = Path(); cap.move(to: apex)
            cap.addLine(to: CGPoint(x: apex.x - abs(apex.x - left.x) * 0.3, y: apex.y - sh))
            cap.addLine(to: CGPoint(x: apex.x, y: apex.y - sh * 0.4))
            cap.addLine(to: CGPoint(x: apex.x + abs(right.x - apex.x) * 0.3, y: apex.y - sh))
            cap.closeSubpath()
            ctx.fill(cap, with: .color(Parch.snow))
        }
    }

    func drawDecor(_ ctx: inout GraphicsContext, _ r: CGRect) {
        drawPalm(&ctx, at: pt(0.33, 0.80, r), s: r.width * 0.045)
        drawPalm(&ctx, at: pt(0.57, 0.70, r), s: r.width * 0.04)
        drawCity(&ctx, at: pt(0.70, 0.10, r), s: r.width * 0.05)   // emblema decorativo (sobre el mar, al norte)
    }

    func drawPalm(_ ctx: inout GraphicsContext, at o: CGPoint, s: CGFloat) {
        var trunk = Path(); trunk.move(to: o)
        trunk.addQuadCurve(to: CGPoint(x: o.x + s * 0.12, y: o.y - s), control: CGPoint(x: o.x - s * 0.1, y: o.y - s * 0.5))
        ctx.stroke(trunk, with: .color(Parch.ink), lineWidth: 1.6)
        let top = CGPoint(x: o.x + s * 0.12, y: o.y - s)
        for ang in stride(from: -2.4, through: -0.7, by: 0.42) {
            let cx = CGFloat(cos(ang)), cy = CGFloat(sin(ang))
            let end = CGPoint(x: top.x + cx * s * 0.8, y: top.y + cy * s * 0.8)
            let ctrl = CGPoint(x: top.x + cx * s * 0.4, y: top.y + cy * s * 0.4 - s * 0.15)
            var frond = Path(); frond.move(to: top); frond.addQuadCurve(to: end, control: ctrl)
            ctx.stroke(frond, with: .color(Parch.ink.opacity(0.8)), lineWidth: 1.3)
        }
    }

    func drawCity(_ ctx: inout GraphicsContext, at o: CGPoint, s: CGFloat) {
        // Muralla y torres (emblema, sin nombre).
        let wall = CGRect(x: o.x - s * 0.5, y: o.y, width: s, height: s * 0.5)
        ctx.fill(Path(wall), with: .color(Parch.paper1.opacity(0.9)))
        ctx.stroke(Path(wall), with: .color(Parch.ink), lineWidth: 1.2)
        for tx in [o.x - s * 0.5, o.x, o.x + s * 0.5] {
            let tw = s * 0.22
            let tower = CGRect(x: tx - tw / 2, y: o.y - s * 0.3, width: tw, height: s * 0.3)
            ctx.fill(Path(tower), with: .color(Parch.paper1))
            ctx.stroke(Path(tower), with: .color(Parch.ink), lineWidth: 1.1)
        }
    }

    func drawEdgeLabels(_ ctx: inout GraphicsContext, _ r: CGRect) {
        func tag(_ es: String, at n: CGPoint, angle: Double) {
            ctx.drawLayer { l in
                l.translateBy(x: pt(n.x, n.y, r).x, y: pt(n.x, n.y, r).y)
                l.rotate(by: .radians(angle))
                var t = l.resolve(Text(es).font(Theme.font(max(9, r.width * 0.026), .semibold)))
                t.shading = .color(Parch.inkSoft)
                l.draw(t, at: .zero)
            }
        }
        tag("→ a Egipto", at: CGPoint(x: 0.13, y: 0.92), angle: 0.2)
        tag("Mesopotamia →", at: CGPoint(x: 0.86, y: 0.5), angle: .pi / 2)
    }

    func drawManchas(_ ctx: inout GraphicsContext, _ r: CGRect) {
        let spots: [(Double, Double, Double)] = [(0.8,0.78,0.05),(0.72,0.9,0.035),(0.9,0.33,0.03),(0.4,0.14,0.03),(0.66,0.66,0.025)]
        for (x, y, rad) in spots {
            let c = pt(x, y, r)
            let e = CGRect(x: c.x - rad * r.width, y: c.y - rad * r.width, width: rad * 2 * r.width, height: rad * 2 * r.width)
            ctx.fill(Path(ellipseIn: e), with: .color(Parch.edge.opacity(0.14)))
        }
    }

    func drawVignette(_ ctx: inout GraphicsContext, _ r: CGRect) {
        let grad = Gradient(stops: [.init(color: .clear, location: 0.6), .init(color: Parch.edge.opacity(0.0), location: 0.6),
                                    .init(color: Color(hex: 0x8A703C).opacity(0.28), location: 1.0)])
        ctx.fill(Path(r), with: .radialGradient(grad, center: CGPoint(x: r.midX, y: r.midY),
                                                startRadius: 0, endRadius: max(r.width, r.height) * 0.72))
    }

    func drawFrame(_ ctx: inout GraphicsContext, _ r: CGRect) {
        let o = r.insetBy(dx: r.width * 0.012, dy: r.width * 0.012)
        let i = o.insetBy(dx: r.width * 0.012, dy: r.width * 0.012)
        ctx.stroke(Path(roundedRect: o, cornerRadius: r.width * 0.012), with: .color(Parch.ink), lineWidth: max(2, r.width * 0.008))
        ctx.stroke(Path(roundedRect: i, cornerRadius: r.width * 0.01), with: .color(Parch.ink), lineWidth: 1)
    }

    func drawCompass(_ ctx: inout GraphicsContext, _ r: CGRect) {
        let c = pt(0.88, 0.14, r); let rad = r.width * 0.055
        ctx.stroke(Path(ellipseIn: CGRect(x: c.x - rad, y: c.y - rad, width: rad * 2, height: rad * 2)),
                   with: .color(Parch.ink), lineWidth: 1.2)
        for (dx, dy) in [(0.0, -1.0), (1.0, 0.0), (0.0, 1.0), (-1.0, 0.0)] {
            var ray = Path(); ray.move(to: c)
            ray.addLine(to: CGPoint(x: c.x + dx * rad, y: c.y + dy * rad))
            ctx.stroke(ray, with: .color(Parch.ink.opacity(0.5)), lineWidth: 0.8)
        }
        var nStar = Path()
        nStar.move(to: CGPoint(x: c.x, y: c.y - rad * 0.85))
        nStar.addLine(to: CGPoint(x: c.x + rad * 0.18, y: c.y))
        nStar.addLine(to: CGPoint(x: c.x, y: c.y + rad * 0.85))
        nStar.addLine(to: CGPoint(x: c.x - rad * 0.18, y: c.y)); nStar.closeSubpath()
        ctx.fill(nStar, with: .color(Parch.b.opacity(0.85)))
        label(&ctx, "N", Theme.font(max(9, rad * 0.5), .bold), Parch.ink, at: CGPoint(x: c.x, y: c.y - rad - rad * 0.3))
    }

    func drawTitle(_ ctx: inout GraphicsContext, _ r: CGRect) {
        let w = r.width * 0.30, h = r.height * 0.075
        let box = CGRect(x: r.minX + r.width * 0.055, y: r.minY + r.height * 0.045, width: w, height: h)
        ctx.fill(Path(roundedRect: box, cornerRadius: h * 0.3), with: .color(Parch.paper1.opacity(0.92)))
        ctx.stroke(Path(roundedRect: box, cornerRadius: h * 0.3), with: .color(Parch.ink), lineWidth: 1.2)
        label(&ctx, "Tierras bíblicas", Theme.font(max(10, h * 0.42), .bold), Parch.ink,
              at: CGPoint(x: box.midX, y: box.midY - h * 0.16))
        label(&ctx, "圣经地图", Theme.fontZH(max(9, h * 0.34), .semibold), Parch.inkSoft,
              at: CGPoint(x: box.midX, y: box.midY + h * 0.24))
    }
}

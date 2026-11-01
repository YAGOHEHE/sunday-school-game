import SwiftUI
import JuegosCore

// MARK: - Ficha (diseno/01, columna derecha)

struct GameDetailView: View {
    @Environment(AppModel.self) private var model
    @Environment(PlayController.self) private var play
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Group {
            if let g = model.selectedGame { detail(g) } else {
                VStack(spacing: 8) {
                    Image(systemName: "gamecontroller").font(.system(size: 48)).foregroundStyle(Theme.secondary)
                    Text(model.t("Elige un juego", "选择一个游戏")).font(Theme.font(16)).foregroundStyle(Theme.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Theme.surface)
    }

    private func detail(_ g: Game) -> some View {
        let ink = categoryInk(g.category, scheme)
        let tpl = model.template(for: g)
        return ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .center, spacing: 18) {
                    Text(g.icon).font(.system(size: 46))
                        .frame(width: 80, height: 80)
                        .background(RoundedRectangle(cornerRadius: 24).fill(g.category.adaptiveTint))
                    VStack(alignment: .leading, spacing: 4) {
                        BiText(g.title, size: 28, weight: .bold).foregroundStyle(Theme.ink)
                        dataLine(g, tpl: tpl)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    HStack(spacing: 6) {
                        Button { play.play(g) } label: {
                            Text(model.t("Jugar", "开始玩")).font(Theme.font(15, .semibold)).foregroundStyle(.white).lineLimit(1).fixedSize()
                                .padding(.horizontal, 18).frame(minHeight: Theme.minTap)
                                .background(Capsule().fill(Theme.ok)).contentShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        Menu {
                            if !inSession(g) {
                                Button { model.addToSession(g) } label: { Label(model.t("Añadir a la sesión", "加入课程"), systemImage: "plus") }
                            }
                            Button { model.toggleFavorite(g.id) } label: {
                                Label(model.isFavorite(g.id) ? model.t("Quitar favorito", "取消收藏") : model.t("Favorito", "收藏"),
                                      systemImage: model.isFavorite(g.id) ? "star.slash" : "star")
                            }
                            Button { model.edit(g) } label: { Label(model.t("Editar", "编辑"), systemImage: "pencil") }
                            Button(role: .destructive) { model.hide(g.id) } label: { Label(model.t("Ocultar", "隐藏"), systemImage: "eye.slash") }
                        } label: {
                            Image(systemName: "ellipsis").font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.ink)
                                .frame(width: Theme.minTap, height: Theme.minTap)
                                .background(Circle().stroke(Theme.border.opacity(1), lineWidth: 1).background(Circle().fill(Theme.surface)))
                        }
                        .menuStyle(.button).buttonStyle(.plain).menuIndicator(.hidden).fixedSize()
                        .accessibilityLabel(model.t("Más acciones", "更多操作"))
                    }
                    .alignmentGuide(VerticalAlignment.center) { $0[VerticalAlignment.center] }
                }
                    VStack(alignment: .trailing, spacing: 12) {
                        HStack(alignment: .center, spacing: 18) {
                    Text(g.icon).font(.system(size: 46))
                        .frame(width: 80, height: 80)
                        .background(RoundedRectangle(cornerRadius: 24).fill(g.category.adaptiveTint))
                    VStack(alignment: .leading, spacing: 4) {
                        BiText(g.title, size: 28, weight: .bold).foregroundStyle(Theme.ink)
                        dataLine(g, tpl: tpl)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    HStack(spacing: 6) {
                        Button { play.play(g) } label: {
                            Text(model.t("Jugar", "开始玩")).font(Theme.font(15, .semibold)).foregroundStyle(.white).lineLimit(1).fixedSize()
                                .padding(.horizontal, 18).frame(minHeight: Theme.minTap)
                                .background(Capsule().fill(Theme.ok)).contentShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        Menu {
                            if !inSession(g) {
                                Button { model.addToSession(g) } label: { Label(model.t("Añadir a la sesión", "加入课程"), systemImage: "plus") }
                            }
                            Button { model.toggleFavorite(g.id) } label: {
                                Label(model.isFavorite(g.id) ? model.t("Quitar favorito", "取消收藏") : model.t("Favorito", "收藏"),
                                      systemImage: model.isFavorite(g.id) ? "star.slash" : "star")
                            }
                            Button { model.edit(g) } label: { Label(model.t("Editar", "编辑"), systemImage: "pencil") }
                            Button(role: .destructive) { model.hide(g.id) } label: { Label(model.t("Ocultar", "隐藏"), systemImage: "eye.slash") }
                        } label: {
                            Image(systemName: "ellipsis").font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.ink)
                                .frame(width: Theme.minTap, height: Theme.minTap)
                                .background(Circle().stroke(Theme.border.opacity(1), lineWidth: 1).background(Circle().fill(Theme.surface)))
                        }
                        .menuStyle(.button).buttonStyle(.plain).menuIndicator(.hidden).fixedSize()
                        .accessibilityLabel(model.t("Más acciones", "更多操作"))
                    }
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(model.t("OBJETIVO", "目标")).font(Theme.font(12, .semibold)).tracking(0.7).foregroundStyle(ink)
                    BiText(g.objective, size: 18).foregroundStyle(Theme.ink)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20).padding(.vertical, 18)
                .background(RoundedRectangle(cornerRadius: 18).fill(g.category.adaptiveTint.opacity(scheme == .dark ? 1 : 0.6)))

                if !g.steps.isEmpty {
                    section(model.t("PASOS", "步骤")) {
                        VStack(alignment: .leading, spacing: 14) {
                            ForEach(Array(g.steps.enumerated()), id: \.offset) { i, s in
                                HStack(alignment: .top, spacing: 14) {
                                    Text("\(i + 1)").font(Theme.font(15, .semibold)).foregroundStyle(.white)
                                        .frame(width: 30, height: 30).background(Circle().fill(g.category.color))
                                    BiText(s, size: 16).foregroundStyle(Theme.ink)
                                }
                            }
                        }
                    }
                }

                if !g.tips.isEmpty {
                    section(model.t("CONSEJOS", "小贴士")) {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(Array(g.tips.enumerated()), id: \.offset) { _, t in
                                HStack(alignment: .top, spacing: 8) { Text("👉"); BiText(t.withoutLeadingPointer, size: 15).foregroundStyle(Theme.ink) }
                            }
                        }
                    }
                }

                if let why = g.why {
                    section(model.t("POR QUÉ FUNCIONA", "为什么有效")) { BiText(why, size: 15).foregroundStyle(Theme.ink) }
                }

                if !g.variants.isEmpty {
                    section(model.t("VARIANTES", "变体")) {
                        VStack(spacing: 8) {
                            ForEach(Array(g.variants.enumerated()), id: \.offset) { _, v in
                                DisclosureGroup {
                                    VStack(alignment: .leading, spacing: 8) {
                                        if let o = v.objective { BiText(o, size: 14, weight: .medium) }
                                        ForEach(Array(v.steps.enumerated()), id: \.offset) { i, s in
                                            HStack(alignment: .top) { Text("\(i + 1).").font(Theme.font(14, .bold)); BiText(s, size: 14) }
                                        }
                                        ForEach(Array(v.tips.enumerated()), id: \.offset) { _, t in
                                            HStack(alignment: .top) { Text("👉"); BiText(t.withoutLeadingPointer, size: 14) }
                                        }
                                    }.padding(.top, 6)
                                } label: { BiText(v.title, size: 15, weight: .semibold) }
                            }
                        }
                        .foregroundStyle(Theme.ink)
                    }
                }
            }
            .padding(.horizontal, 36).padding(.vertical, 28)
            .frame(maxWidth: 820, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("")
    }

    private func inSession(_ g: Game) -> Bool { model.session.items.contains { $0.gameID == g.id } }

    private func dataLine(_ g: Game, tpl: PlayTemplate) -> some View {
        let mins = "\(g.minMinutes == g.maxMinutes ? "\(g.minMinutes)" : "\(g.minMinutes)–\(g.maxMinutes)") min"
        let cat = model.text(g.category.name).replacingOccurrences(of: "\n", with: " · ")
        let tname = model.text(tpl.name).replacingOccurrences(of: "\n", with: " · ")
        return HStack(spacing: 0) {
            Text("\(cat) · \(mins) · ").foregroundStyle(Theme.secondary).lineLimit(1)
            Button { model.openTemplates(focus: tpl.id) } label: {
                Text("\(model.t("Plantilla", "模板")) \(tname)").foregroundStyle(Theme.accentPlanificar).underline().lineLimit(1)
                    .frame(minHeight: 24).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(model.t("Plantilla", "模板")): \(tpl.name.es). \(model.t("Abrir plantillas", "打开模板"))")
        }
        .font(Theme.font(14))
    }

    private func chip(_ text: String, fg: Color, bg: Color) -> some View {
        Text(text).font(Theme.font(13, .semibold)).foregroundStyle(fg).lineLimit(1)
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(Capsule().fill(bg))
    }

    private func section<C: View>(_ title: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(Theme.font(12, .semibold)).tracking(0.7).foregroundStyle(Theme.secondary)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}


private extension L {
    /// Los tips del catálogo a veces ya empiezan con «👉»; la vista añade el suyo.
    var withoutLeadingPointer: L {
        func strip(_ x: String) -> String {
            var t = x.trimmingCharacters(in: .whitespaces)
            while t.hasPrefix("👉") { t = String(t.dropFirst()).trimmingCharacters(in: .whitespaces) }
            return t
        }
        return L(strip(es), strip(zh))
    }
}

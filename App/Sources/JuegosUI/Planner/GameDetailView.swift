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
                HStack(alignment: .center, spacing: 20) {
                    Text(g.icon).font(.system(size: 56))
                        .frame(width: 96, height: 96)
                        .background(RoundedRectangle(cornerRadius: 28).fill(g.category.adaptiveTint))
                    VStack(alignment: .leading, spacing: 8) {
                        BiText(g.title, size: 32, weight: .bold).foregroundStyle(Theme.ink)
                        FlowLayout(spacing: 8) {
                            chip("\(g.category.emoji) \(model.text(g.category.name).replacingOccurrences(of: "\n", with: " · "))", fg: ink, bg: g.category.adaptiveTint)
                            chip("\(g.minMinutes == g.maxMinutes ? "\(g.minMinutes)" : "\(g.minMinutes)–\(g.maxMinutes)") min", fg: Theme.ink, bg: Theme.chipNeutral)
                            if !g.tools.isEmpty {
                                chip(g.tools.map { model.text($0.kind.label).replacingOccurrences(of: "\n", with: " ") }.joined(separator: " · "),
                                     fg: Theme.ink, bg: Theme.chipNeutral)
                            }
                            Button { model.openTemplates(focus: tpl.id) } label: {
                                Text("\(model.t("Plantilla", "模板")): \(model.text(tpl.name).replacingOccurrences(of: "\n", with: " · "))\(g.template == nil ? " ·" + model.t(" auto", " 自动") : "")")
                                    .font(Theme.font(13, .semibold)).foregroundStyle(Theme.accentPlanificar).lineLimit(1)
                                    .padding(.horizontal, 10).padding(.vertical, 4)
                                    .background(Capsule().stroke(Theme.accentPlanificar.opacity(0.5)))
                                    .frame(minHeight: Theme.minTap).contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(model.t("Plantilla", "模板")): \(tpl.name.es). \(model.t("Abrir plantillas", "打开模板"))")
                        }
                    }
                }

                FlowLayout(spacing: 10) {
                    Button { play.play(g) } label: { Label(model.t("Jugar ahora", "开始玩"), systemImage: "play.fill") }
                        .buttonStyle(PillButtonStyle(color: Theme.ok))
                    Button { model.addToSession(g) } label: { Label(model.t("Añadir a la sesión", "加入课程"), systemImage: "plus") }
                        .buttonStyle(PillButtonStyle(color: g.category.color))
                    Button { model.toggleFavorite(g.id) } label: {
                        Image(systemName: model.isFavorite(g.id) ? "star.fill" : "star").foregroundStyle(.yellow)
                    }
                    .buttonStyle(PillButtonStyle(color: .yellow, filled: false))
                    .accessibilityLabel(model.t("Favorito", "收藏"))
                    Button { model.edit(g) } label: { Label(model.t("Editar", "编辑"), systemImage: "pencil") }
                        .buttonStyle(PillButtonStyle(color: Theme.ink, filled: false))
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
                                HStack(alignment: .top, spacing: 8) { Text("👉"); BiText(t, size: 15).foregroundStyle(Theme.ink) }
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
                                            HStack(alignment: .top) { Text("👉"); BiText(t, size: 14) }
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
        .navigationTitle(model.text(g.title).replacingOccurrences(of: "\n", with: " · "))
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

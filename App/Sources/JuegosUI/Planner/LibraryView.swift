import SwiftUI
import JuegosCore

// MARK: - Biblioteca (diseno/01, columna izquierda)

struct LibraryView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme

    private var query: Binding<String> { Binding(get: { model.query }, set: { model.query = $0 }) }

    var body: some View {
        GeometryReader { geo in
            content.frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
        }
        .background(Theme.background)
        .navigationTitle("")
    }

    private var content: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass").foregroundStyle(Theme.secondary)
                    TextField(model.t("Buscar", "搜索"), text: query).textFieldStyle(.plain).font(Theme.font(15))
                        .accessibilityLabel(model.t("Buscar juegos", "搜索游戏"))
                    if !model.query.isEmpty {
                        Button { model.query = "" } label: {
                            Image(systemName: "xmark.circle.fill").frame(width: 28, height: 28).contentShape(Rectangle())
                        }
                        .buttonStyle(.plain).foregroundStyle(Theme.secondary)
                        .accessibilityLabel(model.t("Borrar búsqueda", "清除搜索"))
                    }
                }
                .padding(.horizontal, 12).frame(minHeight: Theme.minTap)
                .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surface))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border))
                    .frame(maxWidth: .infinity)
                    filterMenu
                    Button { model.newGame() } label: {
                        Image(systemName: "plus").font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.ink)
                            .frame(width: Theme.minTap, height: Theme.minTap)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surface))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(model.t("Nuevo juego", "新游戏")).help(model.t("Nuevo juego", "新游戏"))
                }

                FlowLayout(spacing: 6) {
                    chip(model.t("Todos", "全部"), fg: Theme.ink, bg: Theme.chipNeutral, selFG: Color(light: 0xFFFFFF, dark: 0x1F1D2B), selBG: Theme.ink,
                         selected: model.categoryFilter == nil) { model.categoryFilter = nil }
                    ForEach(GameCategory.allCases, id: \.self) { c in
                        chip(model.text(c.name).replacingOccurrences(of: "\n", with: " "),
                             fg: categoryInk(c, scheme), bg: c.adaptiveTint, selFG: .white, selBG: c.color,
                             selected: model.categoryFilter == c) {
                            model.categoryFilter = model.categoryFilter == c ? nil : c
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text("\(model.filteredGames.count) \(model.t("JUEGOS", "游戏"))")
                    .font(Theme.font(12, .semibold)).tracking(0.5).foregroundStyle(Theme.secondary).lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 8)

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(model.filteredGames) { g in
                        LibraryRow(game: g)
                            .draggable(g.id)
                    }
                    if model.hasHidden {
                        Button(model.t("Mostrar juegos ocultos", "显示已隐藏")) { model.unhideAll() }
                            .buttonStyle(.link).font(.caption)
                    }
                }
                .padding(.horizontal, 14).padding(.bottom, 14).padding(.top, 4)
            }
            .overlay {
                if model.filteredGames.isEmpty {
                    Text(model.t("Sin resultados", "没有结果")).foregroundStyle(Theme.secondary)
                }
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
        .clipped()
    }

    private var filterActive: Bool { model.durationFilter != .all || model.favoritesOnly }

    private var filterMenu: some View {
        Menu {
            Section(model.t("Duración", "时长")) {
                ForEach(DurationFilter.allCases) { d in
                    Button { model.durationFilter = d } label: {
                        if model.durationFilter == d { Label(d == .all ? model.t("Todas", "全部") : "\(d.label) min", systemImage: "checkmark") }
                        else { Text(d == .all ? model.t("Todas", "全部") : "\(d.label) min") }
                    }
                }
            }
            Divider()
            Toggle(isOn: Binding(get: { model.favoritesOnly }, set: { model.favoritesOnly = $0 })) {
                Label(model.t("Solo favoritos", "仅收藏"), systemImage: "star")
            }
            if filterActive {
                Divider()
                Button(model.t("Quitar filtros", "清除筛选")) { model.durationFilter = .all; model.favoritesOnly = false }
            }
        } label: {
            Image(systemName: "line.3.horizontal.decrease.circle\(filterActive ? ".fill" : "")")
                .font(.system(size: 17)).foregroundStyle(filterActive ? Color.white : Theme.ink)
                .frame(width: Theme.minTap, height: Theme.minTap)
                .background(RoundedRectangle(cornerRadius: 12).fill(filterActive ? Theme.accentPlanificar : Theme.surface))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border))
        }
        .menuStyle(.button).buttonStyle(.plain).menuIndicator(.hidden).fixedSize()
        .accessibilityLabel(model.t("Filtros: duración y favoritos", "筛选：时长和收藏"))
        .accessibilityValue(filterActive ? "on" : "off")
    }

    private func chip(_ title: String, fg: Color, bg: Color, selFG: Color, selBG: Color, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(Theme.font(13, .semibold))
                .lineLimit(1).fixedSize()
                .padding(.horizontal, 12).frame(minHeight: 32)
                .background(Capsule().fill(selected ? selBG : bg))
                .foregroundStyle(selected ? selFG : fg)
                .frame(minHeight: Theme.minTap)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct LibraryRow: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    let game: Game

    private var minutesText: String {
        "\(game.minMinutes == game.maxMinutes ? "\(game.minMinutes)" : "\(game.minMinutes)–\(game.maxMinutes)") min"
    }
    private var titleText: String { model.language == .zh ? game.title.text(.zh) : game.title.text(.es) }
    private var subtitle: String {
        if model.language == .both, !game.title.zh.isEmpty, game.title.zh != game.title.es { return "\(game.title.zh) · \(minutesText)" }
        return minutesText
    }
    private var inSession: Bool { model.session.items.contains { $0.gameID == game.id } }
    private var selected: Bool { model.selectedGameID == game.id }

    var body: some View {
        HStack(spacing: 12) {
            Text(game.icon).font(.system(size: 24))
                .frame(width: 44, height: 44)
                .background(RoundedRectangle(cornerRadius: 12).fill(game.category.adaptiveTint))
            VStack(alignment: .leading, spacing: 1) {
                Text(titleText).font(model.language == .zh ? Theme.fontZH(15, .semibold) : Theme.font(15, .semibold))
                    .foregroundStyle(Theme.ink).lineLimit(2)
                Text(subtitle).font(Theme.fontZH(12)).foregroundStyle(Theme.secondary).lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if model.isFavorite(game.id) { Image(systemName: "star.fill").foregroundStyle(.yellow).font(.caption) }
            if inSession {
                Text(model.t("En sesión", "已加入")).font(Theme.font(12, .semibold)).foregroundStyle(Theme.ok).lineLimit(1).fixedSize()
                    .padding(.trailing, 8)
            } else {
            Button { model.addToSession(game) } label: {
                Image(systemName: "plus").font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                    .frame(width: 36, height: 36).background(Circle().fill(game.category.color))
                    .frame(width: Theme.minTap, height: Theme.minTap).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(model.t("Añadir a la sesión", "加入课程")): \(game.title.es)")
            .help(model.t("Añadir a la sesión", "加入课程"))
            }
        }
        .padding(.leading, 10).padding(.trailing, 4).padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(selected ? game.category.color : Theme.border, lineWidth: selected ? 2 : 1))
        .contentShape(RoundedRectangle(cornerRadius: 16))
        .onTapGesture(count: 2) { model.addToSession(game) }
        .onTapGesture { model.selectedGameID = game.id }
        .accessibilityElement(children: .contain)
        .contextMenu {
            Button(model.t("Añadir a la sesión", "加入课程")) { model.addToSession(game) }
            Button(model.isFavorite(game.id) ? model.t("Quitar favorito", "取消收藏") : model.t("Favorito", "收藏")) { model.toggleFavorite(game.id) }
            Button(model.t("Editar…", "编辑…")) { model.edit(game) }
        }
    }
}

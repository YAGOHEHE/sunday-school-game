import SwiftUI
import JuegosCore

// MARK: - Sesión del día (diseno/01, columna central)

struct SessionView: View {
    @Environment(AppModel.self) private var model
    @Environment(PlayController.self) private var play
    @Environment(\.colorScheme) private var scheme
    @State private var dropTargeted = false
    @State private var showDate = false
    @State private var showMinutes = false
    @State private var notesOpen = false

    static let rowGap: CGFloat = 6
    static let rowH: CGFloat = 52

    var body: some View {
        @Bindable var model = model
        let s = model.session
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    sessionBlock(s)

                    notesSection
                }
                .padding(20)
            }
            Button { play.startSession(model: model) } label: {
                HStack(spacing: 10) {
                    Image(systemName: "play.fill")
                    Text(model.t("Empezar sesión", "开始课程")).font(Theme.font(20, .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 60)
                .background(RoundedRectangle(cornerRadius: 18).fill(Theme.accentPlanificar))
                .opacity(s.items.isEmpty ? 0.4 : 1)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(s.items.isEmpty)
            .padding(.horizontal, 20).padding(.vertical, 14)
            .accessibilityLabel("\(model.t("Empezar sesión", "开始课程"))")
        }
        .background(Theme.background)
        .navigationTitle("")
    }

    // MARK: Cabecera

    private var header: some View {
        @Bindable var model = model
        let s = model.session
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                TextField(model.t("Sesión de hoy", "今日课程"), text: $model.userData.currentSession.title)
                    .textFieldStyle(.plain).font(Theme.font(28, .bold)).foregroundStyle(Theme.ink)
                    .accessibilityLabel(model.t("Título de la sesión", "课程标题"))
                Button { showDate = true } label: {
                    Text(shortDate).font(Theme.font(14)).foregroundStyle(Theme.ink).lineLimit(1).fixedSize()
                        .padding(.horizontal, 12).frame(minHeight: 36)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.surface))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.border))
                        .frame(minHeight: Theme.minTap).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(model.t("Fecha de la sesión", "课程日期")): \(shortDate)")
                .popover(isPresented: $showDate) {
                    DatePicker("", selection: $model.userData.currentSession.date, displayedComponents: .date)
                        .datePickerStyle(.graphical).labelsHidden().padding(12)
                }
            }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(s.totalMinutes)").font(Theme.font(22, .bold)).foregroundStyle(Theme.ink)
                Text(model.t("de", "/")).font(Theme.font(15)).foregroundStyle(Theme.secondary)
                Button { showMinutes = true } label: {
                    Text("\(s.availableMinutes)").font(Theme.font(22, .bold)).foregroundStyle(Theme.ink)
                        .overlay(alignment: .bottom) {
                            Rectangle().fill(Theme.secondary).frame(height: 2).offset(y: 3).mask(
                                HStack(spacing: 2) { ForEach(0..<8, id: \.self) { _ in Rectangle().frame(width: 2) } })
                        }
                        .frame(minWidth: Theme.minTap, minHeight: Theme.minTap).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(model.t("Cambiar minutos disponibles", "更改可用分钟")).accessibilityValue("\(s.availableMinutes) min")
                .popover(isPresented: $showMinutes) {
                    Stepper(value: $model.userData.currentSession.availableMinutes, in: 5...180, step: 5) {
                        Text("\(model.session.availableMinutes) min").font(Theme.font(16, .semibold))
                    }
                    .padding(16).frame(width: 190)
                }
                Text("min").font(Theme.font(15)).foregroundStyle(Theme.secondary)
            }
        }
    }

    private var shortDate: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: model.language == .zh ? "zh_CN" : "es_ES")
        f.setLocalizedDateFormatFromTemplate("EEEdMMM")
        return f.string(from: model.session.date).capitalized
    }

    // MARK: Lista

    private var notesSection: some View {
        @Bindable var model = model
        return VStack(alignment: .leading, spacing: 6) {
            if notesOpen || !model.session.notes.isEmpty {
                TextEditor(text: $model.userData.currentSession.notes)
                    .font(Theme.font(14)).frame(minHeight: 70).scrollContentBackground(.hidden)
                    .padding(6).background(RoundedRectangle(cornerRadius: 12).fill(Theme.surface))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border))
                    .accessibilityLabel(model.t("Notas", "备注"))
            } else {
                Button { notesOpen = true } label: {
                    Text(model.t("+ Añadir nota", "+ 添加备注")).font(Theme.font(14)).foregroundStyle(Theme.secondary)
                        .frame(minHeight: Theme.minTap, alignment: .leading).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func sessionBlock(_ s: Session) -> some View {
        @Bindable var model = model
        let free = s.availableMinutes - s.totalMinutes
        let listHeight = CGFloat(s.items.count) * (Self.rowH + Self.rowGap)
        return VStack(spacing: 6) {
            if !s.items.isEmpty {
                List {
                    ForEach($model.userData.currentSession.items) { $item in
                        SessionRow(item: $item, index: (s.items.firstIndex { $0.id == item.id } ?? 0), count: s.items.count)
                            .listRowInsets(EdgeInsets(top: Self.rowGap / 2, leading: 0, bottom: Self.rowGap / 2, trailing: 0))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    }
                    .onMove { model.userData.currentSession.items.move(fromOffsets: $0, toOffset: $1) }
                    .onDelete { model.userData.currentSession.items.remove(atOffsets: $0) }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .scrollDisabled(true)
                .frame(height: listHeight + 2)
            }
            freeBlock(free: free, empty: s.items.isEmpty)
        }
        .dropDestination(for: String.self) { ids, _ in
            for id in ids { model.addToSession(id: id) }
            return !ids.isEmpty
        } isTargeted: { dropTargeted = $0 }
    }

    private func freeBlock(free: Int, empty: Bool) -> some View {
        let over = free < 0
        let text: String
        if over { text = model.t("Te pasas \(-free) min", "超时 \(-free) 分钟") }
        else if empty { text = model.t("Quedan \(free) min · arrastra un juego aquí o pulsa +", "还剩 \(free) 分钟 · 拖入游戏或点 +") }
        else { text = model.t("Quedan \(free) min · suelta un juego aquí", "还剩 \(free) 分钟 · 拖入游戏") }
        let color = over ? Theme.danger : Theme.ok
        return Text(text)
            .font(Theme.font(14, .semibold)).foregroundStyle(color).multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, minHeight: Self.rowH)
            .padding(.horizontal, 8)
            .background(RoundedRectangle(cornerRadius: 12).fill(dropTargeted ? Theme.accentPlanificar.opacity(0.12) : Color.clear))
            .overlay(RoundedRectangle(cornerRadius: 12)
                .strokeBorder(dropTargeted ? Theme.accentPlanificar : (over ? Theme.danger.opacity(0.6) : Color(light: 0xD6D0C3, dark: 0x3A3A48)), style: StrokeStyle(lineWidth: 2, dash: [6, 4])))
            .padding(.top, 4)
    }
}

// MARK: Fila de sesión (52 pt fija)

private struct SessionRow: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    @Binding var item: SessionItem
    let index: Int
    let count: Int
    @State private var hover = false

    private var selected: Bool { model.selectedGameID == item.gameID }

    var body: some View {
        if let g = model.game(item.gameID) {
            let active = selected || hover
            HStack(spacing: 10) {
                Rectangle().fill(g.category.color).frame(width: 5)
                Text(g.icon).font(.system(size: 20))
                BiText(g.title, size: 15, weight: .semibold)
                    .foregroundStyle(Theme.ink).lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if active {
                    miniButton("minus", label: "\(model.t("Menos minutos", "减少分钟")): \(g.title.es)") { item.minutes = max(1, item.minutes - 1) }
                }
                Text("\(item.minutes)′").font(Theme.font(15, .semibold)).monospacedDigit().foregroundStyle(Theme.ink)
                    .frame(minWidth: 30)
                if active {
                    miniButton("plus", label: "\(model.t("Más minutos", "增加分钟")): \(g.title.es)") { item.minutes = min(90, item.minutes + 1) }
                    Button { remove() } label: {
                        Image(systemName: "xmark").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.secondary)
                            .frame(width: 36, height: 36).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(model.t("Quitar de la sesión", "移出课程")): \(g.title.es)")
                } else {
                    Color.clear.frame(width: 6, height: 1)
                }
            }
            .padding(.trailing, 4)
            .frame(height: SessionView.rowH)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(selected ? g.category.color : Theme.border, lineWidth: selected ? 1.5 : 1))
            .contentShape(Rectangle())
            .onHover { hover = $0 }
            .onTapGesture { model.selectedGameID = g.id }
            .accessibilityElement(children: .contain)
            .contextMenu {
                Button(model.t("Subir", "上移")) { move(-1) }.disabled(index == 0)
                Button(model.t("Bajar", "下移")) { move(1) }.disabled(index == count - 1)
                Button(model.t("Quitar", "移除"), role: .destructive) { remove() }
            }
        }
    }

    private func miniButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.ink)
                .frame(width: 32, height: 32)
                .background(RoundedRectangle(cornerRadius: 8).fill(Theme.chipNeutral))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain).accessibilityLabel(label)
    }

    private func remove() { model.userData.currentSession.items.removeAll { $0.id == item.id } }

    private func move(_ d: Int) {
        var items = model.session.items
        guard let i = items.firstIndex(where: { $0.id == item.id }), items.indices.contains(i + d) else { return }
        items.swapAt(i, i + d)
        model.userData.currentSession.items = items
    }
}

// MARK: Historial (botón de la barra + popover)

struct HistoryButton: View {
    @Environment(AppModel.self) private var model
    @State private var open = false

    var body: some View {
        Button { open = true } label: {
            Label(model.t("Historial", "历史"), systemImage: "clock.arrow.circlepath")
        }
        .help(model.t("Historial de sesiones", "课程历史"))
        .popover(isPresented: $open, arrowEdge: .bottom) { content }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(model.t("Historial", "历史")).font(Theme.font(17, .semibold)).foregroundStyle(Theme.ink)
            if model.userData.history.isEmpty {
                Text(model.t("Aún no hay sesiones", "暂无记录")).font(Theme.font(14)).foregroundStyle(Theme.secondary)
            }
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(model.userData.history.prefix(10)) { h in
                        HStack(alignment: .center, spacing: 10) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("\(h.date.formatted(date: .abbreviated, time: .omitted))\(h.title.isEmpty ? "" : " · \(h.title)")")
                                    .font(Theme.font(14, .semibold)).foregroundStyle(Theme.ink).lineLimit(1)
                                Text(h.items.compactMap { model.game($0.gameID)?.icon }.joined(separator: " ") + "  · \(h.totalMinutes) min")
                                    .font(Theme.font(12)).foregroundStyle(Theme.secondary).lineLimit(1)
                            }
                            Spacer(minLength: 0)
                            Button(model.t("Repetir", "重复")) { model.repeatSession(h); open = false }
                                .buttonStyle(PillButtonStyle(color: Theme.accentPlanificar, filled: false))
                        }
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surface))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border))
                    }
                }
            }
        }
        .padding(14).frame(width: 360).frame(maxHeight: 460)
    }
}

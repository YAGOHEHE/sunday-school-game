import SwiftUI
import JuegosCore

// MARK: - Historial de sesiones (botón de la barra + hoja)

struct HistoryButton: View {
    @Environment(AppModel.self) private var model
    @State private var open = false

    var body: some View {
        Button { open = true } label: {
            Label(model.t("Historial", "历史"), systemImage: "clock.arrow.circlepath")
        }
        .help(model.t("Historial de sesiones", "课程历史"))
        .sheet(isPresented: $open) { HistoryView() }
    }
}

struct HistoryView: View {
    @Environment(AppModel.self) private var model
    @Environment(PlayController.self) private var play
    @Environment(\.dismiss) private var dismiss
    @State private var selectedID: UUID?
    @State private var query = ""
    @State private var confirmDelete = false

    private var sessions: [Session] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return model.userData.history }
        return model.userData.history.filter { s in
            s.title.localizedCaseInsensitiveContains(q)
            || s.notes.localizedCaseInsensitiveContains(q)
            || s.items.contains { model.game($0.gameID)?.matches(q) ?? false }
        }
    }

    private var selected: Session? {
        selectedID.flatMap { id in model.userData.history.first { $0.id == id } }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(model.t("Historial de sesiones", "课程历史")).font(Theme.font(20, .bold)).foregroundStyle(Theme.ink)
                Spacer()
                Button(model.s("Cerrar", "关闭")) { dismiss() }
                    .buttonStyle(PillButtonStyle(color: Theme.secondary, filled: false))
                    .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 24).padding(.vertical, 12)
            Divider()
            if model.userData.history.isEmpty {
                emptyState
            } else {
                HStack(spacing: 0) {
                    list.frame(width: 300)
                    Divider()
                    Group {
                        if let s = selected { detail(s) } else {
                            Text(model.t("Elige una sesión", "选择一个课程")).font(Theme.font(15)).foregroundStyle(Theme.secondary)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Theme.surface)
                }
            }
        }
        .frame(minWidth: 820, idealWidth: 880, minHeight: 560, idealHeight: 620)
        .background(Theme.background)
        .onAppear { if selectedID == nil { selectedID = model.userData.history.first?.id } }
        .confirmationDialog(model.t("¿Eliminar esta sesión del historial?", "从历史中删除这个课程？"),
                            isPresented: $confirmDelete, titleVisibility: .visible) {
            Button(model.t("Eliminar", "删除"), role: .destructive) { deleteSelected() }
            Button(model.s("Cancelar", "取消"), role: .cancel) {}
        }
    }

    // MARK: Lista

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "clock.arrow.circlepath").font(.system(size: 44)).foregroundStyle(Theme.secondary)
            Text(model.t("Aún no hay sesiones guardadas", "暂无保存的课程")).font(Theme.font(16, .semibold)).foregroundStyle(Theme.ink)
            Text(model.t("Pulsa «Guardar» en la sesión o empieza una sesión para guardarla aquí.",
                         "在课程中点「保存」或开始课程，即可保存到这里。"))
                .font(Theme.font(14)).foregroundStyle(Theme.secondary).multilineTextAlignment(.center)
        }
        .padding(40).frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var list: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").foregroundStyle(Theme.secondary)
                TextField(model.s("Buscar", "搜索"), text: $query).textFieldStyle(.plain).font(Theme.font(14))
            }
            .padding(.horizontal, 10).frame(minHeight: 36)
            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.surface))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.border))
            .padding(12)
            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(sessions) { s in row(s) }
                    if sessions.isEmpty {
                        Text(model.t("Sin resultados", "无结果")).font(Theme.font(14)).foregroundStyle(Theme.secondary).padding(.top, 20)
                    }
                }
                .padding(.horizontal, 12).padding(.bottom, 12)
            }
        }
    }

    private func row(_ s: Session) -> some View {
        let on = s.id == selectedID
        let current = s.id == model.session.id
        return Button { selectedID = s.id } label: {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(dateText(s.date, long: false)).font(Theme.font(13, .semibold)).foregroundStyle(Theme.secondary)
                    if current {
                        Text(model.s("abierta", "当前")).font(Theme.font(11, .semibold)).foregroundStyle(Theme.accentPlanificar)
                            .padding(.horizontal, 6).padding(.vertical, 1)
                            .background(Capsule().fill(Theme.accentPlanificar.opacity(0.15)))
                    }
                }
                Text(displayTitle(s)).font(Theme.font(15, .semibold)).foregroundStyle(Theme.ink).lineLimit(1)
                Text(s.items.compactMap { model.game($0.gameID)?.icon }.joined(separator: " ")
                     + "  · \(s.items.count) \(model.s("juegos", "个游戏")) · \(s.totalMinutes) min")
                    .font(Theme.font(12)).foregroundStyle(Theme.secondary).lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12).padding(.vertical, 9)
            .background(RoundedRectangle(cornerRadius: 12).fill(on ? Theme.accentPlanificar.opacity(0.12) : Theme.surface))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(on ? Theme.accentPlanificar : Theme.border, lineWidth: on ? 1.5 : 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    // MARK: Detalle

    private func detail(_ s: Session) -> some View {
        let free = s.availableMinutes - s.totalMinutes
        return VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(displayTitle(s)).font(Theme.font(26, .bold)).foregroundStyle(Theme.ink)
                        Text(dateText(s.date, long: true)).font(Theme.font(15)).foregroundStyle(Theme.secondary)
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("\(s.totalMinutes)").font(Theme.font(20, .bold)).foregroundStyle(Theme.ink)
                            Text(model.t("de \(s.availableMinutes) min", "/ \(s.availableMinutes) 分钟")).font(Theme.font(15)).foregroundStyle(Theme.secondary)
                            if free < 0 {
                                Text(model.t("· se pasó \(-free) min", "· 超时 \(-free) 分钟")).font(Theme.font(14, .semibold)).foregroundStyle(Theme.danger)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(model.t("JUEGOS", "游戏")).font(Theme.font(12, .semibold)).tracking(0.7).foregroundStyle(Theme.secondary)
                        if s.items.isEmpty {
                            Text(model.t("Sin juegos", "没有游戏")).font(Theme.font(14)).foregroundStyle(Theme.secondary)
                        }
                        ForEach(Array(s.items.enumerated()), id: \.element.id) { i, item in
                            gameRow(item, index: i)
                        }
                    }

                    if !s.notes.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(model.t("NOTAS", "备注")).font(Theme.font(12, .semibold)).tracking(0.7).foregroundStyle(Theme.secondary)
                            Text(s.notes).font(Theme.font(15)).foregroundStyle(Theme.ink).textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                                .background(RoundedRectangle(cornerRadius: 12).fill(Theme.background))
                        }
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Divider()
            HStack(spacing: 10) {
                Button(role: .destructive) { confirmDelete = true } label: {
                    Label(model.s("Eliminar", "删除"), systemImage: "trash")
                }
                .buttonStyle(PillButtonStyle(color: Theme.danger, filled: false))
                Spacer()
                Button { model.repeatSession(s); dismiss() } label: {
                    Label(model.s("Repetir hoy", "今天重复"), systemImage: "arrow.clockwise")
                }
                .buttonStyle(PillButtonStyle(color: Theme.accentPlanificar, filled: false))
                .help(model.t("Copia de esta sesión con la fecha de hoy", "以今天日期复制这个课程"))
                Button { model.openSession(s); dismiss() } label: {
                    Label(model.s("Abrir", "打开"), systemImage: "square.and.pencil")
                }
                .buttonStyle(PillButtonStyle(color: Theme.accentPlanificar, filled: false))
                .help(model.t("Abrir esta sesión para verla o editarla", "打开这个课程查看或编辑"))
                Button {
                    model.openSession(s); dismiss()
                    play.startSession(model: model)
                } label: {
                    Label(model.s("Jugar", "开始"), systemImage: "play.fill")
                }
                .buttonStyle(PillButtonStyle(color: Theme.ok))
                .disabled(s.items.allSatisfy { model.game($0.gameID) == nil })
            }
            .padding(.horizontal, 20).padding(.vertical, 12)
        }
    }

    private func gameRow(_ item: SessionItem, index: Int) -> some View {
        let g = model.game(item.gameID)
        return HStack(spacing: 10) {
            Rectangle().fill(g?.category.color ?? Theme.border).frame(width: 5)
            Text("\(index + 1)").font(Theme.font(13, .semibold)).foregroundStyle(Theme.secondary).frame(width: 18)
            Text(g?.icon ?? "❔").font(.system(size: 20))
            Group {
                if let g {
                    BiText(g.title, size: 15, weight: .semibold).foregroundStyle(Theme.ink).lineLimit(1)
                } else {
                    Text(model.t("(juego eliminado)", "（游戏已删除）")).font(Theme.font(15)).italic().foregroundStyle(Theme.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text("\(item.minutes)′").font(Theme.font(15, .semibold)).monospacedDigit().foregroundStyle(Theme.ink)
                .padding(.trailing, 12)
        }
        .frame(minHeight: 48)
        .background(Theme.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border))
    }

    // MARK: Utilidades

    private func displayTitle(_ s: Session) -> String {
        s.title.isEmpty ? model.t("Sesión sin título", "未命名课程") : s.title
    }

    private func dateText(_ d: Date, long: Bool) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: model.language == .zh ? "zh_CN" : "es_ES")
        f.setLocalizedDateFormatFromTemplate(long ? "EEEEdMMMMyyyy" : "EEEdMMMyyyy")
        return f.string(from: d).capitalized
    }

    private func deleteSelected() {
        guard let id = selectedID else { return }
        let list = sessions
        let next = list.firstIndex { $0.id == id }.flatMap { i in
            list.indices.contains(i + 1) ? list[i + 1].id : (i > 0 ? list[i - 1].id : nil)
        }
        model.deleteHistory(id)
        selectedID = next
    }
}

import SwiftUI

struct HistoryView: View {
  @EnvironmentObject private var appState: AppState
  @EnvironmentObject private var uiState: ClipViewState
  @ObserveInjection private var inject

  var body: some View {
    VStack(spacing: 0) {
      header

      Divider()

      HSplitView {
        VStack(spacing: 8) {
          Picker("", selection: $uiState.currentTab) {
            Text("History").tag(MainTab.history)
            Text("Favorites").tag(MainTab.favorites)
            Text("Trash").tag(MainTab.trash)
          }
          .pickerStyle(.segmented)
          .padding(.horizontal, 6)

          HistoryListView()

          sidebarFooter
        }
        .padding(.bottom, 6)
        .frame(minWidth: 240, idealWidth: 420, maxWidth: .infinity, maxHeight: .infinity)

        PreviewPaneView()
          .frame(minWidth: 320, idealWidth: 560, maxWidth: .infinity, maxHeight: .infinity)
      }
    }
    .frame(minWidth: 700, minHeight: 460)
    .background(PopupEventMonitorView { event in
      switch event.type {
      case .keyDown:
        return appState.handlePopupKeyDown(event)
      case .leftMouseDown:
        return appState.handlePopupMouseDown(event)
      default:
        return event
      }
    })
    .onAppear {
      uiState.normalizeSelection()
    }
    .onChange(of: uiState.currentTab) { _, _ in
      uiState.normalizeSelection()
    }
    .onChange(of: uiState.kindFilter) { _, _ in
      uiState.normalizeSelection()
    }
    .enableInjection()
  }

  private var header: some View {
    HStack(spacing: 10) {
      SearchBarView()

      HStack(spacing: 6) {
        Picker("Type", selection: $uiState.kindFilter) {
          ForEach(ClipKindFilter.allCases, id: \.self) { filter in
            Text(filter.title).tag(filter)
          }
        }
        .pickerStyle(.menu)
        .frame(width: 120)

        if uiState.kindFilter != .all {
          Button {
            uiState.kindFilter = .all
          } label: {
            Image(systemName: "xmark.circle.fill")
              .foregroundStyle(.secondary)
          }
          .buttonStyle(.plain)
        }
      }
    }
    .padding(.horizontal, 12)
    .padding(.top, 10)
    .padding(.bottom, 10)
  }

  private var sidebarFooter: some View {
    HStack(spacing: 8) {
      Button {
        uiState.setVisibleChecked(!uiState.allVisibleChecked)
      } label: {
        Image(systemName: uiState.visibleCheckedState.iconName)
          .foregroundStyle(uiState.checkedVisibleCount > 0 ? Color.accentColor : Color.secondary)
      }

      Text("\(uiState.checkedVisibleCount)")
        .font(.caption)
        .foregroundStyle(.secondary)
        .frame(minWidth: 18, alignment: .leading)

      if uiState.currentTab == .trash {
        Button("Restore") {
          appState.restoreSelection()
        }
        .disabled(uiState.selectedIDs.isEmpty)
      }

      Button(uiState.currentTab == .trash ? "Delete Checked" : "Trash Checked") {
        appState.deleteCheckedVisible(permanently: uiState.currentTab == .trash)
      }
      .disabled(uiState.checkedVisibleCount == 0)

      Button("Reverse") {
        appState.reverseSelection()
      }
      .disabled(uiState.selectedItems.count < 2)

      Button(uiState.currentTab == .trash ? "Delete" : "Trash") {
        appState.deleteSelection(permanently: uiState.currentTab == .trash)
      }
      .disabled(uiState.selectedIDs.isEmpty)

      Spacer()

      Menu("More") {
        if uiState.checkedVisibleCount > 0 {
          Button("Clear Visible Checks") {
            uiState.clearCheckedVisible()
          }
        }
        Button("Settings") {
          appState.openSettings()
        }
        Button("Clear All") {
          appState.clearAll()
        }
      }
    }
    .buttonStyle(.borderless)
    .font(.caption)
    .padding(.horizontal, 6)
    .padding(.top, 4)
  }
}

private struct PopupEventMonitorView: NSViewRepresentable {
  let handler: (NSEvent) -> NSEvent?

  func makeNSView(context: Context) -> NSView {
    let view = NSView(frame: .zero)
    context.coordinator.start(handler: handler)
    return view
  }

  func updateNSView(_ nsView: NSView, context: Context) {
    context.coordinator.handler = handler
  }

  func makeCoordinator() -> Coordinator {
    Coordinator()
  }

  static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
    coordinator.stop()
  }

  final class Coordinator {
    var monitor: Any?
    var handler: ((NSEvent) -> NSEvent?)?

    func start(handler: @escaping (NSEvent) -> NSEvent?) {
      self.handler = handler
      stop()
      monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .leftMouseDown]) { [weak self] event in
        self?.handler?(event) ?? event
      }
    }

    func stop() {
      if let monitor {
        NSEvent.removeMonitor(monitor)
        self.monitor = nil
      }
    }
  }
}

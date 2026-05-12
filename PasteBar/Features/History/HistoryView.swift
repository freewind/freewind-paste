import SwiftUI

struct HistoryView: View {
  @EnvironmentObject private var appState: AppState
  @EnvironmentObject private var store: ClipStore

  var body: some View {
    VStack(spacing: 0) {
      header

      Divider()

      NavigationSplitView {
        VStack(spacing: 8) {
          Picker("", selection: $store.currentTab) {
            Text("History").tag(MainTab.history)
            Text("Favorites").tag(MainTab.favorites)
            Text("Trash").tag(MainTab.trash)
          }
          .pickerStyle(.segmented)

          HistoryListView()

          sidebarFooter
        }
        .padding(.horizontal, 6)
        .padding(.bottom, 6)
        .frame(minWidth: 360, idealWidth: 420, maxWidth: 460, maxHeight: .infinity)
      } detail: {
        PreviewPaneView()
      }
    }
    .frame(minWidth: 960, minHeight: 620)
    .navigationSplitViewColumnWidth(min: 360, ideal: 420, max: 460)
    .background(PopupKeyMonitorView { event in
      appState.handlePopupKeyDown(event)
    })
    .onAppear {
      store.normalizeSelection()
    }
    .onChange(of: store.currentTab) { _, _ in
      store.normalizeSelection()
    }
    .onChange(of: store.kindFilter) { _, _ in
      store.normalizeSelection()
    }
  }

  private var header: some View {
    HStack(spacing: 10) {
      SearchBarView()

      Picker("Type", selection: $store.kindFilter) {
        ForEach(ClipKindFilter.allCases, id: \.self) { filter in
          Text(filter.title).tag(filter)
        }
      }
      .pickerStyle(.menu)
      .frame(width: 120)
    }
    .padding(.horizontal, 12)
    .padding(.top, 10)
    .padding(.bottom, 10)
  }

  private var sidebarFooter: some View {
    HStack(spacing: 8) {
      Button {
        store.setVisibleChecked(!store.allVisibleChecked)
      } label: {
        Image(systemName: store.visibleCheckedState.iconName)
          .foregroundStyle(store.checkedVisibleCount > 0 ? Color.accentColor : Color.secondary)
      }

      Text("\(store.checkedVisibleCount)")
        .font(.caption)
        .foregroundStyle(.secondary)
        .frame(minWidth: 18, alignment: .leading)

      if store.currentTab == .trash {
        Button("Restore") {
          appState.restoreSelection()
        }
        .disabled(store.selectedIDs.isEmpty)
      }

      Button(store.currentTab == .trash ? "Delete Checked" : "Trash Checked") {
        appState.deleteCheckedVisible(permanently: store.currentTab == .trash)
      }
      .disabled(store.checkedVisibleCount == 0)

      Button("Reverse") {
        store.reverseSelection()
        appState.persistItems()
      }
      .disabled(store.selectedItems.count < 2)

      Button(store.currentTab == .trash ? "Delete" : "Trash") {
        appState.deleteSelection(permanently: store.currentTab == .trash)
      }
      .disabled(store.selectedIDs.isEmpty)

      Spacer()

      Menu("More") {
        if store.checkedVisibleCount > 0 {
          Button("Clear Visible Checks") {
            store.clearCheckedVisible()
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
    .padding(.top, 4)
  }
}

private struct PopupKeyMonitorView: NSViewRepresentable {
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
      monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
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

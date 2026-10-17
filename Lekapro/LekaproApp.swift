import SwiftUI

@main
struct LekaproApp: App {
    @StateObject private var store = ProfileStore()
    @StateObject private var workspace = BrowserWorkspace()
    @Environment(\.scenePhase) private var scenePhase
    var body: some Scene {
        WindowGroup {
            TabView {
                ProfileListView().tabItem { Label("Hồ sơ", systemImage: "square.stack.3d.up") }
                ProxyListView().tabItem { Label("Proxy", systemImage: "network") }
                SettingsView().tabItem { Label("Cài đặt", systemImage: "gearshape") }
            }
            .tint(.mint)
            .environmentObject(store)
            .environmentObject(workspace)
            .task {
                await DeviceDiagnostics.runOnce()
                await DeviceNetworkDiagnostics.runIfRequested(store: store, workspace: workspace)
                DevicePageDiagnostics.startIfRequested(store: store, workspace: workspace)
            }
            .fullScreenCover(item: $workspace.diagnosticSession) {
                BrowserView(session: $0).environmentObject(store).environmentObject(workspace)
            }
            .alert("Thông báo", isPresented: Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })) {
                Button("Đóng") { store.errorMessage = nil }
            } message: { Text(store.errorMessage ?? "") }
            .onChange(of: scenePhase) { phase in if phase != .active { workspace.persistAll() } }
        }
    }
}

extension BrowserProfile {
    var tint: Color {
        switch color {
        case "blue": return .blue
        case "purple": return .purple
        case "orange": return .orange
        case "pink": return .pink
        default: return .mint
        }
    }
}

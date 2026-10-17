import SwiftUI

// Label-based controls retain iOS 16 compatibility; the equivalent convenience
// initializers and ContentUnavailableView require iOS 17.
struct ActionButton: View {
    let title: String
    let systemImage: String
    let role: ButtonRole?
    let action: () -> Void
    init(_ title: String, systemImage: String, role: ButtonRole? = nil, action: @escaping () -> Void) {
        self.title = title; self.systemImage = systemImage; self.role = role; self.action = action
    }
    var body: some View { Button(role: role, action: action) { Label(title, systemImage: systemImage) } }
}

struct EmptyStateView: View {
    let title: String
    let systemImage: String
    let description: Text?
    init(_ title: String, systemImage: String, description: Text? = nil) {
        self.title = title; self.systemImage = systemImage; self.description = description
    }
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage).font(.system(size: 40)).foregroundStyle(.secondary)
            Text(title).font(.title3.bold())
            if let description { description.font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center) }
        }.frame(maxWidth: .infinity).padding(.vertical, 32)
    }
}

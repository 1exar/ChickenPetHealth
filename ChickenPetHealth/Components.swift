//
//  Components.swift
//  ChickenPetHealth
//

import SwiftUI

struct EmptyStateView: View {
    let title: String
    let subtitle: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "feather")
                .font(.largeTitle)
                .foregroundStyle(Theme.accent)
            Text(title)
                .font(.headline)
            Text(subtitle)
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundColor(Theme.mutedText(for: colorScheme))
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 20).fill(Theme.overlay(for: colorScheme)))
    }
}

struct StatusBadge: View {
    let status: HealthStatus

    var body: some View {
        Text(status.rawValue)
            .font(.caption2.bold())
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 14).fill(color.opacity(0.18)))
            .foregroundColor(color)
    }

    private var color: Color {
        switch status {
        case .healthy: return Theme.accent
        case .monitoring: return .yellow
        case .sick: return Theme.warning
        }
    }
}

struct Tag: View {
    let label: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Text(label)
            .font(.caption2)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 10).stroke(Theme.mutedText(for: colorScheme).opacity(0.5)))
    }
}

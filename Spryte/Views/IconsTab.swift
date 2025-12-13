//
//  IconsTab.swift
//  Spryte
//
//  Created by John Evans on 12/13/25.
//

import SwiftUI

struct IconsTab: View {
    @Binding var appearanceMode: AppearanceMode
    @State private var iconManager = IconManager()

    private let columns = [
        GridItem(.adaptive(minimum: 100, maximum: 140), spacing: 16)
    ]

    var body: some View {
        NavigationStack {
            Group {
                if iconManager.icons.isEmpty {
                    VStack(spacing: 16) {
                        ContentUnavailableView(
                            "No Icons Found",
                            systemImage: "app.dashed",
                            description: Text("Add icon export folders to the project.\nFiles should follow the pattern: {Name}-iOS-{Style}-1024x1024@1x.png")
                        )

                        // Debug info
                        if !iconManager.debugInfo.isEmpty {
                            Text(iconManager.debugInfo)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .padding()
                                .background(.quaternary)
                                .cornerRadius(8)
                                .padding(.horizontal)
                        }
                    }
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 20) {
                            ForEach(iconManager.icons) { icon in
                                IconGridItem(
                                    icon: icon,
                                    style: iconManager.selectedStyle,
                                    isSelected: iconManager.isSelected(icon),
                                    isLoading: iconManager.isChangingIcon && iconManager.isSelected(icon)
                                )
                                .onTapGesture {
                                    iconManager.setIcon(icon)
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("App Icons")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("Appearance", selection: $appearanceMode) {
                            ForEach(AppearanceMode.allCases) { mode in
                                Label(mode.displayName, systemImage: mode.icon).tag(mode)
                            }
                        }
                    } label: {
                        Image(systemName: appearanceMode.icon)
                    }
                }

                ToolbarSpacer(.fixed, placement: .topBarTrailing)

                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("Style", selection: $iconManager.selectedStyle) {
                            ForEach(IconStyle.allCases) { style in
                                Text(style.displayName).tag(style)
                            }
                        }
                    } label: {
                        Text(iconManager.selectedStyle.displayName)
                    }
                }
            }
        }
        .alert("Error", isPresented: .init(
            get: { iconManager.errorMessage != nil },
            set: { if !$0 { iconManager.errorMessage = nil } }
        )) {
            Button("OK") { iconManager.errorMessage = nil }
        } message: {
            Text(iconManager.errorMessage ?? "")
        }
    }
}

struct IconGridItem: View {
    let icon: IconItem
    let style: IconStyle
    let isSelected: Bool
    let isLoading: Bool

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                // Icon preview from file
                // iOS 26 Icon Composer exports already include the rounded shape
                if let uiImage = icon.previewImage(for: style) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(1, contentMode: .fit)
                        .frame(width: 72, height: 72)
                } else {
                    // Fallback placeholder
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.quaternary)
                        .frame(width: 72, height: 72)
                        .overlay {
                            Image(systemName: "questionmark")
                                .foregroundStyle(.secondary)
                        }
                }

                // Loading indicator
                if isLoading {
                    Color.black.opacity(0.3)
                        .frame(width: 72, height: 72)
                    ProgressView()
                        .tint(.white)
                }
            }
            .frame(width: 72, height: 72)

            // Name with checkmark if selected
            HStack(spacing: 4) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                }
                Text(icon.name)
                    .font(.caption2)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .frame(width: 110, height: 32, alignment: .top)
        }
        .contentShape(Rectangle())
    }
}

#Preview {
    IconsTab(appearanceMode: .constant(.system))
}

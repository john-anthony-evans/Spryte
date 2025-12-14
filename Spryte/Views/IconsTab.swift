//
//  IconsTab.swift
//  Spryte
//
//  Created by John Evans on 12/13/25.
//

import SwiftUI

extension Color: @retroactive RawRepresentable {
    public init?(rawValue: String) {
        guard let data = Data(base64Encoded: rawValue),
              let uiColor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: UIColor.self, from: data) else {
            return nil
        }
        self = Color(uiColor)
    }

    public var rawValue: String {
        guard let data = try? NSKeyedArchiver.archivedData(withRootObject: UIColor(self), requiringSecureCoding: false) else {
            return ""
        }
        return data.base64EncodedString()
    }

    var isDark: Bool {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0
        UIColor(self).getRed(&red, green: &green, blue: &blue, alpha: nil)
        let luminance = 0.299 * red + 0.587 * green + 0.114 * blue
        return luminance < 0.5
    }
}

struct IconsTab: View {
    @Binding var appearanceMode: AppearanceMode
    @State private var iconManager = IconManager()
    @AppStorage("backgroundColor") private var backgroundColor: Color = .white
    @State private var searchText = ""

    private let columns = [
        GridItem(.adaptive(minimum: 120, maximum: 160), spacing: 16)
    ]

    var body: some View {
        NavigationStack {
            Group {
                if iconManager.sections.isEmpty {
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
                        LazyVStack(alignment: .leading, spacing: 24) {
                            ForEach(iconManager.filteredSections(searchText: searchText)) { section in
                                VStack(alignment: .leading, spacing: 12) {
                                    Text(section.name)
                                        .font(.headline)
                                        .foregroundStyle(backgroundColor.isDark ? .white : .primary)
                                        .padding(.horizontal)

                                    LazyVGrid(columns: columns, spacing: 20) {
                                        ForEach(section.icons) { icon in
                                            IconGridItem(
                                                icon: icon,
                                                style: iconManager.selectedStyle,
                                                isSelected: iconManager.isSelected(icon),
                                                isLoading: iconManager.isChangingIcon && iconManager.isSelected(icon),
                                                backgroundColor: backgroundColor
                                            )
                                            .onTapGesture {
                                                iconManager.setIcon(icon)
                                            }
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }
                        }
                        .padding(.vertical)
                    }
                }
            }
            .background(backgroundColor)
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Find icon...")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Select an App Icon")
                        .font(.headline)
                        .padding(8)
                        .glassEffect()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    ColorPicker("Background", selection: $backgroundColor, supportsOpacity: false)
                        .labelsHidden()
                }

                // ToolbarItem(placement: .topBarTrailing) {
                //     Menu {
                //         Picker("Appearance", selection: $appearanceMode) {
                //             ForEach(AppearanceMode.allCases) { mode in
                //                 Label(mode.displayName, systemImage: mode.icon).tag(mode)
                //             }
                //         }
                //     } label: {
                //         Image(systemName: appearanceMode.icon)
                //     }
                // }

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
    let backgroundColor: Color

    var body: some View {
        VStack(alignment: .center, spacing: 8) {
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
                Text(icon.displayName)
                    .font(.caption2)
                    .lineLimit(3)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .glassEffect()
            .frame(maxWidth: 130, minHeight: 52, alignment: .top)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .contentShape(Rectangle())
    }
}

#Preview {
    IconsTab(appearanceMode: .constant(.system))
}

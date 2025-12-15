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
    @AppStorage("iconScale") private var iconScale: Double = -1 // -1 means use default

    @State private var searchText = ""
    @State private var showScalePopover = false
    @State private var contentWidth: CGFloat = 0

    // Grid layout constants
    private let baseColumnSize: CGFloat = 80
    private let columnSpacing: CGFloat = 12
    private let horizontalPadding: CGFloat = 32 // 16 on each side

    private var effectiveScale: Double {
        iconScale < 0 ? scaleForColumns(3) : iconScale
    }

    private var columns: [GridItem] {
        let scaledMin = baseColumnSize * effectiveScale
        let scaledMax = scaledMin + 20
        return [GridItem(.adaptive(minimum: scaledMin, maximum: scaledMax), spacing: columnSpacing)]
    }

    /// Calculate the scale value needed for N icons per row
    private func scaleForColumns(_ n: Int) -> Double {
        guard contentWidth > 0, n > 0 else { return 1.0 }
        let availableWidth = contentWidth - horizontalPadding
        // availableWidth = n * (baseColumnSize * scale) + (n - 1) * spacing
        // scale = (availableWidth - (n - 1) * spacing) / (n * baseColumnSize)
        let scale = (availableWidth - CGFloat(n - 1) * columnSpacing) / (CGFloat(n) * baseColumnSize)
        return max(0.5, Double(scale))
    }

    /// Detent scale values for haptic feedback
    private var scaleDetents: [Double] {
        [
            scaleForColumns(3),  // 3 per row (default)
            scaleForColumns(2),  // 2 per row
            scaleForColumns(1)   // 1 per row
        ]
    }

    private func isNearDetent(_ value: Double) -> Bool {
        scaleDetents.contains { abs($0 - value) < 0.03 }
    }

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
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(backgroundColor)
                } else {
                    GeometryReader { geometry in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 24) {
                                ForEach(iconManager.filteredSections(searchText: searchText)) { section in
                                    VStack(alignment: .leading, spacing: 12) {
                                        Text(section.name)
                                            .font(.title2).fontWeight(.bold)
                                            .foregroundStyle(backgroundColor.isDark ? .white : .primary)
                                            .padding(.horizontal)

                                        LazyVGrid(columns: columns, spacing: 20) {
                                            ForEach(section.icons) { icon in
                                                IconGridItem(
                                                    icon: icon,
                                                    style: iconManager.selectedStyle,
                                                    isSelected: iconManager.isSelected(icon),
                                                    isLoading: iconManager.isChangingTo(icon),
                                                    backgroundColor: backgroundColor,
                                                    iconScale: effectiveScale
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
                        .background(backgroundColor)
                        .onAppear {
                            contentWidth = geometry.size.width
                            // Set default scale for 3 columns if not yet set
                            if iconScale < 0 {
                                iconScale = scaleForColumns(3)
                            }
                        }
                        .onChange(of: geometry.size.width) { _, newWidth in
                            contentWidth = newWidth
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Find icon...")
            .toolbar {
                if iconManager.selectedStyle != .default || !isNearDetent(effectiveScale) || backgroundColor.rawValue != Color.white.rawValue {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            // Reset to defaults
                            iconScale = scaleForColumns(3)
                            backgroundColor = .white
                            iconManager.selectedStyle = .default
                            searchText = ""
                        } label: {
                            Image(systemName: "arrow.uturn.backward.circle")
                        }
                    }
                }
                ToolbarSpacer(.fixed, placement: .topBarTrailing)
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showScalePopover.toggle()
                    } label: {
//                        Image(systemName: "circle.dotted.circle")
                        Image(systemName: "arrow.down.backward.and.arrow.up.forward.circle")
                        
                    }
                    .popover(isPresented: $showScalePopover) {
                        VStack(spacing: 12) {
                            Text("Icon Size")
                                .font(.headline)
                            Slider(value: $iconScale, in: 0.5...5.0, step: 0.05)
                                .frame(width: 250)
                                .onChange(of: iconScale) { _, newValue in
                                    if isNearDetent(newValue) {
                                        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                                    } else {
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    }
                                }
                            Text("\(Int(effectiveScale * 100))%")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                        .presentationCompactAdaptation(.popover)
                        .onAppear {
                            // Initialize slider to calculated default if not yet set
                            if iconScale < 0 {
                                iconScale = scaleForColumns(3)
                            }
                        }
                    }
                }
                ToolbarSpacer(.fixed, placement: .topBarTrailing)
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
    let iconScale: Double

    private var iconSize: CGFloat {
        60 * iconScale
    }

    /// iOS app icon corner radius ~22% of icon size with continuous corners
    private var iconCornerRadius: CGFloat {
        iconSize * 0.22
    }

    var body: some View {
        VStack(alignment: .center, spacing: 8) {
            ZStack {
                // Icon preview from file
                // iOS 26 Icon Composer exports already include the rounded shape
                if let uiImage = icon.previewImage(for: style) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(1, contentMode: .fit)
                        .frame(width: iconSize, height: iconSize)
                } else {
                    // Fallback placeholder
                    RoundedRectangle(cornerRadius: `iconCornerRadius`, style: .continuous)
                        .fill(.quaternary)
                        .frame(width: iconSize, height: iconSize)
                        .overlay {
                            Image(systemName: "questionmark")
                                .foregroundStyle(.secondary)
                        }
                }

                // Loading indicator
                if isLoading {
                    RoundedRectangle(cornerRadius: iconCornerRadius, style: .continuous)
                        .fill(Color.black.opacity(0.3))
                        .frame(width: iconSize, height: iconSize)
                    ProgressView()
                        .tint(.white)
                }
            }
            .frame(width: iconSize, height: iconSize)

            // Name with checkmark if selected
            HStack(spacing: 4) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(Color.accentColor)
                }
                Text(icon.displayName)
                    .font(.caption).fontWeight(.semibold)
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

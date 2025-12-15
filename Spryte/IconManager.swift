//
//  IconManager.swift
//  Spryte
//
//  Created by John Evans on 12/13/25.
//

import SwiftUI

enum IconStyle: String, CaseIterable, Identifiable {
    case `default` = "Default"
    case dark = "Dark"
    case clearLight = "ClearLight"
    case clearDark = "ClearDark"
    case tintedLight = "TintedLight"
    case tintedDark = "TintedDark"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .default: return "Light Mode"
        case .dark: return "Dark Mode"
        case .clearLight: return "Clear Light"
        case .clearDark: return "Clear Dark"
        case .tintedLight: return "Tinted Light"
        case .tintedDark: return "Tinted Dark"
        }
    }
}

struct IconItem: Identifiable, Hashable {
    let id: String
    let name: String
    // Maps style to the file URL for that style's preview
    let previewURLs: [IconStyle: URL]

    /// User-friendly display name (hyphens replaced with spaces)
    var displayName: String {
        name.replacingOccurrences(of: "-", with: " ")
    }

    func previewImage(for style: IconStyle) -> UIImage? {
        guard let url = previewURLs[style] else { return nil }
        return UIImage(contentsOfFile: url.path)
    }
}

struct IconSection: Identifiable {
    let id: String
    let name: String
    var icons: [IconItem]
}

@Observable
@MainActor
final class IconManager {
    var icons: [IconItem] = []
    var sections: [IconSection] = []
    var currentIconName: String?
    var selectedStyle: IconStyle = .default
    var isChangingIcon = false
    var changingToIconName: String?
    var errorMessage: String?
    var debugInfo: String = ""

    // The primary app icon name (set in Build Settings > ASSETCATALOG_COMPILER_APPICON_NAME)
    // This icon requires nil when calling setAlternateIconName
    private let primaryIconName = "Spryte"

    init() {
        currentIconName = UIApplication.shared.alternateIconName
        loadAvailableIcons()
    }

    private func loadManifest() -> [[String: Any]]? {
        guard let manifestURL = Bundle.main.url(forResource: "icons_manifest", withExtension: "json"),
              let data = try? Data(contentsOf: manifestURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let sections = json["sections"] as? [[String: Any]] else {
            return nil
        }
        return sections
    }

    func loadAvailableIcons() {
        icons = []
        debugInfo = ""

        guard let bundleURL = Bundle.main.resourceURL else {
            debugInfo = "Could not find bundle resource URL"
            return
        }

        // Group files by icon name
        var iconFiles: [String: [IconStyle: URL]] = [:]

        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: bundleURL,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )

            // Scan bundle root for PNG files matching pattern: {Name}-iOS-{Style}-2048x2048@1x.png
            for fileURL in contents {
                let fileName = fileURL.lastPathComponent

                guard fileName.hasSuffix("-2048x2048@1x.png"),
                      fileName.contains("-iOS-") else {
                    continue
                }

                // Parse the filename: {Name}-iOS-{Style}-2048x2048@1x.png
                let withoutSuffix = fileName.replacingOccurrences(of: "-2048x2048@1x.png", with: "")
                let parts = withoutSuffix.components(separatedBy: "-iOS-")

                guard parts.count == 2 else { continue }

                let iconName = parts[0]
                let styleString = parts[1]

                // Find matching style
                guard let style = IconStyle.allCases.first(where: { $0.rawValue == styleString }) else {
                    continue
                }

                if iconFiles[iconName] == nil {
                    iconFiles[iconName] = [:]
                }
                iconFiles[iconName]?[style] = fileURL
            }

            // Create IconItems from grouped files
            for (name, urls) in iconFiles {
                let icon = IconItem(
                    id: name,
                    name: name,
                    previewURLs: urls
                )
                icons.append(icon)
            }

            icons.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

            // Build sections from manifest
            buildSections()

            debugInfo = "Found \(icons.count) icon(s) in \(sections.count) section(s)"
            print("IconManager: \(debugInfo)")
            print("IconManager: Loaded icons: \(icons.map { $0.name })")

        } catch {
            debugInfo = "Error scanning bundle: \(error.localizedDescription)"
        }
    }

    private func buildSections() {
        sections = []

        // Create a lookup dictionary for icons by name
        let iconsByName = Dictionary(uniqueKeysWithValues: icons.map { ($0.name, $0) })

        if let manifestSections = loadManifest() {
            // Build sections from manifest
            for sectionData in manifestSections {
                guard let name = sectionData["name"] as? String,
                      let iconNames = sectionData["icons"] as? [String] else {
                    continue
                }

                let sectionIcons = iconNames.compactMap { iconsByName[$0] }
                if !sectionIcons.isEmpty {
                    sections.append(IconSection(
                        id: name,
                        name: name,
                        icons: sectionIcons
                    ))
                }
            }

            // Add any icons not in manifest to "Other" section
            let manifestedIconNames = Set(manifestSections.flatMap { ($0["icons"] as? [String]) ?? [] })
            let unmanifestedIcons = icons.filter { !manifestedIconNames.contains($0.name) }
            if !unmanifestedIcons.isEmpty {
                sections.append(IconSection(
                    id: "Other",
                    name: "Other",
                    icons: unmanifestedIcons
                ))
            }
        } else {
            // No manifest - put all icons in a single section
            if !icons.isEmpty {
                sections.append(IconSection(
                    id: "All Icons",
                    name: "All Icons",
                    icons: icons
                ))
            }
        }
    }

    func setIcon(_ icon: IconItem) {
        guard !isChangingIcon else { return }

        // Don't change if already selected
        if isSelected(icon) { return }

        isChangingIcon = true
        changingToIconName = icon.name
        errorMessage = nil

        // Primary icon requires nil, alternate icons use their name
        let iconNameToSet: String? = (icon.name == primaryIconName) ? nil : icon.name

        // Debug logging before setting icon
        print(String(repeating: "=", count: 60))
        print("🔄 ICON CHANGE DEBUG INFO")
        print(String(repeating: "=", count: 60))
        print("Icon item name (from UI): \(icon.name)")
        print("Icon item ID: \(icon.id)")
        print("Name to pass to setAlternateIconName: \(iconNameToSet ?? "nil (primary icon)")")
        print("Primary icon name: \(primaryIconName)")
        print("Current alternate icon: \(UIApplication.shared.alternateIconName ?? "nil")")

        // List all preview URLs for this icon
        print("\nPreview URLs for this icon:")
        for (style, url) in icon.previewURLs {
            print("  - \(style.rawValue): \(url.lastPathComponent)")
        }

        // List all .icon bundles in the app bundle
        let iconBundles = Bundle.main.paths(forResourcesOfType: "icon", inDirectory: nil)
        print("\nAll .icon bundles in app bundle (\(iconBundles.count) found):")
        for path in iconBundles.sorted() {
            let filename = (path as NSString).lastPathComponent
            print("  - \(filename)")
        }

        // Check if this specific icon exists in bundle
        if let iconNameToSet = iconNameToSet {
            let iconPath = Bundle.main.path(forResource: iconNameToSet, ofType: "icon")
            print("\nBundle.main.path(forResource: \"\(iconNameToSet)\", ofType: \"icon\"):")
            print("  -> \(iconPath ?? "NOT FOUND")")
        }

        // Also check supportsAlternateIcons
        print("\nUIApplication.shared.supportsAlternateIcons: \(UIApplication.shared.supportsAlternateIcons)")
        print(String(repeating: "=", count: 60))

        // Use the completion handler version for better compatibility
        UIApplication.shared.setAlternateIconName(iconNameToSet) { [weak self] error in
            DispatchQueue.main.async {
                guard let self else { return }

                if let error = error {
                    let nsError = error as NSError
                    self.errorMessage = "\(error.localizedDescription)\n\nIcon: \(iconNameToSet ?? "nil (primary)")\nCode: \(nsError.code)"
                    print("Icon change failed: \(nsError)")
                } else {
                    self.currentIconName = iconNameToSet
                }

                self.isChangingIcon = false
                self.changingToIconName = nil
            }
        }
    }

    func isSelected(_ icon: IconItem) -> Bool {
        // Primary icon is selected when currentIconName is nil
        if icon.name == primaryIconName {
            return currentIconName == nil
        }
        return icon.name == currentIconName
    }

    func isChangingTo(_ icon: IconItem) -> Bool {
        return isChangingIcon && icon.name == changingToIconName
    }

    func filteredSections(searchText: String) -> [IconSection] {
        guard !searchText.isEmpty else { return sections }

        let lowercasedSearch = searchText.lowercased()

        return sections.compactMap { section in
            // If section name matches, include all icons in that section
            if section.name.lowercased().contains(lowercasedSearch) {
                return section
            }

            // Otherwise, filter icons by name
            let matchingIcons = section.icons.filter { icon in
                icon.name.lowercased().contains(lowercasedSearch)
            }

            // Only include section if it has matching icons
            guard !matchingIcons.isEmpty else { return nil }

            return IconSection(id: section.id, name: section.name, icons: matchingIcons)
        }
    }
}

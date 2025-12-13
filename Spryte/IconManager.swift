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
        case .default: return "Default"
        case .dark: return "Dark"
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

    func previewImage(for style: IconStyle) -> UIImage? {
        guard let url = previewURLs[style] else { return nil }
        return UIImage(contentsOfFile: url.path)
    }
}

@Observable
@MainActor
final class IconManager {
    var icons: [IconItem] = []
    var currentIconName: String?
    var selectedStyle: IconStyle = .default
    var isChangingIcon = false
    var errorMessage: String?
    var debugInfo: String = ""

    // The primary app icon name (set in Build Settings > ASSETCATALOG_COMPILER_APPICON_NAME)
    // This icon requires nil when calling setAlternateIconName
    private let primaryIconName = "Spryte"

    init() {
        currentIconName = UIApplication.shared.alternateIconName
        loadAvailableIcons()
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

            // Scan bundle root for PNG files matching pattern: {Name}-iOS-{Style}-1024x1024@1x.png
            for fileURL in contents {
                let fileName = fileURL.lastPathComponent

                guard fileName.hasSuffix("-1024x1024@1x.png"),
                      fileName.contains("-iOS-") else {
                    continue
                }

                // Parse the filename: {Name}-iOS-{Style}-1024x1024@1x.png
                let withoutSuffix = fileName.replacingOccurrences(of: "-1024x1024@1x.png", with: "")
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

            debugInfo = "Found \(icons.count) icon(s)"
            print("IconManager: \(debugInfo)")
            print("IconManager: Loaded icons: \(icons.map { $0.name })")

        } catch {
            debugInfo = "Error scanning bundle: \(error.localizedDescription)"
        }
    }

    func setIcon(_ icon: IconItem) {
        guard !isChangingIcon else { return }

        // Don't change if already selected
        if isSelected(icon) { return }

        isChangingIcon = true
        errorMessage = nil

        // Primary icon requires nil, alternate icons use their name
        let iconNameToSet: String? = (icon.name == primaryIconName) ? nil : icon.name

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
}

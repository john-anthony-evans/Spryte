//
//  OnboardingView.swift
//  Spryte
//
//  Created by John Evans on 12/15/25.
//

import SwiftUI

struct OnboardingView: View {
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // App Icon - load from exported preview PNG
            AppIconImage(size: 120)
                .shadow(color: .black.opacity(0.15), radius: 12, y: 6)
                .padding(.bottom, 24)

            // Title
            Text("Welcome to Spryte")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.bottom, 32)

            // Features
            VStack(alignment: .leading, spacing: 24) {
                FeatureRow(
                    icon: "app.grid",
                    iconColor: .accent,
                    title: "Browse App Icons",
                    description: "In order to review an icon with the glass effect fully applied on your Home Screen, pick one from the library and tap to set it so you can preview how it really looks in place."
                )

                FeatureRow(
                    icon: "circle.lefthalf.filled.righthalf.striped.horizontal.inverse",
                    iconColor: .accent,
                    title: "Multiple Styles",
                    description: "Preview icons in Light, Dark, Clear, and Tinted modes."
                )

                FeatureRow(
                    icon: "swatchpalette",
                    iconColor: .accent,
                    title: "Customize Preview",
                    description: "Adjust background color and icon size to test how icons look in different contexts."
                )

                FeatureRow(
                    icon: "app.background.dotted",
                    iconColor: .accent,
                    title: "Splash Screen Preview",
                    description: "Preview splash screens in light and dark modes."
                )
            }
            .padding(.horizontal, 24)

            Spacer()
            Spacer()

            // Continue Button
            Button {
                isPresented = false
            } label: {
                Text("Continue")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(.accent, in: Capsule())
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 20)
        }
        .background(Color(.systemBackground))
    }
}

struct FeatureRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(iconColor)
                .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body)
                    .fontWeight(.semibold)

                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// Displays the app's icon from exported preview PNGs
struct AppIconImage: View {
    let size: CGFloat
    @Environment(\.colorScheme) private var colorScheme

    private var iconImage: UIImage? {
        // Try to load Spryte icon preview, fallback to Default
        let style = colorScheme == .dark ? "Dark" : "Default"
        let iconNames = ["Spryte", "Default"]

        for name in iconNames {
            if let url = Bundle.main.url(forResource: "\(name)-iOS-\(style)-2048x2048@1x", withExtension: "png"),
               let image = UIImage(contentsOfFile: url.path) {
                return image
            }
            // Try default style as fallback
            if let url = Bundle.main.url(forResource: "\(name)-iOS-Default-2048x2048@1x", withExtension: "png"),
               let image = UIImage(contentsOfFile: url.path) {
                return image
            }
        }
        return nil
    }

    var body: some View {
        if let image = iconImage {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
        } else {
            // Fallback placeholder
            RoundedRectangle(cornerRadius: size * 0.44, style: .continuous)
                .fill(.accent.gradient)
                .frame(width: size, height: size)
                .overlay {
                    Image(systemName: "app.gift.fill")
                        .font(.system(size: size * 0.5))
                        .foregroundStyle(.white)
                }
        }
    }
}

#Preview {
    OnboardingView(isPresented: .constant(true))
}

//
//  SplashTab.swift
//  Spryte
//
//  Created by John Evans on 12/13/25.
//

import SwiftUI

struct SplashTab: View {
    @Binding var isUIHidden: Bool
    @State private var currentIndex = 0
    @State private var splashImages: [UIImage] = []

    // Folder name in the app bundle containing splash screen images
    private let splashFolderName = "Splash Screens"

    var body: some View {
        NavigationStack {
            ZStack {
                if splashImages.isEmpty {
                    ContentUnavailableView(
                        "No Splash Screens",
                        systemImage: "app.background.dotted",
                        description: Text("Add a \"Splash Screens\" folder to the project with PNG images.")
                    )
                } else {
                    // Paging TabView for horizontal swiping
                    TabView(selection: $currentIndex) {
                        ForEach(Array(splashImages.enumerated()), id: \.offset) { index, image in
                            SplashScreenImage(image: image)
                                .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: isUIHidden ? .never : .automatic))
                    .ignoresSafeArea()

                    // Tap gesture layer
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                isUIHidden.toggle()
                            }
                        }
                }
            }
            .background(Color.black)
        }
        .onAppear {
            loadSplashImages()
        }
    }

    private func loadSplashImages() {
        splashImages = []

        guard let bundleURL = Bundle.main.resourceURL else { return }
        let splashURL = bundleURL.appendingPathComponent(splashFolderName)

        guard FileManager.default.fileExists(atPath: splashURL.path) else {
            print("Splash Screens folder not found at: \(splashURL.path)")
            return
        }

        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: splashURL,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )

            for fileURL in contents.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
                let ext = fileURL.pathExtension.lowercased()
                guard ["png", "jpg", "jpeg"].contains(ext) else { continue }

                if let image = UIImage(contentsOfFile: fileURL.path) {
                    splashImages.append(image)
                }
            }
        } catch {
            print("Error loading splash images: \(error)")
        }
    }
}

struct SplashScreenImage: View {
    let image: UIImage

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    SplashTab(isUIHidden: .constant(false))
}

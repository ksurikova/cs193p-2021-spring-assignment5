//
//  EmojiArtApp.swift
//  EmojiArt
//
//  Created by Ksenia Surikova on 21.10.2021.
//

import SwiftUI

@main
struct EmojiArtApp: App {
    let document = EmojiArtDocument()
    var body: some Scene {
        WindowGroup {
            EmojiArtDocumentView(document: document)
        }
    }
}

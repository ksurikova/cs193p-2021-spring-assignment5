//
//  EmojiArtModel.swift
//  EmojiArt
//
//  Created by Ksenia Surikova on 21.10.2021.
//

import Foundation

struct EmojiArtModel {
    var background = Background.blank
    var emojis = [Emoji]()
    
    struct Emoji : Identifiable, Hashable {
        let text: String
        var x: Int // offset from center
        var y: Int  // offset from center
        var size: Int
        let id : Int
        
        fileprivate init(text: String, x: Int, y: Int, size: Int, id: Int){
            self.text = text
            self.x = x
            self.y = y
            self.size = size
            self.id = id
        }
    }
    
    init() {}
    
    private var uniqueEmojiId = 0
    mutating func addEmoji(_ text: String, at location: (x: Int, y: Int), size: Int) -> Emoji {
        uniqueEmojiId += 1
        let new = Emoji(text: text, x: location.x, y: location.y, size: size, id: uniqueEmojiId)
        emojis.append(new)
        return new
    }
    
    mutating func removeEmoji(_ emoji: Emoji) {
        emojis.remove(emoji)
    }

}

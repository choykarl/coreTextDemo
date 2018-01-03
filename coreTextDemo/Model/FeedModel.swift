//
//  FeedModel.swift
//  coreTextDemo
//
//  Created by karl on 2017/12/29.
//  Copyright © 2017年 Karl. All rights reserved.
//

import UIKit

class ImageDataModel: NSObject {
    var imageRect = CGRect.zero
    var imageUrl = ""
    var image: UIImage?
}

class BasePartModel: NSObject {
    var range = NSRange(location: 0, length: 0)
    var isSpecial = false
}

class TextPartModel: BasePartModel {
    var text = ""
}

class ImagePartModel: BasePartModel {
    var imageUrl = ""
    var imageSize = CGSize.zero
    var imageData = ImageDataModel()
}

class FeedModel: NSObject {
    var content = "" {
        didSet{
            parseContent()
        }
    }
    
    let drawModel = DrawModel()
    
    private(set) var normalTextPartModels = [TextPartModel]()
    private(set) var specialTextPartModels = [TextPartModel]()
    private(set) var allTextPartModels = [TextPartModel]()
    private(set) var imagePartModels = [ImagePartModel]()
    
    private func parseContent() {
        try? content.enumerateMatches(pattern: "<.*?>", range: NSRange(location: 0, length: content.count)) { (range, _) in
            let partModel = createTextPartModel(range)
            partModel.isSpecial = true
            specialTextPartModels.append(partModel)
        }
        
        try? content.enumerateMatches(pattern: "\\[.*?\\]", range: NSRange(location: 0, length: content.count)) { (range, _) in
            let partModel = createImagePartModel(range)
            partModel.isSpecial = true
            imagePartModels.append(partModel)
        }
        
        try? content.enumerateSeparatedByRegex(pattern: "<.*?>|\\[.*?\\]", range: NSRange(location: 0, length: content.count)) { (range, _) in
            let partModel = createTextPartModel(range)
            normalTextPartModels.append(partModel)
        }
        
        allTextPartModels = (specialTextPartModels + normalTextPartModels).sorted(by: { $0.range.location < $1.range.location })
    }
    
    private func createTextPartModel(_ range: Range<String.Index>) -> TextPartModel {
        let partModel = TextPartModel()
        let text = String(content[range])
        partModel.range = NSRange(range, in: text)
        partModel.text = text
        return partModel
    }
    
    private func createImagePartModel(_ range: Range<String.Index>) -> ImagePartModel {
        let partModel = ImagePartModel()
        let text = String(content[range])
        partModel.range = NSRange(range, in: text)
        let tempText = text[Range(NSRange(location: 1, length: text.count - 2), in: text)!]
        if let data = tempText.data(using: String.Encoding.utf8, allowLossyConversion: false) {
            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions.mutableContainers) as? [String: Any] {
                    partModel.imageSize = CGSize(width: json["width"] as! CGFloat, height: json["height"] as! CGFloat)
                    partModel.imageUrl = json["url"] as! String
                    partModel.imageData.imageRect = CGRect(x: 0, y: 0, width: partModel.imageSize.width, height: partModel.imageSize.height)
                    partModel.imageData.imageUrl = partModel.imageUrl
                }
            } catch {
                print(error)
            }
            
        }
        return partModel
    }
}

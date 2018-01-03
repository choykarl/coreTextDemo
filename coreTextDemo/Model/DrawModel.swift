//
//  DrawModel.swift
//  coreTextDemo
//
//  Created by karl on 2017/12/29.
//  Copyright © 2017年 Karl. All rights reserved.
//

import UIKit
import CoreText

class DrawModel: NSObject {
    var drawWidth: CGFloat = 0
    var drawHeight: CGFloat = 0
    var imageDatas = [ImageDataModel]()
    var frame: CTFrame?
}

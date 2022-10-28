//
//  PassthroughView.swift
//  whim-ios
//
//  Created by Joel Pöllänen on 7.3.2018.
//  Copyright © 2018 maas. All rights reserved.
//

import UIKit

open class PassthroughView: UIView {
    open override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let view = super.hitTest(point, with: event)
        return view == self ? nil : view
    }
}

open class PassthroughStackView: UIStackView {
    open override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let view = super.hitTest(point, with: event)
        return view == self ? nil : view
    }
}

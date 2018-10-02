//
//  CopyableLabel.swift
//  WireGuard
//
//  Created by Jeroen Leenarts on 02/10/2018.
//  Copyright © 2018 WireGuard LLC. All rights reserved.
//

import UIKit

@IBDesignable
class CopyableLabel: UILabel {
    override func awakeFromNib() {
        super.awakeFromNib()
        let gestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTapGesture(_:)))
        self.addGestureRecognizer(gestureRecognizer)
        self.isUserInteractionEnabled = true
    }

    // MARK: - UIGestureRecognizer
    @objc func handleTapGesture(_ recognizer: UIGestureRecognizer) {
        guard recognizer.state == .recognized else { return }

        if let recognizerView = recognizer.view,
            let recognizerSuperView = recognizerView.superview, recognizerView.becomeFirstResponder() {
            let menuController = UIMenuController.shared
            menuController.setTargetRect(recognizerView.frame, in: recognizerSuperView)
            menuController.setMenuVisible(true, animated: true)
        }
    }

    override var canBecomeFirstResponder: Bool {
        return true
    }

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        return (action == #selector(UIResponderStandardEditActions.copy(_:)))

    }

    override func copy(_ sender: Any?) {
        UIPasteboard.general.string = text
    }
}

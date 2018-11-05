// SPDX-License-Identifier: MIT
// Copyright © 2018 WireGuard LLC. All Rights Reserved.

import UIKit

class CopyableLabelTableViewCell: UITableViewCell {
    var copyableGesture = true

    var textToCopy: String? {
        fatalError("textToCopy must be implemented by subclass")
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        let gestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTapGesture(_:)))
        self.addGestureRecognizer(gestureRecognizer)
        self.isUserInteractionEnabled = true
    }

    // MARK: - UIGestureRecognizer
    @objc func handleTapGesture(_ recognizer: UIGestureRecognizer) {
        if !self.copyableGesture {
            return
        }
        guard recognizer.state == .recognized else { return }

        if let recognizerView = recognizer.view,
            let recognizerSuperView = recognizerView.superview, recognizerView.becomeFirstResponder() {
            let menuController = UIMenuController.shared
            menuController.setTargetRect(self.detailTextLabel?.frame ?? recognizerView.frame, in: self.detailTextLabel?.superview ?? recognizerSuperView)
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
        UIPasteboard.general.string = textToCopy
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        self.copyableGesture = true
    }
}

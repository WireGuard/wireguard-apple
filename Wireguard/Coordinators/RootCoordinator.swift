//
//  RootCoordinator.swift
//  Wireguard
//
//  Created by Jeroen Leenarts on 23-05-18.
//  Copyright © 2018 Wireguard. All rights reserved.
//

import Foundation
import UIKit

public protocol RootViewControllerProvider: class {
    // The coordinators 'rootViewController'. It helps to think of this as the view
    // controller that can be used to dismiss the coordinator from the view hierarchy.
    var rootViewController: UIViewController { get }
}

/// A Coordinator type that provides a root UIViewController
public typealias RootViewCoordinator = Coordinator & RootViewControllerProvider

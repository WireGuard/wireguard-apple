//
//  TunnelsTableViewController.swift
//  WireGuard
//
//  Created by Jeroen Leenarts on 23-05-18.
//  Copyright © 2018 Jason A. Donenfeld <Jason@zx2c4.com>. All rights reserved.
//

import UIKit

import CoreData
import BNRCoreDataStack

protocol TunnelsTableViewControllerDelegate: class {
    func addProvider(tunnelsTableViewController: TunnelsTableViewController)
    func connect(tunnel: Tunnel?, tunnelsTableViewController: TunnelsTableViewController)
    func configure(tunnel: Tunnel, tunnelsTableViewController: TunnelsTableViewController)
    func delete(tunnel: Tunnel, tunnelsTableViewController: TunnelsTableViewController)
}

class TunnelsTableViewController: UITableViewController {
    weak var delegate: TunnelsTableViewControllerDelegate?

    var viewContext: NSManagedObjectContext!

    private lazy var fetchedResultsController: FetchedResultsController<Tunnel> = {
        let fetchRequest = NSFetchRequest<Tunnel>()
        fetchRequest.entity = Tunnel.entity()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "title", ascending: true)]
        let frc = FetchedResultsController<Tunnel>(fetchRequest: fetchRequest,
                                                    managedObjectContext: viewContext)
        frc.setDelegate(self.frcDelegate)
        return frc
    }()

    private lazy var frcDelegate: TunnelFetchedResultsControllerDelegate = { // swiftlint:disable:this weak_delegate
        return TunnelFetchedResultsControllerDelegate(tableView: self.tableView)
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        do {
            try fetchedResultsController.performFetch()
        } catch {
            print("Failed to fetch objects: \(error)")
        }
    }

    @IBAction func addProvider(_ sender: Any) {
        delegate?.addProvider(tunnelsTableViewController: self)
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return fetchedResultsController.sections?[0].objects.count ?? 0
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(type: TunnelTableViewCell.self, for: indexPath)

        guard let sections = fetchedResultsController.sections else {
            fatalError("FetchedResultsController \(fetchedResultsController) should have sections, but found nil")
        }

        let section = sections[indexPath.section]
        let tunnel = section.objects[indexPath.row]

        cell.textLabel?.text = tunnel.title

        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let sections = fetchedResultsController.sections else {
            fatalError("FetchedResultsController \(fetchedResultsController) should have sections, but found nil")
        }

        let section = sections[indexPath.section]
        let tunnel = section.objects[indexPath.row]

        delegate?.connect(tunnel: tunnel, tunnelsTableViewController: self)

        tableView.deselectRow(at: indexPath, animated: true)
    }

    override func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
        guard let sections = fetchedResultsController.sections else {
            fatalError("FetchedResultsController \(fetchedResultsController) should have sections, but found nil")
        }

        let section = sections[indexPath.section]
        let tunnel = section.objects[indexPath.row]

        delegate?.configure(tunnel: tunnel, tunnelsTableViewController: self)

    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }

    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {

            guard let sections = fetchedResultsController.sections else {
                fatalError("FetchedResultsController \(fetchedResultsController) should have sections, but found nil")
            }

            let section = sections[indexPath.section]
            let tunnel = section.objects[indexPath.row]

            delegate?.delete(tunnel: tunnel, tunnelsTableViewController: self)
        }
    }
}

extension TunnelsTableViewController: Identifyable {}

class TunnelFetchedResultsControllerDelegate: NSObject, FetchedResultsControllerDelegate {

    private weak var tableView: UITableView?

    // MARK: - Lifecycle
    init(tableView: UITableView) {
        self.tableView = tableView
    }

    func fetchedResultsControllerDidPerformFetch(_ controller: FetchedResultsController<Tunnel>) {
        tableView?.reloadData()
    }

    func fetchedResultsControllerWillChangeContent(_ controller: FetchedResultsController<Tunnel>) {
        tableView?.beginUpdates()
    }

    func fetchedResultsControllerDidChangeContent(_ controller: FetchedResultsController<Tunnel>) {
        tableView?.endUpdates()
    }

    func fetchedResultsController(_ controller: FetchedResultsController<Tunnel>, didChangeObject change: FetchedResultsObjectChange<Tunnel>) {
        guard let tableView = tableView else { return }
        switch change {
        case let .insert(_, indexPath):
            tableView.insertRows(at: [indexPath], with: .automatic)

        case let .delete(_, indexPath):
            tableView.deleteRows(at: [indexPath], with: .automatic)

        case let .move(_, fromIndexPath, toIndexPath):
            tableView.moveRow(at: fromIndexPath, to: toIndexPath)

        case let .update(_, indexPath):
            tableView.reloadRows(at: [indexPath], with: .automatic)
        }
    }

    func fetchedResultsController(_ controller: FetchedResultsController<Tunnel>, didChangeSection change: FetchedResultsSectionChange<Tunnel>) {
        guard let tableView = tableView else { return }
        switch change {
        case let .insert(_, index):
            tableView.insertSections(IndexSet(integer: index), with: .automatic)

        case let .delete(_, index):
            tableView.deleteSections(IndexSet(integer: index), with: .automatic)
        }
    }
}

class TunnelTableViewCell: UITableViewCell {

}

extension TunnelTableViewCell: Identifyable {}

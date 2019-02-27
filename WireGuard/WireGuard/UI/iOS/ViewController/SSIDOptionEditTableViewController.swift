// SPDX-License-Identifier: MIT
// Copyright © 2018-2019 WireGuard LLC. All Rights Reserved.

import UIKit

protocol SSIDOptionEditTableViewControllerDelegate: class {
    func ssidOptionSaved(option: ActivateOnDemandViewModel.OnDemandSSIDOption, ssids: [String])
}

class SSIDOptionEditTableViewController: UITableViewController {
    private enum Section {
        case ssidOption
        case selectedSSIDs
        case addSSIDs
    }

    weak var delegate: SSIDOptionEditTableViewControllerDelegate?

    private var sections = [Section]()

    let ssidOptionFields: [ActivateOnDemandViewModel.OnDemandSSIDOption] = [
        .anySSID,
        .onlySpecificSSIDs,
        .exceptSpecificSSIDs
    ]

    var selectedOption: ActivateOnDemandViewModel.OnDemandSSIDOption
    var selectedSSIDs: [String]

    init(option: ActivateOnDemandViewModel.OnDemandSSIDOption, ssids: [String]) {
        selectedOption = option
        selectedSSIDs = ssids
        super.init(style: .grouped)
        loadSections()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = tr("tunnelOnDemandSelectionViewTitle")

        tableView.estimatedRowHeight = 44
        tableView.rowHeight = UITableView.automaticDimension

        tableView.register(CheckmarkCell.self)
        tableView.register(EditableTextCell.self)
        tableView.register(TextCell.self)
        tableView.isEditing = true
        tableView.allowsSelectionDuringEditing = true
    }

    func loadSections() {
        sections.removeAll()
        sections.append(.ssidOption)
        if selectedOption != .anySSID {
            if !selectedSSIDs.isEmpty {
                sections.append(.selectedSSIDs)
            }
            sections.append(.addSSIDs)
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        delegate?.ssidOptionSaved(option: selectedOption, ssids: selectedSSIDs)
    }
}

extension SSIDOptionEditTableViewController {
    override func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch sections[section] {
        case .ssidOption:
            return ssidOptionFields.count
        case .selectedSSIDs:
            return selectedSSIDs.count
        case .addSSIDs:
            return 1
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch sections[indexPath.section] {
        case .ssidOption:
            return ssidOptionCell(for: tableView, at: indexPath)
        case .selectedSSIDs:
            return selectedSSIDCell(for: tableView, at: indexPath)
        case .addSSIDs:
            return addSSIDCell(for: tableView, at: indexPath)
        }
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        switch sections[indexPath.section] {
        case .ssidOption:
            return false
        case .selectedSSIDs, .addSSIDs:
            return true
        }
    }

    override func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        switch sections[indexPath.section] {
        case .ssidOption:
            return .none
        case .selectedSSIDs:
           return .delete
        case .addSSIDs:
            return .insert
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch sections[section] {
        case .ssidOption:
            return nil
        case .selectedSSIDs:
            return tr("tunnelOnDemandSectionTitleSelectedSSIDs")
        case .addSSIDs:
            return tr("tunnelOnDemandSectionTitleAddSSIDs")
        }
    }

    private func ssidOptionCell(for tableView: UITableView, at indexPath: IndexPath) -> UITableViewCell {
        let field = ssidOptionFields[indexPath.row]
        let cell: CheckmarkCell = tableView.dequeueReusableCell(for: indexPath)
        cell.message = field.localizedUIString
        cell.isChecked = selectedOption == field
        cell.isEditing = false
        return cell
    }

    private func selectedSSIDCell(for tableView: UITableView, at indexPath: IndexPath) -> UITableViewCell {
        let cell: EditableTextCell = tableView.dequeueReusableCell(for: indexPath)
        cell.message = selectedSSIDs[indexPath.row]
        cell.isEditing = true
        cell.onValueBeingEdited = { [weak self, weak cell] text in
            guard let self = self, let cell = cell else { return }
            if let row = self.tableView.indexPath(for: cell)?.row {
                self.selectedSSIDs[row] = text
            }
        }
        return cell
    }

    private func addSSIDCell(for tableView: UITableView, at indexPath: IndexPath) -> UITableViewCell {
        let cell: TextCell = tableView.dequeueReusableCell(for: indexPath)
        cell.message = tr("tunnelOnDemandAddMessageAddNew")
        cell.isEditing = true
        return cell
    }

    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        switch sections[indexPath.section] {
        case .ssidOption:
            assertionFailure()
        case .selectedSSIDs:
            assert(editingStyle == .delete)
            selectedSSIDs.remove(at: indexPath.row)
            loadSections()
            let hasSelectedSSIDsSection = sections.contains(.selectedSSIDs)
            if hasSelectedSSIDsSection {
                tableView.deleteRows(at: [indexPath], with: .automatic)
            } else {
                tableView.deleteSections(IndexSet(integer: indexPath.section), with: .automatic)
            }
        case .addSSIDs:
            assert(editingStyle == .insert)
            let hasSelectedSSIDsSection = sections.contains(.selectedSSIDs)
            selectedSSIDs.append("")
            loadSections()
            let selectedSSIDsSection = sections.firstIndex(of: .selectedSSIDs)!
            let indexPath = IndexPath(row: selectedSSIDs.count - 1, section: selectedSSIDsSection)
            if !hasSelectedSSIDsSection {
                tableView.insertSections(IndexSet(integer: selectedSSIDsSection), with: .automatic)
            } else {
                tableView.insertRows(at: [indexPath], with: .automatic)
            }
            if let selectedSSIDCell = tableView.cellForRow(at: indexPath) as? EditableTextCell {
                selectedSSIDCell.beginEditing()
            }
        }
    }

    func lastSelectedSSIDItemIndexPath() -> IndexPath? {
        guard !selectedSSIDs.isEmpty else { return nil }
        guard let section = sections.firstIndex(of: .selectedSSIDs) else { return nil }
        return IndexPath(row: selectedSSIDs.count - 1, section: section)
    }
}

extension SSIDOptionEditTableViewController {
    override func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        switch sections[indexPath.section] {
        case .ssidOption:
            return indexPath
        case .selectedSSIDs, .addSSIDs:
            return nil
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch sections[indexPath.section] {
        case .ssidOption:
            let previousOption = selectedOption
            let previousSectionCount = sections.count
            selectedOption = ssidOptionFields[indexPath.row]
            loadSections()
            if previousOption == .anySSID {
                let indexSet = selectedSSIDs.isEmpty ? IndexSet(integer: 1) : IndexSet(1 ... 2)
                tableView.insertSections(indexSet, with: .fade)
            }
            if selectedOption == .anySSID {
                let indexSet = previousSectionCount == 2 ? IndexSet(integer: 1) : IndexSet(1 ... 2)
                tableView.deleteSections(indexSet, with: .fade)
            }
            tableView.reloadSections(IndexSet(integer: indexPath.section), with: .none)
        case .selectedSSIDs, .addSSIDs:
            assertionFailure()
        }
    }
}

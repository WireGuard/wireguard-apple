// SPDX-License-Identifier: MIT
// Copyright © 2018-2023 WireGuard LLC. All Rights Reserved.

import UIKit
import SystemConfiguration.CaptiveNetwork
import NetworkExtension

protocol SSIDOptionEditTableViewControllerDelegate: AnyObject {
    func ssidOptionSaved(option: ActivateOnDemandViewModel.OnDemandSSIDOption, ssids: [String])
}

class SSIDOptionEditTableViewController: UITableViewController {
    private enum Section {
        case ssidOption
        case selectedSSIDs
        case addSSIDs
    }

    private enum AddSSIDRow {
        case addConnectedSSID(connectedSSID: String)
        case addNewSSID
    }

    weak var delegate: SSIDOptionEditTableViewControllerDelegate?

    private var sections = [Section]()
    private var addSSIDRows = [AddSSIDRow]()

    let ssidOptionFields: [ActivateOnDemandViewModel.OnDemandSSIDOption] = [
        .anySSID,
        .onlySpecificSSIDs,
        .exceptSpecificSSIDs
    ]

    var selectedOption: ActivateOnDemandViewModel.OnDemandSSIDOption
    var selectedSSIDs: [String]
    var connectedSSID: String?

    init(option: ActivateOnDemandViewModel.OnDemandSSIDOption, ssids: [String]) {
        selectedOption = option
        selectedSSIDs = ssids
        super.init(style: .grouped)
        loadSections()
        addSSIDRows.removeAll()
        addSSIDRows.append(.addNewSSID)

        getConnectedSSID { [weak self] ssid in
            guard let self = self else { return }
            self.connectedSSID = ssid
            self.updateCurrentSSIDEntry()
            self.updateTableViewAddSSIDRows()
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = tr("tunnelOnDemandSSIDViewTitle")

        tableView.estimatedRowHeight = 44
        tableView.rowHeight = UITableView.automaticDimension

        tableView.register(CheckmarkCell.self)
        tableView.register(EditableTextCell.self)
        tableView.register(TextCell.self)
        tableView.isEditing = true
        tableView.allowsSelectionDuringEditing = true
        tableView.keyboardDismissMode = .onDrag
    }

    func loadSections() {
        sections.removeAll()
        sections.append(.ssidOption)
        if selectedOption != .anySSID {
            sections.append(.selectedSSIDs)
            sections.append(.addSSIDs)
        }
    }

    func updateCurrentSSIDEntry() {
        if let connectedSSID = connectedSSID, !selectedSSIDs.contains(connectedSSID) {
            if let first = addSSIDRows.first, case .addNewSSID = first {
                addSSIDRows.insert(.addConnectedSSID(connectedSSID: connectedSSID), at: 0)
            }
        } else if let first = addSSIDRows.first, case .addConnectedSSID = first {
            addSSIDRows.removeFirst()
        }
    }

    func updateTableViewAddSSIDRows() {
        guard let addSSIDSection = sections.firstIndex(of: .addSSIDs) else { return }
        let numberOfAddSSIDRows = addSSIDRows.count
        let numberOfAddSSIDRowsInTableView = tableView.numberOfRows(inSection: addSSIDSection)
        switch (numberOfAddSSIDRowsInTableView, numberOfAddSSIDRows) {
        case (1, 2):
            tableView.insertRows(at: [IndexPath(row: 0, section: addSSIDSection)], with: .automatic)
        case (2, 1):
            tableView.deleteRows(at: [IndexPath(row: 0, section: addSSIDSection)], with: .automatic)
        default:
            break
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
            return selectedSSIDs.isEmpty ? 1 : selectedSSIDs.count
        case .addSSIDs:
            return addSSIDRows.count
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch sections[indexPath.section] {
        case .ssidOption:
            return ssidOptionCell(for: tableView, at: indexPath)
        case .selectedSSIDs:
            if !selectedSSIDs.isEmpty {
                return selectedSSIDCell(for: tableView, at: indexPath)
            } else {
                return noSSIDsCell(for: tableView, at: indexPath)
            }
        case .addSSIDs:
            return addSSIDCell(for: tableView, at: indexPath)
        }
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        switch sections[indexPath.section] {
        case .ssidOption:
            return false
        case .selectedSSIDs:
            return !selectedSSIDs.isEmpty
        case .addSSIDs:
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

    private func noSSIDsCell(for tableView: UITableView, at indexPath: IndexPath) -> UITableViewCell {
        let cell: TextCell = tableView.dequeueReusableCell(for: indexPath)
        cell.message = tr("tunnelOnDemandNoSSIDs")
        cell.setTextColor(.secondaryLabel)
        cell.setTextAlignment(.center)
        return cell
    }

    private func selectedSSIDCell(for tableView: UITableView, at indexPath: IndexPath) -> UITableViewCell {
        let cell: EditableTextCell = tableView.dequeueReusableCell(for: indexPath)
        cell.message = selectedSSIDs[indexPath.row]
        cell.placeholder = tr("tunnelOnDemandSSIDTextFieldPlaceholder")
        cell.isEditing = true
        cell.onValueBeingEdited = { [weak self, weak cell] text in
            guard let self = self, let cell = cell else { return }
            if let row = self.tableView.indexPath(for: cell)?.row {
                self.selectedSSIDs[row] = text
                self.updateCurrentSSIDEntry()
                self.updateTableViewAddSSIDRows()
            }
        }
        return cell
    }

    private func addSSIDCell(for tableView: UITableView, at indexPath: IndexPath) -> UITableViewCell {
        let cell: TextCell = tableView.dequeueReusableCell(for: indexPath)
        switch addSSIDRows[indexPath.row] {
        case .addConnectedSSID:
            cell.message = tr(format: "tunnelOnDemandAddMessageAddConnectedSSID (%@)", connectedSSID!)
        case .addNewSSID:
            cell.message = tr("tunnelOnDemandAddMessageAddNewSSID")
        }
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
            if !selectedSSIDs.isEmpty {
                tableView.deleteRows(at: [indexPath], with: .automatic)
            } else {
                tableView.reloadRows(at: [indexPath], with: .automatic)
            }
            updateCurrentSSIDEntry()
            updateTableViewAddSSIDRows()
        case .addSSIDs:
            assert(editingStyle == .insert)
            let newSSID: String
            switch addSSIDRows[indexPath.row] {
            case .addConnectedSSID(let connectedSSID):
                newSSID = connectedSSID
            case .addNewSSID:
                newSSID = ""
            }
            selectedSSIDs.append(newSSID)
            loadSections()
            let selectedSSIDsSection = sections.firstIndex(of: .selectedSSIDs)!
            let indexPath = IndexPath(row: selectedSSIDs.count - 1, section: selectedSSIDsSection)
            if selectedSSIDs.count == 1 {
                tableView.reloadRows(at: [indexPath], with: .automatic)
            } else {
                tableView.insertRows(at: [indexPath], with: .automatic)
            }
            updateCurrentSSIDEntry()
            updateTableViewAddSSIDRows()
            if newSSID.isEmpty {
                if let selectedSSIDCell = tableView.cellForRow(at: indexPath) as? EditableTextCell {
                    selectedSSIDCell.beginEditing()
                }
            }
        }
    }

    private func getConnectedSSID(completionHandler: @escaping (String?) -> Void) {
        #if targetEnvironment(simulator)
        completionHandler("Simulator Wi-Fi")
        #else
        NEHotspotNetwork.fetchCurrent { hotspotNetwork in
            completionHandler(hotspotNetwork?.ssid)
        }
        #endif
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
            selectedOption = ssidOptionFields[indexPath.row]
            guard previousOption != selectedOption else {
                tableView.deselectRow(at: indexPath, animated: true)
                return
            }
            loadSections()
            if previousOption == .anySSID {
                let indexSet = IndexSet(1 ... 2)
                tableView.insertSections(indexSet, with: .fade)
            }
            if selectedOption == .anySSID {
                let indexSet = IndexSet(1 ... 2)
                tableView.deleteSections(indexSet, with: .fade)
            }
            tableView.reloadSections(IndexSet(integer: indexPath.section), with: .none)
        case .selectedSSIDs, .addSSIDs:
            assertionFailure()
        }
    }
}

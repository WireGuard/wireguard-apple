// SPDX-License-Identifier: MIT
// Copyright © 2018-2023 WireGuard LLC. All Rights Reserved.

import UIKit

class SSIDOptionDetailTableViewController: UITableViewController {

    let selectedSSIDs: [String]

    init(title: String, ssids: [String]) {
        selectedSSIDs = ssids
        super.init(style: .grouped)
        self.title = title
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.estimatedRowHeight = 44
        tableView.rowHeight = UITableView.automaticDimension
        tableView.allowsSelection = false

        tableView.register(TextCell.self)
    }
}

extension SSIDOptionDetailTableViewController {
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return selectedSSIDs.count
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return tr("tunnelOnDemandSectionTitleSelectedSSIDs")
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: TextCell = tableView.dequeueReusableCell(for: indexPath)
        cell.message = selectedSSIDs[indexPath.row]
        return cell
    }
}

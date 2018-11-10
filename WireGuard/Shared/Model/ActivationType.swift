// SPDX-License-Identifier: MIT
// Copyright © 2018 WireGuard LLC. All Rights Reserved.

enum ActivationType {
    case activateManually
    case useOnDemandOverWifiAndCellular
    case useOnDemandOverWifiOnly
    case useOnDemandOverCellularOnly
}

extension ActivationType: Codable {
    // We use separate coding keys in case we might have a enum with associated values in the future
    enum CodingKeys: CodingKey {
        case activateManually
        case useOnDemandOverWifiAndCellular
        case useOnDemandOverWifiOnly
        case useOnDemandOverCellularOnly
    }

    // Decoding error
    enum DecodingError: Error {
        case invalidInput
    }

    // Encoding
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .activateManually:
            try container.encode(true, forKey: CodingKeys.activateManually)
        case .useOnDemandOverWifiAndCellular:
            try container.encode(true, forKey: CodingKeys.useOnDemandOverWifiAndCellular)
        case .useOnDemandOverWifiOnly:
            try container.encode(true, forKey: CodingKeys.useOnDemandOverWifiOnly)
        case .useOnDemandOverCellularOnly:
            try container.encode(true, forKey: CodingKeys.useOnDemandOverCellularOnly)
        }
    }

    // Decoding
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let isValid = try? container.decode(Bool.self, forKey: CodingKeys.activateManually), isValid {
            self = .activateManually
            return
        }

        if let isValid = try? container.decode(Bool.self, forKey: CodingKeys.useOnDemandOverWifiAndCellular), isValid {
            self = .useOnDemandOverWifiAndCellular
            return
        }

        if let isValid = try? container.decode(Bool.self, forKey: CodingKeys.useOnDemandOverWifiOnly), isValid {
            self = .useOnDemandOverWifiOnly
            return
        }

        if let isValid = try? container.decode(Bool.self, forKey: CodingKeys.useOnDemandOverCellularOnly), isValid {
            self = .useOnDemandOverCellularOnly
            return
        }

        throw DecodingError.invalidInput
    }
}

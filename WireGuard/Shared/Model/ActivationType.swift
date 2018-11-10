// SPDX-License-Identifier: MIT
// Copyright © 2018 WireGuard LLC. All Rights Reserved.

enum ActivationType {
    case activateManually
    case useOnDemandForAnyInternetActivity
    case useOnDemandOnlyOverWifi
    case useOnDemandOnlyOverCellular
}

extension ActivationType: Codable {
    // We use separate coding keys in case we might have a enum with associated values in the future
    enum CodingKeys: CodingKey {
        case activateManually
        case useOnDemandForAnyInternetActivity
        case useOnDemandOnlyOverWifi
        case useOnDemandOnlyOverCellular
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
        case .useOnDemandForAnyInternetActivity:
            try container.encode(true, forKey: CodingKeys.useOnDemandForAnyInternetActivity)
        case .useOnDemandOnlyOverWifi:
            try container.encode(true, forKey: CodingKeys.useOnDemandOnlyOverWifi)
        case .useOnDemandOnlyOverCellular:
            try container.encode(true, forKey: CodingKeys.useOnDemandOnlyOverCellular)
        }
    }

    // Decoding
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let isValid = try? container.decode(Bool.self, forKey: CodingKeys.activateManually), isValid {
            self = .activateManually
            return
        }

        if let isValid = try? container.decode(Bool.self, forKey: CodingKeys.useOnDemandForAnyInternetActivity), isValid {
            self = .useOnDemandForAnyInternetActivity
            return
        }

        if let isValid = try? container.decode(Bool.self, forKey: CodingKeys.useOnDemandOnlyOverWifi), isValid {
            self = .useOnDemandOnlyOverWifi
            return
        }

        if let isValid = try? container.decode(Bool.self, forKey: CodingKeys.useOnDemandOnlyOverCellular), isValid {
            self = .useOnDemandOnlyOverCellular
            return
        }

        throw DecodingError.invalidInput
    }
}

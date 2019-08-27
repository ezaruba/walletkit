//
//  BRCrypto.swift
//  BRCrypto
//
//  Created by Ed Gamble on 3/27/19.
//  Copyright © 2018 Breadwallet AG. All rights reserved.
//
//  See the LICENSE file at the project root for license information.
//  See the CONTRIBUTORS file at the project root for a list of contributors.
//
import BRCryptoC

///
/// A Blockchain Network.  Networks are created based from a cross-product of block chain and
/// network type.  Specifically {BTC, BCH, ETH, ...} x {Mainnet, Testnet, ...}.  Thus there will
/// be networks of [BTC-Mainnet, BTC-Testnet, ..., ETH-Mainnet, ETH-Testnet, ETH-Rinkeby, ...]
///
public final class Network: CustomStringConvertible {
    let core: BRCryptoNetwork

    /// A unique-identifer-string
    internal let uids: String

    /// The name
    public let name: String

    /// If 'mainnet' then true, otherwise false
    public let isMainnet: Bool

    /// The current height of the blockChain network.  On a reorganization, this might go backwards.
    /// (No guarantee that this monotonically increases)
    public var height: UInt64 {
        get { return cryptoNetworkGetHeight (core) }
        set { cryptoNetworkSetHeight (core, newValue) }
    }

     /// The network fees.  Expect the User to select their preferred fee, based on time-to-confirm,
    /// and then have their preferred fee held in WalletManager.defaultNetworkFee.
    public let fees: [NetworkFee]

    /// Return the minimum fee which should be the fee with the largest confirmation time
    public var minimumFee: NetworkFee {
        return fees.min { $0.timeIntervalInMilliseconds > $1.timeIntervalInMilliseconds }!
    }

    /// The native currency.
    public let currency: Currency

    /// All currencies - at least those we are handling/interested-in.
    public let currencies: Set<Currency>

    public func currencyBy (code: String) -> Currency? {
        return currencies.first { $0.code == code } // sloppily
    }

    public func currencyBy (issuer: String) -> Currency? {
        let issuerLowercased = issuer.lowercased()
        return currencies.first {
            // Not the best way to compare - but avoid Foundation
            $0.issuer.map { $0.lowercased() == issuerLowercased } ?? false
        }
    }

    public func hasCurrency(_ currency: Currency) -> Bool {
        return CRYPTO_TRUE == cryptoNetworkHasCurrency (core, currency.core)
    }

    public func baseUnitFor (currency: Currency) -> Unit? {
        guard hasCurrency(currency) else { return nil }
        return cryptoNetworkGetUnitAsBase (core, currency.core)
            .map { Unit (core: $0, take: false) }
    }

    public func defaultUnitFor (currency: Currency) -> Unit? {
        guard hasCurrency (currency) else { return nil }
        return cryptoNetworkGetUnitAsDefault (core, currency.core)
            .map { Unit (core: $0, take: false) }
    }

    public func unitsFor (currency: Currency) -> Set<Unit>? {
        guard hasCurrency (currency) else { return nil }
        return Set ((0..<cryptoNetworkGetUnitCount (core, currency.core))
            .map { cryptoNetworkGetUnitAt (core, currency.core, $0) }
            .map { Unit (core: $0, take: false) }
        )
    }

    public func hasUnitFor (currency: Currency, unit: Unit) -> Bool? {
        return unitsFor (currency: currency)?.contains(unit)
    }

    public struct Association {
        let baseUnit: Unit
        let defaultUnit: Unit
        let units: Set<Unit>
    }

    internal init (core: BRCryptoNetwork, take: Bool) {
        self.core = take ? cryptoNetworkTake(core) : core
        self.uids = asUTF8String (cryptoNetworkGetUids (core))
        self.name = asUTF8String (cryptoNetworkGetName (core))
        self.isMainnet  = (CRYPTO_TRUE == cryptoNetworkIsMainnet (core))
        self.currency   = Currency (core: cryptoNetworkGetCurrency(core), take: false)
        self.currencies = Set ((0..<cryptoNetworkGetCurrencyCount(core))
            .map { cryptoNetworkGetCurrencyAt (core, $0) }
            .map { Currency (core: $0, take: false)})
        self.fees = Array ((0..<cryptoNetworkGetNetworkFeeCount(core))
            .map { cryptoNetworkGetNetworkFeeAt (core, $0)}
            .map { NetworkFee (core: $0, take: false) })
    }

    /// Create a Network
    ///
    /// - Parameters:
    ///   - uids: A unique identifier string amoung all networks.  This parameter must include a
    ///       substring of {"mainnet", "testnet", "ropsten", "rinkeby"} to indicate the type
    ///       of the network.  [This following the BlockChainDB convention]
    ///   - name: the name
    ///   - isMainnet: if mainnet, then true
    ///   - currency: the currency
    ///   - height: the height
    ///   - associations: An association between one or more currencies and the units
    ///      for those currency.  The network currency should be included.
    ///
    public convenience init (uids: String,
                             name: String,
                             isMainnet: Bool,
                             currency: Currency,
                             height: UInt64,
                             associations: Dictionary<Currency, Association>,
                             fees: [NetworkFee]) {
        precondition (!fees.isEmpty)
        
        var core: BRCryptoNetwork!

        switch currency.code.lowercased() {
        case Currency.codeAsBTC:
            let chainParams = (isMainnet ? BRMainNetParams : BRTestNetParams)
            core = cryptoNetworkCreateAsBTC (uids, name, chainParams!.pointee.forkId, chainParams)

        case Currency.codeAsBCH:
            let chainParams = (isMainnet ? BRBCashParams : BRBCashTestNetParams)
            core = cryptoNetworkCreateAsBTC (uids, name, chainParams!.pointee.forkId, chainParams)

        case Currency.codeAsETH:
            if uids.contains("mainnet") {
                core = cryptoNetworkCreateAsETH (uids, name, 1, ethereumMainnet)
            }
            else if uids.contains("testnet") || uids.contains("ropsten") {
                core = cryptoNetworkCreateAsETH (uids, name, 3, ethereumTestnet)
            }
            else if uids.contains ("rinkeby") {
                core = cryptoNetworkCreateAsETH (uids, name, 4, ethereumRinkeby)
            }
            else {
                precondition (false)
            }

        default:
            core = cryptoNetworkCreateAsGEN (uids, name, (isMainnet ? 1 : 0))
            break
        }

        cryptoNetworkSetHeight (core, height);
        cryptoNetworkSetCurrency (core, currency.core)

        associations.forEach {
            let (currency, association) = $0
            cryptoNetworkAddCurrency (core,
                                      currency.core,
                                      association.baseUnit.core,
                                      association.defaultUnit.core)
            association.units.forEach {
                cryptoNetworkAddCurrencyUnit (core,
                                              currency.core,
                                              $0.core)
            }
        }

        fees.forEach {
            cryptoNetworkAddNetworkFee (core, $0.core)
        }

        self.init (core: core, take: false)
    }

    public var description: String {
        return name
    }

    deinit {
        cryptoNetworkGive (core)
    }

    /// TODO: Should use the network's/manager's default address scheme
    public func addressFor (_ string: String) -> Address? {
        return cryptoNetworkCreateAddressFromString (core, string)
            .map { Address (core: $0, take: false) }
    }
}

extension Network: Hashable {
    public static func == (lhs: Network, rhs: Network) -> Bool {
        return lhs.uids == rhs.uids
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(uids)
    }
}

public enum NetworkEvent {
    case created
}

///
/// Listener for NetworkEvent
///
public protocol NetworkListener: class {
    ///
    /// Handle a NetworkEvent
    ///
    /// - Parameters:
    ///   - system: the system
    ///   - network: the network
    ///   - event: the event
    ///
    func handleNetworkEvent (system: System,
                             network: Network,
                             event: NetworkEvent)
}

/// A Functional Interface for a Handler
public typealias NetworkEventHandler = (System, Network, NetworkEvent) -> Void

///
/// A Network Fee represents the 'amount per cost factor' paid to mine a transfer. For BTC this
/// amount is 'SAT/BYTE'; for ETH this amount is 'gasPrice'.  The actual fee for the transfer
/// depends on properties of the transfer; for BTC, the cost factor is 'size in kB'; for ETH, the
/// cost factor is 'gas'.
///
/// A Network supports a variety of fees.  Essentially the higher the fee the more enticing the
/// transfer is to a miner and thus the more quickly the transfer gets into the block chain.
///
/// A NetworkFee is Equatable on the underlying Core representation.  It is natural to compare
/// NetworkFee based on timeIntervalInMilliseconds
///
public final class NetworkFee: Equatable {
    // The Core representation
    internal var core: BRCryptoNetworkFee

    /// The estimated time internal for a transaction confirmation.
    public let timeIntervalInMilliseconds: UInt64

    /// The ammount, as a rate on 'cost factor', to pay in network fees for the desired
    /// time internal to confirmation.  The 'cost factor' is blockchain specific - for BTC it is
    /// 'transaction size in kB'; for ETH it is 'gas'.
    internal let pricePerCostFactor: Amount

    /// Initialize from the Core representation
    internal init (core: BRCryptoNetworkFee, take: Bool) {
        self.core = (take ? cryptoNetworkFeeTake(core) : core)
        self.timeIntervalInMilliseconds = cryptoNetworkFeeGetConfirmationTimeInMilliseconds(core)
        self.pricePerCostFactor = Amount (core: cryptoNetworkFeeGetPricePerCostFactor (core),
                                          take: false)
    }

    /// Initialize based on the timeInternal and pricePerCostFactor.  Used by BlockchainDB when
    /// parsing a NetworkFee from BlockchainDB.Model.BlockchainFee
    internal convenience init (timeIntervalInMilliseconds: UInt64,
                               pricePerCostFactor: Amount) {
        self.init (core: cryptoNetworkFeeCreate (timeIntervalInMilliseconds,
                                                 pricePerCostFactor.core,
                                                 pricePerCostFactor.unit.core),
                   take: false)
    }

    deinit {
        cryptoNetworkFeeGive (core)
    }

    // Equatable using the Core representation
    public static func == (lhs: NetworkFee, rhs: NetworkFee) -> Bool {
        return CRYPTO_TRUE == cryptoNetworkFeeEqual (lhs.core, rhs.core)
    }
}

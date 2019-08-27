package com.breadwallet.corecrypto;

import com.breadwallet.corenative.crypto.BRCryptoKey;
import com.breadwallet.corenative.crypto.BRCryptoWalletSweeper;
import com.breadwallet.corenative.crypto.BRCryptoWalletSweeperStatus;
import com.breadwallet.corenative.crypto.CoreBRCryptoCurrency;
import com.breadwallet.corenative.crypto.CoreBRCryptoNetwork;
import com.breadwallet.corenative.crypto.CoreBRCryptoWallet;
import com.breadwallet.crypto.NetworkFee;
import com.breadwallet.crypto.blockchaindb.BlockchainDb;
import com.breadwallet.crypto.blockchaindb.errors.QueryError;
import com.breadwallet.crypto.blockchaindb.models.bdb.Transaction;
import com.breadwallet.crypto.errors.FeeEstimationError;
import com.breadwallet.crypto.errors.WalletSweeperError;
import com.breadwallet.crypto.errors.WalletSweeperInsufficientFundsError;
import com.breadwallet.crypto.errors.WalletSweeperInvalidKeyError;
import com.breadwallet.crypto.errors.WalletSweeperInvalidSourceWalletError;
import com.breadwallet.crypto.errors.WalletSweeperNoTransfersFoundError;
import com.breadwallet.crypto.errors.WalletSweeperQueryError;
import com.breadwallet.crypto.errors.WalletSweeperUnableToSweepError;
import com.breadwallet.crypto.errors.WalletSweeperUnexpectedError;
import com.breadwallet.crypto.errors.WalletSweeperUnsupportedCurrencyError;
import com.breadwallet.crypto.utility.CompletionHandler;
import com.google.common.base.Optional;
import com.google.common.primitives.UnsignedLong;

import java.util.Collections;
import java.util.List;

import static com.google.common.base.Preconditions.checkState;

/* package */
final class WalletSweeper implements com.breadwallet.crypto.WalletSweeper {

    private static WalletSweeperError statusToError(BRCryptoWalletSweeperStatus status) {
        switch (status) {
            case CRYPTO_WALLET_SWEEPER_SUCCESS: return null;
            case CRYPTO_WALLET_SWEEPER_UNSUPPORTED_CURRENCY: return new WalletSweeperUnsupportedCurrencyError();

            case CRYPTO_WALLET_SWEEPER_INVALID_KEY: return new WalletSweeperInvalidKeyError();
            case CRYPTO_WALLET_SWEEPER_INVALID_SOURCE_WALLET: return new WalletSweeperInvalidSourceWalletError();
            case CRYPTO_WALLET_SWEEPER_INSUFFICIENT_FUNDS: return new WalletSweeperInsufficientFundsError();
            case CRYPTO_WALLET_SWEEPER_UNABLE_TO_SWEEP: return new WalletSweeperUnableToSweepError();
            case CRYPTO_WALLET_SWEEPER_NO_TRANSFERS_FOUND: return new WalletSweeperNoTransfersFoundError();

            case CRYPTO_WALLET_SWEEPER_INVALID_ARGUMENTS: return new WalletSweeperUnexpectedError("Invalid argument");
            case CRYPTO_WALLET_SWEEPER_INVALID_TRANSACTION: return new WalletSweeperUnexpectedError("Invalid transaction");

            case CRYPTO_WALLET_SWEEPER_ILLEGAL_OPERATION: return new WalletSweeperUnexpectedError("Illegal operation");

        }
        return null;
    }

    private static WalletSweeperError validateSupported(WalletManager manager,
                                                        Wallet wallet,
                                                        Key key) {
        Network network = manager.getNetwork();

        BRCryptoKey coreKey = key.getBRCryptoKey();
        CoreBRCryptoWallet coreWallet = wallet.getCoreBRCryptoWallet();
        CoreBRCryptoCurrency coreCurrency = coreWallet.getCurrency();
        CoreBRCryptoNetwork coreNetwork = network.getCoreBRCryptoNetwork();

        return statusToError(BRCryptoWalletSweeper.validateSupported(coreNetwork, coreCurrency, coreKey, coreWallet));
    }

    private static WalletSweeper createAsBtc(WalletManager manager,
                                             Wallet wallet,
                                             Key key) {
        Network network = manager.getNetwork();

        BRCryptoKey coreKey = key.getBRCryptoKey();
        CoreBRCryptoWallet coreWallet = wallet.getCoreBRCryptoWallet();
        CoreBRCryptoCurrency coreCurrency = coreWallet.getCurrency();
        CoreBRCryptoNetwork coreNetwork = network.getCoreBRCryptoNetwork();

        int coreScheme = Utilities.addressSchemeToCrypto(manager.getAddressScheme());
        return new WalletSweeper(BRCryptoWalletSweeper.createAsBtc(coreNetwork, coreCurrency, coreKey, coreScheme), manager, wallet);
    }

    /* package */
    static void create(WalletManager manager,
                       Wallet wallet,
                       Key key,
                       BlockchainDb bdb,
                       CompletionHandler<com.breadwallet.crypto.WalletSweeper, WalletSweeperError> completion) {
        // check that the requested operation is supported
        WalletSweeperError e = validateSupported(manager, wallet, key);
        if (null != e) {
            completion.handleError(e);
            return;
        }

        // construct a sweeper and populate it
        if (Currency.CODE_AS_BTC.equals(wallet.getCurrency().getCode())) {
            createAsBtc(manager, wallet, key).initAsBtc(bdb, completion);
        } else {
            throw new IllegalArgumentException("Unsupported wallet");
        }
    }

    private final BRCryptoWalletSweeper core;
    private final WalletManager manager;
    private final Wallet wallet;

    private WalletSweeper(BRCryptoWalletSweeper core, WalletManager manager, Wallet wallet) {
        this.core = core;
        this.manager = manager;
        this.wallet = wallet;
    }

    @Override
    public Optional<Amount> getBalance() {
        return core.getBalance().transform(Amount::create);
    }

    @Override
    public void estimate(NetworkFee fee,
                         CompletionHandler<com.breadwallet.crypto.TransferFeeBasis, FeeEstimationError> completion) {
        wallet.estimateFee(core, fee, completion);
    }

    @Override
    public Optional<Transfer> submit(com.breadwallet.crypto.TransferFeeBasis feeBasis) {
        Optional<Transfer> maybeTransfer = wallet.createTransfer(core, feeBasis);
        if (maybeTransfer.isPresent()) {
            Transfer transfer = maybeTransfer.get();
            manager.submit(transfer, core.getKey());
        }
        return maybeTransfer;
    }

    private void initAsBtc(BlockchainDb bdb,
                           CompletionHandler<com.breadwallet.crypto.WalletSweeper, WalletSweeperError> completion) {
        Network network = manager.getNetwork();
        String address = getAddress();

        bdb.getTransactions(network.getUids(),
                Collections.singletonList(address),
                UnsignedLong.ZERO,
                network.getHeight(),
                true,
                false,
                new CompletionHandler<List<Transaction>, QueryError>() {

                    @Override
                    public void handleData(List<Transaction> data) {
                        for (Transaction txn: data) {
                            Optional<byte[]> maybeRaw = txn.getRaw();
                            if (maybeRaw.isPresent()) {
                                WalletSweeperError e = handleTransactionAsBtc(maybeRaw.get());
                                if (null != e) {
                                    completion.handleError(e);
                                    return;
                                }
                            }
                        }

                        WalletSweeperError e = validate();
                        if (null != e) {
                            completion.handleError(e);
                            return;
                        }

                        completion.handleData(WalletSweeper.this);
                    }

                    @Override
                    public void handleError(QueryError e) {
                        completion.handleError(new WalletSweeperQueryError(e));
                    }
                });
    }

    private String getAddress() {
        Optional<String> maybeAddress = core.getAddress();
        checkState(maybeAddress.isPresent());
        return maybeAddress.get();
    }

    private WalletSweeperError handleTransactionAsBtc(byte[] transaction) {
        return statusToError(core.handleTransactionAsBtc(transaction));
    }

    private WalletSweeperError validate() {
        return statusToError(core.validate());
    }
}

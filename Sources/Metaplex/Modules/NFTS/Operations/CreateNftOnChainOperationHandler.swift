//
//  CreateNftOnChainOperationHandler.swift
//
//
//  Created by Michael J. Huber Jr. on 9/2/22.
//

import Foundation
import Solana

public enum AccountState {
    case new(Account)
    case existing(Account)

    var account: Account {
        switch self {
        case .new(let account):
            return account
        case .existing(let account):
            return account
        }
    }
}

public struct CreateNftInput {
    public var mintAccountState: AccountState
    public var account: Account
    public var name: String
    public var symbol: String?
    public var uri: String
    public var sellerFeeBasisPoints: UInt16
    public var hasCreators: Bool
    public var addressCount: UInt32
    public var creators: [MetaplexCreator]
    public var collection: MetaplexCollection? = nil
    public var uses: MetaplexUses? = nil
    public var isMutable: Bool
    
    public init(mintAccountState: AccountState, account: Account, name: String, symbol: String?, uri: String, sellerFeeBasisPoints: UInt16, hasCreators: Bool, addressCount: UInt32, creators: [MetaplexCreator], isMutable: Bool) {
        self.mintAccountState = mintAccountState
        self.account = account
        self.name = name
        self.symbol = symbol
        self.uri = uri
        self.sellerFeeBasisPoints = sellerFeeBasisPoints
        self.hasCreators = hasCreators
        self.addressCount = addressCount
        self.creators = creators
        self.isMutable = isMutable
    }

}

typealias CreateNftOperation = OperationResult<CreateNftInput, OperationError>

class CreateNftOnChainOperationHandler: OperationHandler {
    var metaplex: Metaplex

    typealias I = CreateNftInput
    typealias O = NFT

    init(metaplex: Metaplex) {
        self.metaplex = metaplex
    }

    func handle(operation: CreateNftOperation) -> OperationResult<NFT, OperationError> {
        let builder = InstructionBuilder(metaplex: metaplex)
        return operation.flatMap { input in
            OperationResult<[TransactionInstruction], Error>.init { callback in
                builder.createNftInstructions(input: input) {
                    callback($0)
                }
            }.mapError {
                OperationError.buildInstructionsError($0)
            }.flatMap { instructions in
                OperationResult<String, Error>.init { callback in
                    self.metaplex.connection.serializeTransaction(instructions: instructions, recentBlockhash: nil, signers: [input.account, input.mintAccountState.account]) {
                        callback($0)
                    }
                }
                .mapError { OperationError.serializeTransactionError($0) }
            }.flatMap { serializedTransaction in
                OperationResult<TransactionID, IdentityDriverError>.init { callback in
                    self.metaplex.sendTransaction(serializedTransaction: serializedTransaction) {
                        callback($0)
                    }
                }
                .mapError { OperationError.sendTransactionError($0) }
            }.flatMap { signature in
                let operation: () -> OperationResult<SignatureStatus, Retry<Error>> = {
                    OperationResult<SignatureStatus, Error>.init { callback in
                        // We are sleeping here in order to wait for the transaction to finalize on the chain.
                        #warning("This needs to be refactored into something more elegant.")
                        sleep(3)
                        self.metaplex.confirmTransaction(
                            signature: signature,
                            configs: nil
                        ) { result in
                            switch result {
                            case .success(let signature):
                                guard let signature = signature, let status = signature.confirmationStatus, status == .finalized else {
                                    callback(.failure(OperationError.nilSignatureStatus))
                                    return
                                }
                                callback(.success(signature))
                            case .failure(let error):
                                callback(.failure(error))
                            }
                        }
                    }
                    .mapError { error in
                        if case OperationError.nilSignatureStatus = error {
                            return Retry.retry(error)
                        }
                        return Retry.doNotRetry(error)
                    }
                }
                let retry = OperationResult<SignatureStatus, Error>.retry(attempts: 5, operation: operation)
                    .mapError { OperationError.confirmTransactionError($0) }
                return retry
            }.flatMap { (status: SignatureStatus) -> OperationResult<NFT, OperationError> in
                let findNft = FindNftByMintOnChainOperationHandler(metaplex: self.metaplex)
                return findNft.handle(operation: FindNftByMintOperation.pure(.success(input.mintAccountState.account.publicKey)))
            }
        }
    }
}

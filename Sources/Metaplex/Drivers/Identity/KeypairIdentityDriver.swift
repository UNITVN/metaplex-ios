//
//  KeypairIdentityDriver.swift
//  
//
//  Created by Arturo Jamaica on 4/9/22.
//

import Foundation
import Solana

public class KeypairIdentityDriver: IdentityDriver {

    public var publicKey: PublicKey
    private let secretKey: Data
    private let account: Account
    private let solanaRPC: Api
    public  init(solanaRPC: Api, account: Account) {
        self.solanaRPC = solanaRPC
        self.publicKey = account.publicKey
        self.secretKey = account.secretKey
        self.account = account
    }

    public func sendTransaction(serializedTransaction: String, onComplete: @escaping(Result<TransactionID, IdentityDriverError>) -> Void) {
        self.solanaRPC.sendTransaction(serializedTransaction: serializedTransaction) { result in
            switch result {
            case .success(let transactionID):
                onComplete(.success(transactionID))
            case .failure(let error):
                onComplete(.failure(.sendTransactionError(error)))
            }
        }
    }

    public func signTransaction(transaction: Transaction, onComplete: @escaping (Result<Transaction, IdentityDriverError>) -> Void) {
        var transaction = transaction
        transaction.sign(signers: [account])
            .onSuccess { onComplete(.success(transaction))}
    }

    public func signAllTransactions(transactions: [Transaction], onComplete: @escaping (Result<[Transaction?], IdentityDriverError>) -> Void) {
        var mutableTransactions: [Transaction?] = []
        transactions.forEach { transaction in
            var mutableTransaction = transaction
            mutableTransaction.sign(signers: [account]).onSuccess { _ in
                mutableTransactions.append(mutableTransaction)
            }.onFailure { _ in
                mutableTransactions.append(nil)
            }
        }
        onComplete(.success(mutableTransactions))
    }
}

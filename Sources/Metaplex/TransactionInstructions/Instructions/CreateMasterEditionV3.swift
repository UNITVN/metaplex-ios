//
//  CreateMasterEditionV3.swift
//  
//
//  Created by Michael J. Huber Jr. on 9/12/22.
//

import Foundation
import Solana

public struct CreateMasterEditionV3InstructionAccounts {
    public init(edition: PublicKey, mint: PublicKey, updateAuthority: PublicKey, mintAuthority: PublicKey, payer: PublicKey, metadata: PublicKey) {
        self.edition = edition
        self.mint = mint
        self.updateAuthority = updateAuthority
        self.mintAuthority = mintAuthority
        self.payer = payer
        self.metadata = metadata
    }
    
    let edition: PublicKey
    let mint: PublicKey
    let updateAuthority: PublicKey
    let mintAuthority: PublicKey
    let payer: PublicKey
    let metadata: PublicKey
    var tokenProgram: PublicKey?
    var systemProgram: PublicKey?
    var rent: PublicKey?
}

public struct CreateMasterEditionV3InstructionData {
    public init(maxSupply: UInt64?) {
        self.maxSupply = maxSupply
    }
    
    let maxSupply: UInt64?
}

public struct CreateMasterEditionV3 {
    private struct Index {
        static let create: UInt8 = 17
    }

    public static func createMasterEditionV3(
        accounts: CreateMasterEditionV3InstructionAccounts,
        arguments: CreateMasterEditionV3InstructionData,
        programId: PublicKey = TokenMetadataProgram.publicKey
    ) -> TransactionInstruction {
        let keys = [
            Account.Meta(publicKey: accounts.edition, isSigner: false, isWritable: true),
            Account.Meta(publicKey: accounts.mint, isSigner: false, isWritable: true),
            Account.Meta(publicKey: accounts.updateAuthority, isSigner: true, isWritable: false),
            Account.Meta(publicKey: accounts.mintAuthority, isSigner: true, isWritable: false),
            Account.Meta(publicKey: accounts.payer, isSigner: true, isWritable: true),
            Account.Meta(publicKey: accounts.metadata, isSigner: false, isWritable: true),
            Account.Meta(publicKey: accounts.tokenProgram ?? PublicKey.tokenProgramId, isSigner: false, isWritable: false),
            Account.Meta(publicKey: accounts.systemProgram ?? PublicKey.systemProgramId, isSigner: false, isWritable: false),
            Account.Meta(publicKey: accounts.rent ?? PublicKey.sysvarRent, isSigner: false, isWritable: false)
        ]

        var data = [Index.create]
        data.append(contentsOf: (arguments.maxSupply != nil).bytes)
        data.append(contentsOf: arguments.maxSupply?.bytes ?? UInt64(0).bytes)

        return TransactionInstruction(
            keys: keys,
            programId: programId,
            data: data
        )
    }
}

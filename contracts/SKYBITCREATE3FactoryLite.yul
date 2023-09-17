// SPDX-License-Identifier: MIT

/// @notice A factory contract that deploys a contract from bytecode using "CREATE3" method.
/// @author SKYBIT (https://github.com/SKYBITDev3/SKYBIT-Keyless-Deployment)
object "SKYBITCREATE3FactoryLite" {
    code { // Constructor code of the contract        
        datacopy(0, dataoffset("runtime"), datasize("runtime")) // Deploy the contract
        return (0, datasize("runtime"))
    }

    object "runtime" {
        code { // Executable code of the object
            if gt(callvalue(), 0) { revert(0, 0) } // Protection against sending Ether

            datacopy(0, dataoffset("CREATEFactory"), datasize("CREATEFactory")) // Write CREATEFactory bytecode to memory position 0. 25 bytes on left of slot, 0-padded on right
            mstore(0x20, caller()) // 32 bytes. to be hashed with salt to help ensure unique address.
            mstore(0x40, calldataload(0)) // 32 bytes. User-provided salt

            let createFactoryAddress:= create2(0, 0, datasize("CREATEFactory"), keccak256(0x20, 0x40)) // Deploy the CREATE factory via CREATE2, store address on the stack

            if iszero(createFactoryAddress) {
                mstore(0, 0x6e0df51b) // Store ABI encoding of `Deployment of CREATEFactory contract failed`
                revert(0x1c, 4) // Revert with the stored 4 bytes skipping 0-padding
            }

            calldatacopy(0x20, 32, sub(calldatasize(), 32)) // Overwrite scratch at memory position 0x20 (we'll reserve 0 for call output later) with incoming contract bytecode (skipping first 32 bytes which is salt). We take full control of memory because it won't return to Solidity code. We don't need the previously stored data anymore.

            if iszero(
                call( // Use the deployed CREATEFactory to deploy the users' contract. Returns 0 on error (eg. out of gas) and 1 on success.
                    gas(), // Gas remaining
                    createFactoryAddress,
                    0, // Ether value
                    0x20, // Start of contract bytecode or "creation code"
                    sub(calldatasize(), 32), // Length of contract bytecode
                    0, // Offset of output (resulting address of deployed user's contract). If call fails whatever was here may remain, so we left it empty beforehand.
                    20 // Length of output
                )
            ) {
                mstore(0, 0xec4cb4b6) // Store ABI encoding of `CREATEFactory call failed`
                revert(0x1c, 4)
            }

            if iszero(mload(0)) { // Call output was 0 or not received
                mstore(0, 0xc6831bdb) // Store ABI encoding of `No address`
                revert(0x1c, 4)
            }

            return (0, 20) // Return the call output, which is the address of the contract that was deployed via CREATEFactory
        }

        object "CREATEFactory" {
            code {
                datacopy(0, dataoffset("runtime"), datasize("runtime"))
                return (0, datasize("runtime"))
            }
    
            object "runtime" {
                code {
                    calldatacopy(0, 0, calldatasize())
                    mstore(0, create(0, 0, calldatasize())) // Create returns 0 if error

                    return (12, 20) // Addresses are only 20 bytes, so skip the first 12 bytes
                }
            }
        }
    }
}

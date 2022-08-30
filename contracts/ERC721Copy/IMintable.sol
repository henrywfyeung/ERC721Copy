// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

/**
 * @notice This is the interface of the Mintable Contract, the mintable contract specifies the rule for minting copies. 
 * Contracts that inherit the IMintable Interface can define their own rules. The creator will first specifies rules 
 * using the setupRule function. Then, the collector can mint a copy with the isMintable function, or subsequently extend
 * the validity of the copy with the isExtendable function.
 */
interface IMintable {
    /**
     * @notice mintInfo struct that specifies the input to the minting function
     *
     * @param creatorId The tokenId of the creator NFT that produces the original content
     * @param duration The time duration that should add to the NFT token after mint
     * @param transferable Indicates whether the token is transferable
     * @param updatable Indicates whether the token is updatable.
     * @param revokable Indicataes whether the token is recovable by the creator token holder
     * @param extendable Indicates whether the token can be extended beyond the deadline
     * @param statement The copyright declaration by the creator token holder
     * @param data Addition data that is required by the Mintable rule to pass. Should deserialize into variables specified
     * in the abi.decode function in the app
     */
    struct MintInfo {
        uint256 creatorId;
        uint64 duration;
        bool transferable;
        bool updatable;
        bool revokable;
        bool extendable;
        string statement;
        bytes data;
    }

    /**
     * @notice Sets up the mintable rule by the creator NFT's tokenId and the ruleData. This function will
     * decode the ruleData back to the required parameters and sets up the mintable rule that decides who
     * can or cannot mint a copy of the creator's NFT content, with the corresponding parameters, such as
     * transferable, updatable etc. see {IMintable-MintInfo}
     *
     * @param creatorId The token Id of the creator NFT, i.e. the token which will get its contentUri copied
     * @param ruleData The data bytes for initialising the mintableRule. Parameters are encoded into bytes
     */
    function setupRule(uint256 creatorId, bytes calldata ruleData) external;

    /**
     * @notice Supply the data that will be used to passed the mintable rule setup by the creator. Different
     * rule has different requirement
     *
     * @param to the address that the NFT will be minted to
     * @param mintInfo the mint information as indicated in {IMintable-MintInfo}
     */
    function isMintable(address to, MintInfo calldata mintInfo) external;

    /**
     * @notice Supply the the expiry date of the NFT and data that will be used to passed the mintable rule setup
     * by the creator. Different rule has different requirement. Once pass the NFT expiry will be extended by the
     * specific duration
     *
     * @param to the token holder of the copy NFT
     * @param expiry the expiry timestamp of the token
     * @param mintInfo the mint information as indicated in {IMintable-MintInfo}
     */
    function isExtendable(
        address to,
        uint64 expiry,
        MintInfo memory mintInfo
    ) external;
}

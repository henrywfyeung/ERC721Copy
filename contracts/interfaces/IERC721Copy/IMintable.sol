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
     * @dev Sets up the mintable rule by the creator NFT's tokenId and the ruleData. This function will
     * decode the ruleData back to the required parameters and sets up the mintable rule that decides who
     * can or cannot mint a copy of the creator's NFT content, with the corresponding parameters, such as
     * transferable, updatable etc. see {IMintable-MintInfo}
     *
     * @param copyHash The hash of the copy configuration
     * @param ruleData The data bytes for initialising the mintableRule. Parameters are encoded into bytes
     */
    function setupRule(bytes32 copyHash, bytes calldata ruleData) external;

    /**
     * @dev Supply the data that will be used to passed the mintable rule setup by the creator. Different
     * rule has different requirement
     *
     * @param to the address that the NFT will be minted to
     * @param copyHash the hash of the copy configuration
     * @param duration the duration that the NFT validity can be extended
     */
    function isMintable(address to, bytes32 copyHash, uint64 duration) external payable;

    /**
     * @dev Supply the the expiry date of the NFT and data that will be used to passed the mintable rule setup
     * by the creator. Different rule has different requirement. Once pass the NFT expiry will be extended by the
     * specific duration
     *
     * @param to the token holder of the copy NFT
     * @param copyHash the hash of the copy configuration
     * @param duration the duration that the NFT validity can be extended
     */
    function isExtendable(address to, bytes32 copyHash, uint64 duration) external payable;

    /**
     * @dev Returns the mintable rule of the creator NFT's tokenId
     *
     * @param copyHash The hash of the copy configuration
     * @return count The total number of copies minted by this rule
     */
    function getMintCount(bytes32 copyHash) external view returns (uint256);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import './IERC721Copy/IERC721Copy.sol';

/**
 * @notice The Interface of Copy Contract. Creator can use the setMintableRule to specify the condition for minting
 * the copy. Depending on the mintable rules, collector can copy, then update, transfer, extend or destroy the copy. Creator 
 * can revoke the copy if allowed in mintable rules. This interface is intended to be used for single creator NFT contract. 
 * It can be easily extended to accept request from multiple create NFT contracts.
 */
interface ICopy is IERC721Copy {

    /**
     * @dev Struct containing the information of the minted copy NFT
     *
     * @param expiredAt The expiration timestamp of the nft token
     * @param copyURI Shows the contentUri copied from the creator token for collection purposes
     * the copy NFT owner will get, for instance, the right to create derivative work based on the creator NFT content
     */
    struct CopyInfo {
        string copyURI;
        bytes32 copyHash;
        uint64 expireAt;
    }

    /**
     * @param tokenId The copy NFT tokenId
     *
     * @return string Returns the content identifier of the copyright declaration that the creator provided
     */
    function getStatement(uint256 tokenId) external view returns (Statement);

    /**
     * @param copyHash The hash of the mintInfo
     *
     * @return MintInfo Returns the full information of the mint info
     */
    function getMintInfo(bytes32 copyHash) external view returns (MintInfo memory);

    /**
     * @param creatorId The creator NFT tokenId
     *
     * @return copyHashes Returns the list of copyHashes that the creator has minted
     */
    function getCopyHashes(uint256 creatorId) external view returns (bytes32[] memory);

    /**
     * @param creatorId The creator NFT tokenId
     *
     * @return copyCount Returns total number of copies minted based on a specific creator token
     */
    function getCopyCount(uint256 creatorId) external view returns (uint256);
    
    /**
     * @param creatorId The creator NFT token Id
     * @param index The index of the list of copy NFTs minted based on the creatorId, index starts from 1
     *
     * @return uint256 Returns the copy NFT tokenId of a particular creator NFT token
     */
    function getCopyByIndex(uint256 creatorId, uint256 index) external view returns (uint256);

    /**
     * @param tokenId The copy NFT tokenId
     *
     * @return copyInfo Returns the copyInfo of a specific copy token
     */
    function getCopyInfo(uint256 tokenId) external view returns (CopyInfo memory);

    /**
     * @param collector The address who may process valid copies of a particular creator NFT. A valid copy refers to a
     * copy that has not expired and has not been revoked by the creator
     * @param creatorId The creator NFT tokenId
     *
     * @return bool Returns true if the collector has a valid copy of the creator NFT
     */
    function hasValidCopy(address collector, uint256 creatorId) external view returns (bool);

    /**
      * @param collector The address who may process copies of a particular creator NFT.
      * @param creatorId The creator NFT tokenId
     */
    function tokenCounter(address collector, uint256 creatorId) external view returns (uint256);
}

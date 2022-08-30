// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import './IMintable.sol';

/**
 * @notice The Interface of ERC721Copy Contract. Creator can use the setMintableRule to specify the condition for minting
 * the copy. Depending on the mintable rules, collector can copy, then update, transfer, extend or destroy the copy. Creator 
 * can revoke the copy if allowed in mintable rules. This interface is intended to be used for single creator NFT contract. 
 * It can be easily extended to accept request from multiple create NFT contracts.
 */
interface IERC721Copy {
    /**
     * @dev Struct containing the information of the minted copy NFT
     *
     * @param creatorId The tokenId of the creator NFT that produces the original content
     * @param extendAt The contract address that the user can go to when extending the expiration timestemp
     * @param expiredAt The expiration timestamp of the nft token
     * @param transferable Indicates whether the token is transferable
     * @param updatable Indicates whether the token is updatable.
     *  User can update the contentUri of the copy token (copyUri) to the latest contentUri state of the creator token
     * @param revokable Indicataes whether the token is recovable by the creator token holder
     * @param extendable Indicates whether the token can be extended beyond the deadline
     * @param copyURI Shows the contentUri copied from the creator token for collection purposes
     * @param statement The copyright declaration by the creator token holder. The declaration may include the rights that
     * the copy NFT owner will get, for instance, the right to create derivative work based on the creator NFT content
     */
    struct CopyInfo {
        uint256 creatorId;
        address extendAt;
        uint64 expireAt;
        bool transferable;
        bool updatable;
        bool revokable;
        bool extendable;
        string copyURI;
        string statement;
    }

    /**
     * @dev The creator who holds a creator token can set a mintable rule that enables others
     * to mint copies given that they fulfil the conditions specified by the rule
     *
     * @param creatorId the tokenId of the creator NFT
     * @param mintable the address of the mintable rule
     * @param mintableInitData the data to be input into the mintable address for setup rules
     */
    function setMintableRule(
        uint256 creatorId,
        address mintable,
        bytes calldata mintableInitData
    ) external;

    /**
     * @dev Mint a copy of a creator token which has a mintable rule set
     *
     * @param to address of copy token receiver
     * @param mintInfo See {IMintable-MintInfo}
     *
     * @return uint256 Returns the newly minted tokenId
     */
    function copy(
        address to, 
        IMintable.MintInfo calldata mintInfo
    ) external returns (uint256);

    /**
     * @dev The creator can revoke the ownership of the copy NFT if isRevokable returns true
     * see {IERC721Copy-isRevokable}
     *
     * @param tokenId the copy nft tokenId to be revoked by the creator
     *
     */
    function revoke(uint256 tokenId) external;

    /**
     * @dev The copy NFT owner can destroy the copy NFT anytime he/she wants. The destroy function
     * works also for expired tokens
     *
     * @param tokenId the copy nft tokenId to be revoked by the creator
     *
     */
    function destroy(uint256 tokenId) external;


    /**
     * @dev The copy NFT owner can extend the copy NFT anytime he/she wants. Extension of the token's
     * expiry timestamp should subject to the conditions specified in the mintable rule set by the
     * creator
     *
     * @param tokenId the copy nft tokenId to be revoked by the creator
     * @param duration the duration to be extended
     * @param data the additional data required to pass the isExtendable function. It will be abi.decoded
     * into the respective variables in {IMintable-isExtendable}
     *
     */
    function extend(
        uint256 tokenId,
        uint64 duration,
        bytes calldata data
    ) external returns (uint64);

    /**
     * @dev The copy NFT owner can update the copy NFT if the NFT is updatable. The update function
     * should stop functioning once the token is expired
     *
     * @param tokenId the copy nft tokenId to be revoked by the creator
     *
     */    
    function update(uint256 tokenId) external returns (string memory);

    /**
     * @return address Returns the address of the creator NFT contract
     */
    function getCreatorContract() external view returns (address);

    /**
     * @dev The copy NFT is transferable if its transferable parameter is true and it has not expired
     *
     * @param tokenId The copy NFT token Id
     *
     * @return bool Returns a boolean indicating whether the token is transferable
     */
    function isTransferable(uint256 tokenId) external view returns (bool);

    /**
     * @dev The copy NFT is updatable if its updatable parameter is true and it has not expired
     *
     * @param tokenId The copy NFT token Id
     *
     * @return bool Returns a boolean indicating whether the token is updatable
     */
    function isUpdatable(uint256 tokenId) external view returns (bool);

    /**
     * @dev The copy NFT is revokable if its revokable parameter is true or it has expired
     *
     * @param tokenId The copy NFT token Id
     *
     * @return bool Returns a boolean indicating whether the token is is revokable
     */
    function isRevokable(uint256 tokenId) external view returns (bool);

    /**
     * @dev The copy NFT is extendable if its extendable parameter is true
     *
     * @param tokenId The copy NFT token Id
     *
     * @return bool Returns a boolean indicating whether the token is is extendable
     */
    function isExtendable(uint256 tokenId) external view returns (bool);

    /**
     * @param tokenId The copy NFT token Id
     *
     * @return bool Returns a boolean indicating whether the token is is expired
     */
    function isExpired(uint256 tokenId) external view returns (bool);

    /**
     * @dev This function calls the IERC721 ownerOf function. It returns the token owner regardless of whether
     * the token is currently expired.
     *
     * @param tokenId The copy NFT tokenId
     *
     * @return address Returns the address of the token holder
     */
    function holderOf(uint256 tokenId) external view returns (address);

    /**
     * @param tokenId The copy NFT tokenId
     *
     * @return uint256 Returns the creator NFT tokenId that the copy NFT is based on
     */
    function creatorOf(uint256 tokenId) external view returns (uint256);

    /**
     * @param creatorId The creator NFT tokenId
     *
     * @return address Returns of the mintable rule provided by the creator NFT token owner
     */
    function getMintableRule(uint256 creatorId) external view returns (address);

    /**
     * @param tokenId The copy NFT tokenId
     *
     * @return string Returns the content identifier of the copyright declaration that the creaetor provided
     */
    function getStatement(uint256 tokenId) external view returns (string memory);

    /**
     * @param tokenId The copy NFT tokenId
     *
     * @return string Returns the expiration timestamp of the token
     */
    function expireAt(uint256 tokenId) external view returns (uint64);
}

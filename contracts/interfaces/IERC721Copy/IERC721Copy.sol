// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

/**
 * @notice The Interface of ERC721Copy Contract. Creator can use the setMintableRule to specify the condition for minting
 * the copy. Depending on the mintable rules, collector can copy, then update, transfer, extend or destroy the copy. Creator 
 * can revoke the copy if allowed in mintable rules. This interface is intended to be used for single creator NFT contract. 
 * It can be easily extended to accept request from multiple create NFT contracts.
 * 
 * The MintInfo encapulates the information of the copy NFT, including all the permissions granted to it. This information can be 
 * stored on chain as a MintInfo struct, or simple a hashed version of it to save gas. It comes with a fixed set of basic info, such 
 * as isTransferable, isExtendable, etc, and a bytes field for defining custom additional permissions.
 * 
 * MintableRules are external contract that is responsible for the defintion and enforcement of rules, that should be fulfilled before 
 * minting a copy NFT
 * 
 * Creator chooses the MintableRules that associate with the corresponding MintInfos.
 * Copier fulfils the MintableRule to obtain a copy and enjoy the benefits brought by the MintInfo.
 */
interface IERC721Copy {

    /**
     * @dev Emitted when a mintable rule is created
     * 
     * @param copyHash The hash of the copy configuration
     * @param mintInfo The mintable rule that the copyHash is generated from
     */
    event SetMintableRule(bytes32 copyHash, MintInfo mintInfo);
    
    /**
     * @dev Emitted when a mintable rule is paused
     * 
     * @param copyHash The hash of the copy configuration
     */
    event PauseMintableRule(bytes32 copyHash);

    /**
     * @dev Emitted when a copy is created
     * 
     * @param tokenId The tokenId of the copy NFT
     * @param copyHash The hash of the copy configuration
     * @param expiry The expiration timestamp of the copy NFT
     */
    event Create(uint256 tokenId, bytes32 copyHash, uint64 expiry);

    /**
     * @dev Emitted when a copy is extended
     * 
     * @param tokenId The tokenId of the copy NFT
     * @param expiry The renewed expiration timestamp of the copy NFT
     */
    event Extend(uint256 tokenId, uint64 expiry);

    /**
     * @dev Emitted when a copy is updated
     * 
     * @param tokenId The tokenId of the copy NFT
     * @param tokenUri The tokenUri of the copy NFT. This tokenUri should point to the resources that the copy NFT owner will get.
     */
    event Update(uint256 tokenId, string tokenUri);

    /**
     * @dev Emitted when a copy is revoked. A revoked copy is burnt and will never be recovered
     * 
     * @param tokenId The tokenId of the copy NFT
     */
    event Revoke(uint256 tokenId);

    /**
     * @dev Emitted when a copy is destroyed. A destroyed copy is burnt and will never be recovered
     * 
     * @param tokenId The tokenId of the copy NFT
     */
    event Destroy(uint256 tokenId);

    /**
     * @dev The Permission Granted to the owner of the CopyNFT. The Value in this enum is only suggested values. Please substitute them for 
     *    your own use case.
     * 
     * @param COLLECT Only allows for holding the copy NFT. This is suitable for the case which the NFT is an artwork collection.
     * @param USE Allows for holding and using the copy NFT. This is suitable for the case which, for instance, the copy NFT is a ticket to an event, or a key to unlock private content
     * @param MODIFY Allows for holding, and modifying the copy NFT. This is suitable for the case which the Creator wants to grant permission to Copy NFT holders who wants to create derivative work based on the content
     * @param DISTRIBUTE Allows for holding, and distributing the copy NFT. This is suitable for the case which the Creator wants to grant Copy NFT holders unresticted distribute of the content
     */
    enum Statement {
        COLLECT,
        USE,
        MODIFY,
        DISTRIBUTE
    }

    /**
    * @dev States of the mintable rule
    *
    * @param NIL Rule not exists
    * @param EXIST Rule exists for minting and extending
    * @param PAUSED Rule paused for minting but available for extending
    */
    enum State {
        NIL,
        EXIST,
        PAUSED
    }

    /**
     * @dev mintInfo struct that specifies the input to the minting function
     *
     * @param creatorId The tokenId of the creator NFT that produces the original content
     * @param statement The copyright declaration by the creator token holder
     * @param transferable Indicates whether the token is transferable
     * @param updatable Indicates whether the token is updatable.
     *  User can update the contentUri of the copy token (copyUri) to the latest contentUri state of the creator token
     * @param revokable Indicates whether the token is recovable by the creator token holder
     * @param extendable Indicates whether the token can be extended beyond the deadline
     * in the abi.decode function in the app
     * @param mintInfoAdditional Additional data for the mintable rule
     */
    struct MintInfo {
        address mintable;
        Statement statement;
        bool transferable;
        bool updatable;
        bool revokable;
        bool extendable;
        uint256 creatorId;
        bytes mintInfoAdditional;
    }

    /**
     * @dev The creator who holds a creator token can set a mintable rule that enables others
     * to mint copies given that they fulfil the conditions specified by the rule
     *
     * @param mintInfo the basic states of the copy to be minted
     * @param mintableInitData the data to be input into the mintable address for setup rules
     * 
     * @return bytes32 Returns the hash of the copy conifiguration 
     */
    function setMintableRule(
        MintInfo memory mintInfo,
        bytes calldata mintableInitData
    ) external returns (bytes32);

    /**
     * @dev The creator can pause the mintable rule
     *
     * @param copyHash the hash of the copy configuration for minting
     */ 
    function pauseMintableRule(
        bytes32 copyHash
    ) external;

    /**
     * @param copyId The copy NFT tokenId
     *
     * @return address Returns of the mintable rule provided by the creator NFT token owner
     */
    function getMintableRule(uint256 copyId) external view returns (address);

    /**
     * @dev Mint a copy of a creator token which has a mintable rule set
     *
     * @param to address of copy token receiver
     * @param copyHash the hash of the copy configuration for minting
     * @param duration the duration of the copy
     *
     * @return uint256 Returns the newly minted tokenId
     */
    function create(
        address to, 
        bytes32 copyHash,
        uint64 duration
    ) external payable returns (uint256);

    /**
     * @dev The copy NFT owner can extend the copy NFT anytime he/she wants. Extension of the token's
     * expiry timestamp should subject to the conditions specified in the mintable rule set by the
     * creator
     *
     * @param tokenId the copy nft tokenId to be revoked by the creator
     * @param duration the duration to be extended
     *
     */
    function extend(
        uint256 tokenId,
        uint64 duration
    ) external payable returns (uint64);

    /**
     * @dev The copy NFT owner can update the copy NFT if the NFT is updatable. The update function
     * should stop functioning once the token is expired
     *
     * @param tokenId the copy nft tokenId to be revoked by the creator
     *
     */    
    function update(uint256 tokenId) external returns (string memory);

    /**
     * @dev The creator can revoke the ownership of the copy NFT if isRevokable returns true
     * see {ICopy-isRevokable}
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
     * @param tokenId The copy NFT tokenId
     *
     * @return uint256 Returns the creator NFT tokenId that the copy NFT is based on
     */
    function creatorOf(uint256 tokenId) external view returns (uint256);

    /**
     * @param tokenId The copy NFT tokenId
     *
     * @return string Returns the expiration timestamp of the token
     */
    function expireAt(uint256 tokenId) external view returns (uint64);
}

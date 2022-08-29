// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

interface IERC721Copy {
    /**
     * @notice Struct containing the information of the minted copy NFT
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
     * @return address Returns the address of the creator NFT contract
     */
    function getCreatorContract() external view returns (address);

    /**
     * @return uint256 Returns the total number of minted copy NFT tokens
     */
    function getTokenCount() external view returns (uint256);

    /**
     * @param creatorId The creator NFT token Id
     *
     * @return uint256 Returns the total number of copy NFT tokens minted based on a particular creator NFT token
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
     * @notice The copy NFT is transferable if its transferable parameter is true and it has not expired
     *
     * @param tokenId The copy NFT token Id
     *
     * @return bool Returns a boolean indicating whether the token is transferable
     */
    function isTransferable(uint256 tokenId) external view returns (bool);

    /**
     * @notice The copy NFT is updatable if its updatable parameter is true and it has not expired
     *
     * @param tokenId The copy NFT token Id
     *
     * @return bool Returns a boolean indicating whether the token is updatable
     */
    function isUpdatable(uint256 tokenId) external view returns (bool);

    /**
     * @notice The copy NFT is revokable if its revokable parameter is true or it has expired
     *
     * @param tokenId The copy NFT token Id
     *
     * @return bool Returns a boolean indicating whether the token is is revokable
     */
    function isRevokable(uint256 tokenId) external view returns (bool);

    /**
     * @notice The copy NFT is extendable if its extendable parameter is true
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
     * @dev See {IERC721-ownerOf}.
     *
     * @notice This function calls the IERC721 ownerOf function. It returns the token owner regardless of whether
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

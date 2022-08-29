// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import './ERC721Copy/ERC721Copy.sol';
import './ERC721Copy/IERC721Copy.sol';

contract Copy is ERC721Copy {
    event SetMintableRule(uint256 creatorId, address mintable, bytes mintableInitData);
    event Create(address to, uint256 copyId, IMintable.MintInfo mintInfo);
    event BatchCollect(address to, uint256[] copyIds, IMintable.MintInfo[] mintInfoList);
    event BatchCreate(address[] recipients, uint256[] copyIds, IMintable.MintInfo mintInfo);
    event Extend(uint256 copyId, uint64 expiry);
    event Update(uint256 copyId, string tokenUri);
    event Revoke(uint256 copyId);
    event Burn(uint256 copyId);

    constructor (
        string memory name_, 
        string memory symbol_,
        address creatorContract_
    ) ERC721Copy(creatorContract_) ERC721(name_, symbol_) {}

    modifier onlyCreator(uint256 creatorId) {
        require(IERC721(_creatorContract).ownerOf(creatorId) == msg.sender, "Copy: Invalid Creator");
        _;
    }

    /**
     * @notice The creator who holds a creator token can set a mintable rule that enables others
     * to mint copies given that they fulfil the conditions specified by the rule.
     *
     * @param creatorId the tokenId of the creator NFT
     * @param mintable the address of the mintable rule
     * @param mintableInitData the data to be input into the mintable address for setup rules
     */
    function setMintableRule(
        uint256 creatorId,
        address mintable,
        bytes calldata mintableInitData
    ) external onlyCreator(creatorId) {
        _setMintableRule(creatorId, mintable, mintableInitData);
        emit SetMintableRule(creatorId, mintable, mintableInitData);
    }

    /**
     * @notice Create a copy NFT by fulfilling the condition in the mintable rule, and mint to a particular address
     *
     * @param to An address to receive the copy NFT token
     * @param mintInfo See {IMintable-MintInfo}
     */
    function create(address to, IMintable.MintInfo calldata mintInfo)
        external
        returns (uint256)
    {
        uint256 copyId = _copy(to, mintInfo);
        emit Create(to, copyId, mintInfo);
        return copyId;
    }

    /*
     * Function for the collector to collect copies from multiple creator tokens.
     */
    function batchCollect(address to, IMintable.MintInfo[] calldata mintInfoList)
        external
        returns (uint256[] memory)
    {
        uint256[] memory copyIds = new uint256[](mintInfoList.length);
        for (uint256 i = 0; i < mintInfoList.length; i++) {
            copyIds[i] = _copy(to, mintInfoList[i]);
        }

        emit BatchCollect(to, copyIds, mintInfoList);
        return copyIds;
    }

    /*
     * Function for a creator to issue multiple copies of a particular creator token to recipients.
     */
    function batchCreate(address[] memory recipients, IMintable.MintInfo calldata mintInfo)
        external
        returns (uint256[] memory)
    {
        uint256[] memory copyIds = new uint256[](recipients.length);
        for (uint256 i = 0; i < recipients.length; i++) {
            copyIds[i] = _copy(recipients[i], mintInfo);
        }

        emit BatchCreate(recipients, copyIds, mintInfo);
        return copyIds;
    }

    /**
     * @notice Extend the expiration timestamp of the copy NFT
     *
     * @param copyId  The tokenId of the copy NFT
     * @param duration The duration that the NFT expiry will be extended
     * @param data Additional data for the isExtendable function to process
     */
    function extend(
        uint256 copyId,
        uint64 duration,
        bytes calldata data
    ) external returns (uint64) {
        uint64 expiry = _extend(copyId, duration, data);
        emit Extend(copyId, expiry);
        return expiry;
    }

    /**
     * @notice Update the contentUri of the copy NFT token by the copy NFT owner or approved address
     *
     * @param copyId The tokenId of the copy NFT
     *
     * @return string Returns the updated contentUri
     *
     */
    function update(uint256 copyId) external returns (string memory) {
        string memory tokenUri = _update(copyId);
        emit Update(copyId, tokenUri);
        return tokenUri;
    }

    /**
     * @notice Revoke the ownership of the copy NFT, can only be called by the creator NFT token owner or approved address
     *
     * @param copyId The tokenId of the copy NFT
     *
     */
    function revoke(uint256 copyId) external {
        _revoke(copyId);
        emit Revoke(copyId);
    }

    /**
     * @notice Burn the copy NFT token, the owner of the copy NFT or approved address can burn the token
     *
     * @param copyId The tokenId of the copy NFT
     *
     */
    function burn(uint256 copyId) external {
        _destroy(copyId);
        emit Burn(copyId);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import '@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol';
import '@openzeppelin/contracts/utils/Counters.sol';

import './ERC721Copy/IERC721Copy.sol';
import './ERC721Copy/IMintable.sol';

/**
 * @notice This is an implementation of the IERC721Copy interface.
 */
contract ERC721Copy is ERC721Enumerable, IERC721Copy {
    uint64 private constant MAX_UINT64 = 0xffffffffffffffff;
    address internal _creatorContract;

    using Strings for uint256;
    using Counters for Counters.Counter;
    Counters.Counter private _copyIds;

    // copyId => CopyInfo
    mapping(uint256 => CopyInfo) private _copyInfo;
    // creatorId => index => copyId
    mapping(uint256 => mapping(uint256 => uint256)) private _copys;
    // creatorId => copy_count
    mapping(uint256 => uint256) private _copyCount;
    // copyId => index
    mapping(uint256 => uint256) private _copyIndex;
    // createrId => rule
    mapping(uint256 => address) private _mintableRules;

    /**
     * @notice initializer
     *
     * @param creatorContract_ The NFT contract of the creator NFT
     *
     */
    constructor (
        string memory name_, 
        string memory symbol_,
        address creatorContract_
    ) ERC721(name_, symbol_) {
        _creatorContract = creatorContract_;
    }

    /// @inheritdoc IERC721Copy
    function setMintableRule(
        uint256 creatorId,
        address mintable,
        bytes calldata mintableInitData
    ) external virtual override {
        require(
            _isApprovedOrCreator(_msgSender(), creatorId),
            'ERC721Copy: caller is not creator nor approved'
        );
        _mintableRules[creatorId] = mintable;
        if (mintable != address(0)) {
            IMintable(mintable).setupRule(creatorId, mintableInitData);
        }
    }

    /// @inheritdoc IERC721Copy
    function copy(address to, IMintable.MintInfo calldata mintInfo) external virtual override returns (uint256) {
        address mintAddress = _mintableRules[mintInfo.creatorId];
        require(mintAddress != address(0), 'ERC721Copy: No Mintable Rule');
        IMintable(mintAddress).isMintable(to, mintInfo);

        uint256 tokenId = _mint(to);
        _register(tokenId, mintInfo, mintAddress);

        return tokenId;
    }

    /// @inheritdoc IERC721Copy
    function revoke(uint256 tokenId) external virtual override  {
        require(isRevokable(tokenId), 'ERC721Copy: Non-revokable');
        require(
            _isApprovedOrCreator(_msgSender(), creatorOf(tokenId)),
            'ERC721Copy: caller is not creator nor approved'
        );
        _deregisterAndBurn(tokenId);
    }

    /// @inheritdoc IERC721Copy
    function destroy(uint256 tokenId) external virtual override {
        require(
            _isApprovedOrHolder(_msgSender(), tokenId),
            'ERC721Copy: caller is not token holder nor approved'
        );
        _deregisterAndBurn(tokenId);
    }

    /// @inheritdoc IERC721Copy
    function extend(
        uint256 tokenId,
        uint64 duration,
        bytes calldata data
    ) external virtual override returns (uint64) {
        require(isExtendable(tokenId), 'ERC721Copy: Non-extendable');
        IMintable(_copyInfo[tokenId].extendAt).isExtendable(
            holderOf(tokenId),
            _copyInfo[tokenId].expireAt,
            IMintable.MintInfo(
                _copyInfo[tokenId].creatorId,
                duration,
                _copyInfo[tokenId].transferable,
                _copyInfo[tokenId].updatable,
                _copyInfo[tokenId].revokable,
                _copyInfo[tokenId].extendable,
                _copyInfo[tokenId].statement,
                data
            )
        );

        // The expiration date will be extended by the duration if the token is not yet expired
        // Else, the expiration date will be added to the current block timestamp
        _copyInfo[tokenId].expireAt = _copyInfo[tokenId].expireAt < uint64(block.timestamp)
            ? _add(uint64(block.timestamp), duration)
            : _add(_copyInfo[tokenId].expireAt, duration);
        return _copyInfo[tokenId].expireAt;
    }

    /// @inheritdoc IERC721Copy
    function update(uint256 tokenId) external virtual override returns (string memory) {
        require(isUpdatable(tokenId), 'ERC721Copy: Non-updatable');
        require(
            _isApprovedOrOwner(_msgSender(), tokenId),
            'ERC721: caller is not token owner nor approved'
        );
        _copyInfo[tokenId].copyURI = _fetchURIForCopy(creatorOf(tokenId));
        return _copyInfo[tokenId].copyURI;
    }

    /**
     * @dev Register the information of a newly minted token Id.
     *
     * @param tokenId The copy NFT token Id
     * @param mintInfo See {IMintable-mintInfo}
     * @param mintAddress the address of the mintable rule contract
     */
    function _register(
        uint256 tokenId,
        IMintable.MintInfo calldata mintInfo,
        address mintAddress
    ) internal {
        uint256 copyCount = _copyCount[mintInfo.creatorId]++;
        _copys[mintInfo.creatorId][copyCount] = tokenId;
        _copyIndex[tokenId] = copyCount;

        // copy from creation
        _copyInfo[tokenId].creatorId = mintInfo.creatorId;
        _copyInfo[tokenId].copyURI = _fetchURIForCopy(mintInfo.creatorId);
        _copyInfo[tokenId].transferable = mintInfo.transferable;
        _copyInfo[tokenId].updatable = mintInfo.updatable;
        _copyInfo[tokenId].revokable = mintInfo.revokable;

        if (bytes(mintInfo.statement).length > 0) {
            _copyInfo[tokenId].statement = mintInfo.statement;
        }
        _copyInfo[tokenId].expireAt = _add(uint64(block.timestamp), mintInfo.duration);
        _copyInfo[tokenId].extendable = mintInfo.extendable;
        _copyInfo[tokenId].extendAt = mintAddress;
    }

    /**
     * @dev Remove the copy NFT token from the mappings. And clear the memory of the copy NFT token information
     *
     * @param tokenId The copy NFT token Id
     */
    function _deregister(uint256 tokenId) internal virtual {
        uint256 creatorId = creatorOf(tokenId);
        uint256 copyIndex = _copyIndex[tokenId];
        uint256 lastCopyIndex = --_copyCount[creatorId];
        if (copyIndex < lastCopyIndex) {
            _copys[creatorId][copyIndex] = _copys[creatorId][lastCopyIndex];
            _copyIndex[_copys[creatorId][lastCopyIndex]] = copyIndex;
        }
        delete _copys[creatorId][lastCopyIndex];
        delete _copyIndex[tokenId];
        delete _copyInfo[tokenId];
    }

    /**
     * @notice Deregister, clear up information related to a copy NFT and burn the NFT
     *
     * @param tokenId The copy NFT token Id
     *
     */
    function _deregisterAndBurn(uint256 tokenId) internal virtual {
        _deregister(tokenId);
        _burn(tokenId);
    }

    /**
     * @notice SafeMint a new copy NFT token
     *
     * @param to The address to mint the NFT token tos
     *
     * @return uint256 Returns the newly minted token Id
     */
    function _mint(address to) internal returns (uint256) {
        _copyIds.increment();
        uint256 tokenId = _copyIds.current();
        _safeMint(to, tokenId);
        return tokenId;
    }

    /**
     * @notice Fetch the token URI from the creator token, using the {IERC721Metadata-tokenURI} method
     * This function can be overriden to fetch contentUri from other functions
     *
     * @param creatorId The creator NFT token Id
     *
     * @return string Returns the token URI of the creator token
     */
    function _fetchURIForCopy(uint256 creatorId) internal view virtual returns (string memory) {
        return IERC721Metadata(_creatorContract).tokenURI(creatorId);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override {
        if (address(0) != from && address(0) != to) {
            // disable transfer if the token is not transferable. It does not apply to mint/burn action
            require(isTransferable(tokenId), 'ERC721Copy: Non-transferable');
        }
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function _isApprovedOrCreator(address spender, uint256 creatorId)
        internal
        view
        virtual
        returns (bool)
    {
        address owner = IERC721(_creatorContract).ownerOf(creatorId);
        return
            owner == spender ||
            IERC721(_creatorContract).getApproved(creatorId) == spender ||
            IERC721(_creatorContract).isApprovedForAll(owner, spender);
    }

    function _isApprovedOrHolder(address spender, uint256 tokenId)
        internal
        view
        virtual
        returns (bool)
    {
        return
            holderOf(tokenId) == spender ||
            getApproved(tokenId) == spender ||
            isApprovedForAll(holderOf(tokenId), spender);
    }

    /**
     * @dev return MAX_UINT64 if the sum exceed such value
     */
    function _add(uint64 a, uint64 b) internal pure returns (uint64) {
        return MAX_UINT64 - a < b ? MAX_UINT64 : a + b;
    }
    
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721Enumerable)
        returns (bool)
    {
        return interfaceId == type(IERC721Copy).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), 'ERC721Metadata: URI query for nonexistent token');
        return _copyInfo[tokenId].copyURI;
    }

    /**
     * @dev See {IERC721-ownerOf}.
     *
     * @notice this function overrides the IERC721 ownerOf function. It first runs the parant implementation.
     * Then, it checks the expiry of the token. The Expired token will return address(0) as owner, indicating
     * that the token is now invalid. The token holder should extend the expiry to enable the token functions
     * again
     *
     */
    function ownerOf(uint256 tokenId) public view virtual override returns (address) {
        // run ownerOf first to screen for non exist token error
        address owner = super.ownerOf(tokenId);
        return isExpired(tokenId) ? address(0) : owner;
    }

    /// @inheritdoc IERC721Copy
    function holderOf(uint256 tokenId) public view virtual override returns (address) {
        return super.ownerOf(tokenId);
    }

    /// @inheritdoc IERC721Copy
    function getCreatorContract() external view virtual override returns (address) {
        return _creatorContract;
    }

    /**
     * @return uint256 Returns the total number of minted copy NFT tokens
     */
    function getTokenCount() external view virtual returns (uint256) {
        return _copyIds.current();
    }

    /**
     * @param creatorId The creator NFT token Id
     *
     * @return uint256 Returns the total number of copy NFT tokens minted based on a particular creator NFT token
     */
    function getCopyCount(uint256 creatorId) external view virtual returns (uint256) {
        return _copyCount[creatorId];
    }

    /**
     * @param creatorId The creator NFT token Id
     * @param index The index of the list of copy NFTs minted based on the creatorId, index starts from 1
     *
     * @return uint256 Returns the copy NFT tokenId of a particular creator NFT token
     */
    function getCopyByIndex(uint256 creatorId, uint256 index)
        external
        view
        virtual
        returns (uint256)
    {
        require(index < _copyCount[creatorId], 'ERC721Copy: Index Out Of Bounds');
        return _copys[creatorId][index];
    }

    /// @inheritdoc IERC721Copy
    function isTransferable(uint256 tokenId) public view virtual override returns (bool) {
        return _copyInfo[tokenId].transferable && !isExpired(tokenId);
    }

    /// @inheritdoc IERC721Copy
    function isUpdatable(uint256 tokenId) public view virtual override returns (bool) {
        return _copyInfo[tokenId].updatable && !isExpired(tokenId);
    }

    /// @inheritdoc IERC721Copy
    function isRevokable(uint256 tokenId) public view virtual override returns (bool) {
        return _copyInfo[tokenId].revokable || isExpired(tokenId);
    }

    /// @inheritdoc IERC721Copy
    function isExpired(uint256 tokenId) public view virtual override returns (bool) {
        return _copyInfo[tokenId].expireAt < uint64(block.timestamp);
    }

    /// @inheritdoc IERC721Copy
    function isExtendable(uint256 tokenId) public view virtual override returns (bool) {
        return _copyInfo[tokenId].extendable;
    }

    /// @inheritdoc IERC721Copy
    function creatorOf(uint256 tokenId) public view virtual override returns (uint256) {
        return _copyInfo[tokenId].creatorId;
    }

    /// @inheritdoc IERC721Copy
    function expireAt(uint256 tokenId) external view virtual override returns (uint64) {
        return _copyInfo[tokenId].expireAt;
    }

    /// @inheritdoc IERC721Copy
    function getMintableRule(uint256 creatorId) external view virtual override returns (address) {
        return _mintableRules[creatorId];
    }

    /// @inheritdoc IERC721Copy
    function getStatement(uint256 tokenId) external view virtual override returns (string memory) {
        return _copyInfo[tokenId].statement;
    }
}

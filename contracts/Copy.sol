// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import '@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol';
import '@openzeppelin/contracts/access/Ownable.sol';

import './interfaces/IERC721Copy/IMintable.sol';
import './interfaces/ICopy.sol';

import 'hardhat/console.sol';

/**
 * @notice This is an implementation of the ICopy interface.
 */
contract Copy is Ownable, ERC721Enumerable, ICopy {
    using Strings for uint256;

    event WhiteListMintable(address mitnable, bool state);

    uint64 private constant MAX_UINT64 = 0xffffffffffffffff;
    address internal _creatorContract;
    // mapping for tokenId generation address => creatorId => tokenId
    mapping(address=>mapping(uint256=>uint256)) private _tokenCounter;

    // tokenId => CopyInfo
    mapping(uint256 => CopyInfo) private _copyInfo;
    // creatorId => index => tokenId
    mapping(uint256 => mapping(uint256 => uint256)) private _copys;
    // creatorId => copy_count
    mapping(uint256 => uint256) private _copyCount;
    // tokenId => index
    mapping(uint256 => uint256) private _copyIndex;

    // creatorId => copyRules (For Record Keeping, mint info cannot be deleted once set)
    mapping(uint256 => bytes32[]) _copyHashes;
    mapping(bytes32 => MintInfo) private _mintInfo;
    mapping(bytes32 => State) private _states;

    mapping(address => bool) private _whiteListedMintable;

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

    function whiteListMintableContract(
        address mintable
    ) external onlyOwner {
        _whiteListedMintable[mintable] = true;
        emit WhiteListMintable(mintable, true);
    }

    function removeMintableContract(
        address mintable
    ) external onlyOwner {
        _whiteListedMintable[mintable] = false;
        emit WhiteListMintable(mintable, false);
    }

    
    /// @inheritdoc IERC721Copy
    function setMintableRule(
        MintInfo memory mintInfo,
        bytes calldata mintableInitData
    ) external virtual override returns (bytes32) {
        require(
            _isApprovedOrCreator(_msgSender(), mintInfo.creatorId),
            'Copy: caller is not creator nor approved'
        );
        require(_whiteListedMintable[mintInfo.mintable], 'Copy: Invalid Mintable Rule');

        bytes32 copyHash = _getHash(mintInfo);
        
        if ( _states[copyHash] == State.NIL ) {
            _copyHashes[mintInfo.creatorId].push(copyHash);
            _mintInfo[copyHash] = mintInfo;
        }

        _states[copyHash] = State.EXIST;
                
        IMintable(mintInfo.mintable).setupRule(copyHash, mintableInitData);
                
        emit SetMintableRule(copyHash, mintInfo);
        return copyHash;
    }

    /// @inheritdoc IERC721Copy
    function pauseMintableRule(
        bytes32 copyHash
    ) external virtual override {
        require(
            _isApprovedOrCreator(_msgSender(), _mintInfo[copyHash].creatorId),
            'Copy: caller is not creator nor approved'
        );
        _states[copyHash] = State.PAUSED; // disable copying
        emit PauseMintableRule(copyHash);
    }

    /// @inheritdoc IERC721Copy
    function create(address to, bytes32 copyHash, uint64 duration) external virtual payable override returns (uint256) {
        require(_states[copyHash] == State.EXIST, 'Copy: Copying Disabled');
        IMintable(_mintInfo[copyHash].mintable).isMintable{value: msg.value}(to, copyHash, duration);
        
        uint256 tokenId = _mintToken(to, _mintInfo[copyHash].creatorId);
        _register(tokenId, copyHash, duration);

        emit Create(tokenId, copyHash, _copyInfo[tokenId].expireAt);
        return tokenId;
    }
    
    /// @inheritdoc IERC721Copy
    function revoke(uint256 tokenId) external virtual override  {
        require(isRevokable(tokenId), 'Copy: Non-revokable');
        require(
            _isApprovedOrCreator(_msgSender(), creatorOf(tokenId)),
            'Copy: caller is not creator nor approved'
        );
        _deregisterAndBurn(tokenId);
        emit Revoke(tokenId);
    }

    /// @inheritdoc IERC721Copy
    function destroy(uint256 tokenId) external virtual override {
        require(
            _isApprovedOrOwner(_msgSender(), tokenId),
            'ERC721: caller is not token owner nor approved'
        );
        _deregisterAndBurn(tokenId);
        emit Destroy(tokenId);
    }

    /// @inheritdoc IERC721Copy
    function extend(
        uint256 tokenId,
        uint64 duration
    ) external virtual payable override returns (uint64) {
        bytes32 copyHash = _copyInfo[tokenId].copyHash;
        require(State.EXIST != State.NIL, 'Copy: Mint info not set'); 
        require(isExtendable(tokenId), 'Copy: Non-extendable');
        
        IMintable(_mintInfo[copyHash].mintable).isExtendable{value: msg.value}(
            ownerOf(tokenId),
            copyHash,
            duration // duration to extend
        );
        // The expiration date will be extended by the duration if the token is not yet expired
        // Else, the expiration date will be added to the current block timestamp
        _copyInfo[tokenId].expireAt = _copyInfo[tokenId].expireAt < uint64(block.timestamp)
            ? _add(uint64(block.timestamp), duration)
            : _add(_copyInfo[tokenId].expireAt, duration);
        emit Extend(tokenId, _copyInfo[tokenId].expireAt);
        return _copyInfo[tokenId].expireAt;
    }

    /// @inheritdoc IERC721Copy
    function update(uint256 tokenId) external virtual override returns (string memory) {
        require(isUpdatable(tokenId), 'Copy: Non-updatable');
        require(
            _isApprovedOrOwner(_msgSender(), tokenId),
            'ERC721: caller is not token owner nor approved'
        );
        _copyInfo[tokenId].copyURI = _fetchURIForCopy(creatorOf(tokenId));
        emit Update(tokenId, _copyInfo[tokenId].copyURI);
        return _copyInfo[tokenId].copyURI;
    }

    /**
     * @dev Register the information of a newly minted token Id.
     *
     * @param tokenId The copy NFT token Id
     * @param copyHash The hash of the copy configuration
     */
    function _register(
        uint256 tokenId,
        bytes32 copyHash,
        uint64 duration
    ) internal {
        uint256 creatorId = _mintInfo[copyHash].creatorId;
        uint256 copyCount = ++_copyCount[creatorId];
        _copys[creatorId][copyCount] = tokenId;
        _copyIndex[tokenId] = copyCount;

        _copyInfo[tokenId].copyURI = _fetchURIForCopy(creatorId);
        _copyInfo[tokenId].expireAt = _add(uint64(block.timestamp), duration);
        _copyInfo[tokenId].copyHash = copyHash;
    }

    /**
     * @dev Remove the copy NFT token from the mappings. And clear the memory of the copy NFT token information
     *
     * @param tokenId The copy NFT token Id
     */
    function _deregister(uint256 tokenId) internal virtual {
        uint256 creatorId = creatorOf(tokenId);
        uint256 copyIndex = _copyIndex[tokenId];
        uint256 lastCopyIndex = _copyCount[creatorId]--;
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
     * @param creatorId The creatorId 
     *
     * @return uint256 Returns the newly minted token Id
     */
    function _mintToken(address to, uint256 creatorId) internal returns (uint256) {
        _tokenCounter[to][creatorId]++;
        uint256 tokenId = uint256(keccak256(abi.encode(to, creatorId, _tokenCounter[to][creatorId])));
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
            require(isTransferable(tokenId), 'Copy: Non-transferable');
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

    /**
     * @dev return MAX_UINT64 if the sum exceed such value
     */
    function _add(uint64 a, uint64 b) internal pure returns (uint64) {
        return MAX_UINT64 - a < b ? MAX_UINT64 : a + b;
    }

    function _getHash(
        MintInfo memory mintInfo
    ) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    mintInfo.creatorId,
                    mintInfo.mintable,
                    mintInfo.transferable,
                    mintInfo.revokable,
                    mintInfo.extendable,
                    mintInfo.updatable,
                    mintInfo.statement
                )
            );
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
        return interfaceId == type(ICopy).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), 'ERC721Metadata: URI query for nonexistent token');
        return _copyInfo[tokenId].copyURI;
    }

    /// @inheritdoc IERC721Copy
    function getCreatorContract() external view virtual override returns (address) {
        return _creatorContract;
    }

    /// @inheritdoc ICopy
    function getCopyCount(uint256 creatorId) external view virtual override returns (uint256) {
        return _copyCount[creatorId];
    }

    /// @inheritdoc ICopy
    function getCopyByIndex(uint256 creatorId, uint256 index)
        external
        view
        virtual
        override 
        returns (uint256)
    {
        require(index <= _copyCount[creatorId], 'Copy: Index Out Of Bounds');
        return _copys[creatorId][index];
    }

    /// @inheritdoc ICopy
    function getCopyInfo(uint256 tokenId) external view override returns (CopyInfo memory) {
        return _copyInfo[tokenId];
    }

    /// @inheritdoc IERC721Copy
    function isTransferable(uint256 tokenId) public view virtual override returns (bool) {
        return _mintInfo[_copyInfo[tokenId].copyHash].transferable && !isExpired(tokenId);
    }

    /// @inheritdoc IERC721Copy
    function isUpdatable(uint256 tokenId) public view virtual override returns (bool) {
        return _mintInfo[_copyInfo[tokenId].copyHash].updatable && !isExpired(tokenId);
    }

    /// @inheritdoc IERC721Copy
    function isRevokable(uint256 tokenId) public view virtual override returns (bool) {
        return _mintInfo[_copyInfo[tokenId].copyHash].revokable || isExpired(tokenId);
    }

    /// @inheritdoc IERC721Copy
    function isExpired(uint256 tokenId) public view virtual override returns (bool) {
        return _copyInfo[tokenId].expireAt < uint64(block.timestamp);
    }

    /// @inheritdoc IERC721Copy
    function isExtendable(uint256 tokenId) public view virtual override returns (bool) {
        return _mintInfo[_copyInfo[tokenId].copyHash].extendable;
    }

    /// @inheritdoc IERC721Copy
    function creatorOf(uint256 tokenId) public view virtual override returns (uint256) {
        return _mintInfo[_copyInfo[tokenId].copyHash].creatorId;
    }

    /// @inheritdoc IERC721Copy
    function expireAt(uint256 tokenId) external view virtual override returns (uint64) {
        return _copyInfo[tokenId].expireAt;
    }

    /// @inheritdoc IERC721Copy
    function getMintableRule(uint256 tokenId) external view virtual override returns (address) {
        return _mintInfo[_copyInfo[tokenId].copyHash].mintable;
    }

    /// @inheritdoc ICopy
    function getStatement(uint256 tokenId) external view virtual override returns (Statement) {
        return _mintInfo[_copyInfo[tokenId].copyHash].statement;
    }

    /// @inheritdoc ICopy
    function getMintInfo(bytes32 copyHash) external view virtual override returns (MintInfo memory) {
        return _mintInfo[copyHash];
    }

    /// @inheritdoc ICopy
    function getCopyHashes(uint256 creatorId) external view virtual override returns (bytes32[] memory) {
        return _copyHashes[creatorId];
    }

    /// @inheritdoc ICopy
    function hasValidCopy(address collector, uint256 creatorId) external view virtual override returns (bool) {
        uint256 count = balanceOf(collector);
        for (uint256 i = 0; i < count; i++) {
            uint256 copyId = tokenOfOwnerByIndex(collector, i);
            if (creatorOf(copyId) == creatorId && ! isExpired((copyId))) {
                return true;
            }
        }
        return false;
    }

    /// @inheritdoc ICopy
    function tokenCounter(address collector, uint256 creatorId) external view override returns (uint256) {
        return _tokenCounter[collector][creatorId];
    }
}

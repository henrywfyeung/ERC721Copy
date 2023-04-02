// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import '@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol';
import '@openzeppelin/contracts/utils/cryptography/ECDSA.sol';

import './interfaces/ICreator.sol';

import 'hardhat/console.sol';

contract Creator is ICreator, ERC721Enumerable {
    using Strings for uint256;

    event Publish(address to, uint256 pubId, string contentUri);
    event Update(uint256 pubId, string contentUri);

    string private constant COPYRIGHT_TRANSFER_NOTICE = 'By signing this statement, I confirm that I am the full copyright holder of the data pointed to by the contentUri included in this signature. I willingly give up all my copyright to the holder of the newly minted NFT, in the condition that the copyright will be forever bound to, and transfer together with that newly minted NFT.';
    string private constant COPYRIGHT_ERR = 'Invalid copyright signature';
    string private constant OWNER_ERR = 'Invalid owner';
    string private constant TIME_ERR = 'Expired Signature';

    mapping(address=>uint256) private _tokenCounter;

    mapping(uint256 => string) private _tokenUri;

    constructor(string memory name_, string memory symbol_) ERC721(name_, symbol_) {}

    modifier onlyOwner(uint256 pubId) {
        require(msg.sender == ownerOf(pubId), OWNER_ERR);
        _;
    }

    function createWithOperator(
        address to,
        address operator,
        string memory contentUri,
        PermSig memory permSig
    ) external override returns (uint256) {
        uint256 pubId = _create(to, contentUri, permSig);
        _approve(operator, pubId);
        return pubId;
    }

    function create(
        address to,
        string memory contentUri,
        PermSig memory permSig
    ) external override returns (uint256) {
        return _create(to, contentUri, permSig);
    }

    function _create(
        address to,
        string memory contentUri,
        PermSig memory permSig
    ) internal virtual returns (uint256) {
        require(_recoverSig(contentUri, permSig) == to, COPYRIGHT_ERR);
        uint256 pubId = _mintToken(to);
        _tokenUri[pubId] = contentUri;

        emit Publish(to, pubId, contentUri);

        return pubId;
    }
    
    function update(
        uint256 pubId, 
        string memory contentUri,
        PermSig memory permSig
    ) external override onlyOwner(pubId) {
        require(_recoverSig(contentUri, permSig) == ownerOf(pubId), COPYRIGHT_ERR);
        _tokenUri[pubId] = contentUri;
        emit Update(pubId, contentUri);
    }

    function burn(uint256 pubId) external override onlyOwner(pubId) {
        _burn(pubId);
    }

    function _mintToken(address to) internal returns (uint256) {
        _tokenCounter[to]++;
        uint256 tokenId = uint256(keccak256(abi.encode(to, _tokenCounter[to])));
        _safeMint(to, tokenId);
        return tokenId;
    }
    
    function _recoverSig(
        string memory contentUri,
        PermSig memory permSig
    ) internal view returns (address recoveredSender) {
        // prove that the tags are signed by the valid dapp
        // reject signature past deadline
        require(permSig.deadline > block.timestamp, TIME_ERR);
        // convert app list into bytes
        bytes32 messageData = keccak256(
            abi.encode(contentUri, COPYRIGHT_TRANSFER_NOTICE, permSig.deadline)
        );
        bytes32 message = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messageData));

        (recoveredSender, ) = ECDSA.tryRecover(
            message,
            permSig.v,
            permSig.r,
            permSig.s
        );
    }

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 pubId) public view virtual override returns (string memory) {
        require(_exists(pubId), 'ERC721Metadata: URI query for nonexistent token');
        return _tokenUri[pubId];
    }
    
    function exists(uint256 pubId) external view virtual override returns (bool) {
        return _exists(pubId);
    }

    function tokenCounter(address creator) external view returns (uint256) {
        return _tokenCounter[creator];
    }

    /** 
     * @dev Get the tokenId of the new n-th token, with offset=0 as the next token, offset=1 as the next next token, etc
     */
    function newTokenId(address creator, uint256 offset) external view returns (uint256) {
        return uint256(keccak256(abi.encode(creator, _tokenCounter[creator] + offset + 1)));
    }
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import '@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol';
import '@openzeppelin/contracts/utils/Counters.sol';

/**
 * @notice This is one example of an abitrary NFT contract that has a function of getting the tokenURI.
 */
contract MockNFT is ERC721Enumerable {
    
    using Strings for uint256;
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    
    mapping(uint256 => string) private _tokenURIs;

    constructor (string memory name_, string memory symbol_) ERC721(name_, symbol_) {}

    function mintToken(string memory contentUri) external returns (uint256) {
        _tokenIds.increment();

        uint256 id = _tokenIds.current();
        _safeMint(msg.sender, id);
        _setTokenURI(id, contentUri);

        return id;
    }

    function _setTokenURI(uint256 tokenId, string memory _tokenURI) internal virtual {
        require(_exists(tokenId), 'ERC721URIStorage: URI set of nonexistent token');
        _tokenURIs[tokenId] = _tokenURI;
    }

    /**
     * @notice Obtain the contentUri of the creator token.
     *
     * @param tokenId The creator token Id
     *
     * @return string Returns the contentUri
     */
    function getTokenURIs(uint256 tokenId) public view returns (string memory) {
        return _tokenURIs[tokenId];
    }

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), 'ERC721Metadata: URI query for nonexistent token');
        return _tokenURIs[tokenId];
    }

    /**
     * @notice The total number of creator tokens created
     *
     * @return uint256 Returns the total number of creator tokens
     */
    function getTokenCount() public view returns (uint256) {
        return _tokenIds.current();
    }

}

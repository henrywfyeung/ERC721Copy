// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import '@openzeppelin/contracts/token/ERC721/IERC721.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol';

import '../interfaces/ICreator.sol';
import '../interfaces/ICopy.sol';
import '../interfaces/IPaidMintable.sol';

import '../libraries/Pagination.sol';

import 'hardhat/console.sol';

contract Helper {

    address private immutable _creatorContract;
    address private immutable _copyContract;
    address private immutable _mintableContract;

    constructor (
        address creatorContract_,
        address copyContract_,
        address mintableContract_
    ) {
        _creatorContract = creatorContract_;
        _copyContract = copyContract_;
        _mintableContract = mintableContract_;
    }
    
    function createWithMintables(
        address to,
        string memory contentUri,
        ICreator.PermSig memory permSig,
        ICopy.MintInfo[] memory mintInfo,
        bytes[] calldata mintableInitData
    ) external {
        uint256 creatorId = ICreator(_creatorContract).createWithOperator(to, address(this), contentUri, permSig);

        for ( uint256 i = 0 ; i < mintInfo.length ; i++ ) {
            mintInfo[i].creatorId = creatorId;
            ICopy(_copyContract).setMintableRule(mintInfo[i], mintableInitData[i]);
        }

        // remove the approval to prevent potential exploits
        // IERC721(_creatorContract).approve(address(0), creatorId);
    }

    /*
     * Function for the user to follow multiple profiles with one call.
     */
    function batchCollect(address to, bytes32[] calldata copyHash, uint64[] calldata duration, uint256[] calldata values)
        external payable
        returns (uint256[] memory)
    {
        uint256[] memory copyIds = new uint256[](copyHash.length);
        for (uint256 i = 0; i < copyHash.length; i++) {
            copyIds[i] = ICopy(_copyContract).create{value: values[i]}(to, copyHash[i], duration[i]);
        }
        return copyIds;
    }
    
    /*
     * Function for the certificate creator to issue a batch of Issue NFTs to recipients.
     */
    function batchCreate(address[] memory recipients, bytes32 copyHash, uint64 duration, uint256[] calldata values)
        external payable
        returns (uint256[] memory)
    {
        uint256[] memory copyIds = new uint256[](recipients.length);
        for (uint256 i = 0; i < recipients.length; i++) {
            copyIds[i] = ICopy(_copyContract).create{value: values[i]}(recipients[i], copyHash, duration);
        }
        return copyIds;
    }

    // view functions

    struct CreatorView {
        uint256 creatorId;
        address holder;
        string tokenURI;
        uint256 copies;
        uint256 rules;
    }

    struct CopyView {
        uint256 copyId;
        uint256 creatorId;
        address holder;
        string tokenURI;
        uint64 expireAt;
        MintableView mintable;
    }

    struct MintableView {
        ICopy.MintInfo mintInfo;
        IPaidMintable.ValidationInfo valInfo;
        uint256 count;
        bytes32 copyHash;
    }

    struct CreatorFullView {
        CreatorView creation;
        MintableView[] mintable;
    }

    struct CreatorPaginationView {
        CreatorView[] creators;
        Pagination.PaginationMetaView meta;
    }

    struct CopyPaginationView {
        CopyView[] copies;
        Pagination.PaginationMetaView meta;
    }

    function getCreatorTokenById(
        uint256 creatorId
    ) public view returns (CreatorView memory) {
        CreatorView memory creatorView = CreatorView(
            creatorId,
            IERC721(_creatorContract).ownerOf(creatorId),
            IERC721Metadata(_creatorContract).tokenURI(creatorId),
            ICopy(_copyContract).getCopyCount(creatorId),
            ICopy(_copyContract).getCopyHashes(creatorId).length
        );
        return creatorView;
    }

    function getCopyTokenById(
        uint256 copyId
    ) public view returns (CopyView memory) {
        ICopy.CopyInfo memory copyInfo = ICopy(_copyContract).getCopyInfo(copyId);
        CopyView memory copyView = CopyView(
            copyId,
            ICopy(_copyContract).creatorOf(copyId),
            IERC721(_copyContract).ownerOf(copyId),
            copyInfo.copyURI,
            copyInfo.expireAt,
            getMintableByHash(copyInfo.copyHash)
        );
        return copyView;
    }

    function getMintableByHash(
        bytes32 copyHash
    ) public view returns (MintableView memory) {
        MintableView memory mintable = MintableView(
            ICopy(_copyContract).getMintInfo(copyHash),
            IPaidMintable(_mintableContract).getValidationInfo(copyHash),
            IPaidMintable(_mintableContract).getMintCount(copyHash),
            copyHash
        );
        return mintable;
    }

    /**
     * @dev Get CreatorIds By Address
     */
    function getCreatorTokensByAddress(
        address creator,
        uint256 skip,
        uint256 limit
    ) public view returns (CreatorPaginationView memory) {
        uint256 count = IERC721(_creatorContract).balanceOf(creator);

        (uint256 last, uint256 _limit) = Pagination._paginationHandler(skip, limit, count);

        CreatorView[] memory creators = new CreatorView[](_limit);

        for (uint256 i = skip; i < last; i++) {
            uint256 creatorId = IERC721Enumerable(_creatorContract).tokenOfOwnerByIndex(creator, i);
            creators[i - skip] = getCreatorTokenById(creatorId);
        }

        CreatorPaginationView memory _creatorPaginationView = CreatorPaginationView(
            creators,
            Pagination._paginationResponseHandler(skip, limit, count)
        );

        return _creatorPaginationView;
    }

    /**
     * @dev Get All CreatorIds
     */
    function getCreatorTokens(
        uint256 skip,
        uint256 limit
    ) external view returns (CreatorPaginationView memory) {
        uint256 count = IERC721Enumerable(_creatorContract).totalSupply();
        (uint256 last, uint256 _limit) = Pagination._paginationHandler(skip, limit, count);
        
        CreatorView[] memory creators = new CreatorView[](_limit);
        
        for (uint256 i = skip; i < last; i++) {
            uint256 creatorId = IERC721Enumerable(_creatorContract).tokenByIndex(i);
            creators[i - skip] = getCreatorTokenById(creatorId);
        }
        
        CreatorPaginationView memory _creatorPaginationView = CreatorPaginationView(
            creators,
            Pagination._paginationResponseHandler(skip, limit, count)
        );
        
        return _creatorPaginationView;
    }


    /**
     * @dev Get CopyIds By Address
     */
    function getCopyTokensByAddress(
        address collector,
        uint256 skip,
        uint256 limit
    ) external view returns (CopyPaginationView memory) {
        uint256 count = IERC721(_copyContract).balanceOf(collector);
        
        (uint256 last, uint256 _limit) = Pagination._paginationHandler(skip, limit, count);
        
        CopyView[] memory copies = new CopyView[](_limit);

        for (uint256 i = skip; i < last; i++) {
            uint256 copyId = IERC721Enumerable(_copyContract).tokenOfOwnerByIndex(collector, i);
            copies[i - skip] = getCopyTokenById(copyId);
        }

        CopyPaginationView memory _copyPaginationView = CopyPaginationView(
            copies,
            Pagination._paginationResponseHandler(skip, limit, count)
        );

        return _copyPaginationView;   
    }   

    /**
     * Get all CopyId
     */
    function getCopyTokens(
        uint256 skip,
        uint256 limit
    ) external view returns (CopyPaginationView memory) {
        uint256 count = IERC721Enumerable(_copyContract).totalSupply();
        
        (uint256 last, uint256 _limit) = Pagination._paginationHandler(skip, limit, count);
        
        CopyView[] memory copies = new CopyView[](_limit);

        for (uint256 i = skip; i < last; i++) {
            uint256 copyId = IERC721Enumerable(_copyContract).tokenByIndex(i);
            copies[i - skip] = getCopyTokenById(copyId);
        }

        CopyPaginationView memory _copyPaginationView = CopyPaginationView(
            copies,
            Pagination._paginationResponseHandler(skip, limit, count)
        );

        return _copyPaginationView;        
    } 

    /**
     * @dev Get CopyIds By Creator
     */
    function getCopyTokensByCreator(
        uint256 creatorId,
        uint256 skip,
        uint256 limit
    ) external view returns (CopyPaginationView memory){
        uint256 count = ICopy(_copyContract).getCopyCount(creatorId);
        
        (uint256 last, uint256 _limit) = Pagination._paginationHandler(skip, limit, count);
        
        CopyView[] memory copies = new CopyView[](_limit);

        for (uint256 i = skip; i < last; i++) {
            uint256 copyId = ICopy(_copyContract).getCopyByIndex(creatorId, i+1);
            copies[i - skip] = getCopyTokenById(copyId);
        }

        CopyPaginationView memory _copyPaginationView = CopyPaginationView(
            copies,
            Pagination._paginationResponseHandler(skip, limit, count)
        );

        return _copyPaginationView;   
    }

    /**
     * Get all CopyIds By Address
     */
    function getMintInfoByCreator(
        uint256 creatorId
    ) external view returns (CreatorFullView memory){
        
        bytes32[] memory copyHashes = ICopy(_copyContract).getCopyHashes(creatorId);

        CreatorFullView memory creatorFullView = CreatorFullView(
            getCreatorTokenById(creatorId),
            new MintableView[](copyHashes.length)
        );

        for (uint256 i = 0; i < copyHashes.length; i++) {
            creatorFullView.mintable[i] = getMintableByHash(copyHashes[i]);
        }
        return creatorFullView;
    }

}
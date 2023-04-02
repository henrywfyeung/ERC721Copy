// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import './interfaces/IPaidMintable.sol';
import './interfaces/ICopy.sol';

interface IERC721 {
    function ownerOf(uint256 tokenId) external view returns (address owner);
    function balanceOf(address owner) external view returns (uint256);
}

interface IERC20 {
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external;
}

/**
 * @notice This contract is an implementation of the IMintable interface. It is used to enable mintable 
 * and extending a token with a fee charged. The creator will need to setup rules for copier/collector 
 * to follow before a copy token is minted / extended. 
 * 
 */
contract Mintable is IPaidMintable {

    event SetupRule(
        bytes32 copyHash,
        ValidationInfo validationInfo
    );
    
    address private immutable _copyContract;
    mapping(bytes32 => ValidationInfo) private _validationInfo;
    mapping(bytes32 => uint256) private _count;

    modifier onlyCopy {
        require(msg.sender == _copyContract, "Mintable: Invalid Contract Call");
        _;
    }

    constructor (address copyContract_) {
        _copyContract = copyContract_;
    }

    /// @inheritdoc IMintable
    function setupRule(bytes32 copyHash, bytes calldata ruleData) external override onlyCopy {
        (ValidationInfo memory valInfo) = abi.decode(ruleData, (ValidationInfo));

        // require(valInfo.start > uint64(block.timestamp), "Mintable: Invalid Start Time");
        _validationInfo[copyHash] = valInfo;
        emit SetupRule(copyHash, valInfo);
    }
    
    /// @inheritdoc IMintable
    function isMintable(address to, bytes32 copyHash,  uint64 duration) external payable override onlyCopy {
        _validateMint(to, copyHash, duration);
        ++_count[copyHash];
    }

    /// @inheritdoc IMintable
    function isExtendable(address to, bytes32 copyHash, uint64 duration) external payable override onlyCopy {
        _validateExtend(to, copyHash, duration);
    }
    
    // no reentrant**
    function _validateMint(
        address to,
        bytes32 copyHash,
        uint64 duration
    ) internal {
        ValidationInfo memory valInfo = _validationInfo[copyHash];
        // check start time
        require(valInfo.start < uint64(block.timestamp), "Mintable: Minting Period Not Started");

        // check deadline (timestamp - start to prevent overflow)
        require(valInfo.time > uint64(block.timestamp) - valInfo.start, "Mintable: Minting Period Ended");

        // check limit
        require(valInfo.limit > _count[copyHash], "Mintable: Minting Limit Reached");

        // check token binding
        if (valInfo.requiredERC721Token != address(0)) {
            require(IERC721(valInfo.requiredERC721Token).balanceOf(to) > 0, "Mintable: Required ERC721 Token has Zero Balance");
        }
        
        uint256 durationFee = valInfo.mintAmount;
        if (durationFee == 0) return;
        uint256 fee = valInfo.fragmented ? duration  * durationFee / valInfo.duration : durationFee;

        address creatorAddress = IERC721(
                ICopy(msg.sender).getCreatorContract()
            ).ownerOf(ICopy(msg.sender).getMintInfo(copyHash).creatorId);

        // address(0) is the native token
        if (valInfo.feeToken == address(0)) {
            require(msg.value >= fee, "Mintable: Insufficient Native Tokens");
            payable(creatorAddress).transfer(fee);
        } else {
            IERC20(valInfo.feeToken).transferFrom(
                to,
                creatorAddress,
                fee
            );
        }
    }

    // no reentrant**
    function _validateExtend(
        address to,
        bytes32 copyHash,
        uint64 duration
    ) internal {
        ValidationInfo memory valInfo = _validationInfo[copyHash];
        
        uint256 durationFee = valInfo.mintAmount;
        if (durationFee == 0) return;
        
        uint256 fee = valInfo.fragmented ? duration  * durationFee / valInfo.duration : durationFee;

        address creatorAddress = IERC721(
                ICopy(msg.sender).getCreatorContract()
            ).ownerOf(ICopy(msg.sender).getMintInfo(copyHash).creatorId);

        // address(0) is the native token
        if (valInfo.feeToken == address(0)) {
            require(msg.value >= fee, "Mintable: Insufficient Native Tokens");
            payable(creatorAddress).transfer(fee);
        } else {
            IERC20(valInfo.feeToken).transferFrom(
                to,
                creatorAddress,
                fee
            );
        }
    }

    function getValidationInfo(
        bytes32 copyHash
    ) external view override returns (ValidationInfo memory) {
        return _validationInfo[copyHash];
    }

    function getMintCount(
        bytes32 copyHash
    ) external view override returns (uint256) {
        return _count[copyHash];
    }

}

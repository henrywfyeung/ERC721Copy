// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import './IERC721Copy/IMintable.sol';

interface IPaidMintable is IMintable{
    
    /**
    * @dev the fee to be paid before minting / extending a copy token
    * 
    * @param feeToken The contract address of the fee token, i.e. USDT token contract address
    * @param mintAmount The token amount that is required for minting a copy token
    * @param extendAmount The token amount that is required for extending a copy token
    * @param fragmented Whether fragmented duration is enabled
    * @param duration The time duration that should add to the NFT token after mint
    */
    struct ValidationInfo {
        address feeToken;
        uint64 duration;        
        bool fragmented;
        uint256 mintAmount;
        uint256 extendAmount;
        address requiredERC721Token;
        uint256 limit;
        uint64  start;
        uint64  time;
    }

    /**
    * @dev This function is called to get the validation rule for a copy token
    *
    * @param copyHash the hash of the copy token
    * @return validationInfo the validation rule for the copy token
    */
    function getValidationInfo(bytes32 copyHash) external view returns (ValidationInfo memory);

}
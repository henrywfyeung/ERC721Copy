// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

interface ICreator {
    
    /**
     * @dev the permission signature for the creator to create a new NFT tokens
     * @param deadline The deadline of the permission signature
     * @param v The v of the permission signature
     * @param r The r of the permission signature
     * @param s The s of the permission signature
     */
    struct PermSig {
        uint256 deadline;
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    /**
     * @dev This function is called to mint a creator token and at the same time entrust an operator contract to manage the token
     *
     * @param to address of creator token receiver
     * @param operator address of the operator contract
     * @param contentUri the content uri of the creator token
     * @param permSig the permission signature for the creator to create a new NFT tokens 
     */
    function createWithOperator(
        address to,
        address operator,
        string memory contentUri,
        PermSig memory permSig
    ) external returns (uint256);

    /**
     * @dev This function is called to mint a creator token
     *
     * @param to address of creator token receiver
     * @param contentUri the content uri of the creator token
     * @param permSig the permission signature for the creator to create a new NFT tokens 
     */
    function create(
        address to,
        string memory contentUri,
        PermSig memory permSig
    ) external returns (uint256);

    /**
     * @dev This function is called to update the content uri of a creator token
     *
     * @param pubId the public id of the creator token
     * @param contentUri the content uri of the creator token
     * @param permSig the permission signature for the creator to create a new NFT tokens 
     */
    function update(
        uint256 pubId, 
        string memory contentUri,
        PermSig memory permSig
    ) external;

    /**
     * @dev This function is called to burn a creator token. By burning the creator token, 
     * the author permanently lost control over the management of the copies.
     *
     * @param pubId the public id of the creator token
     */
    function burn(uint256 pubId) external;

    /**
     * @dev This function is called to check whether a creator token exists
     *
     * @param pubId the public id of the creator token
     */
    function exists(uint256 pubId) external view returns (bool);

}
---
eip: <to be assigned>
title: Conditional Copy NFT
description: Creation of copies of an NFT Token under conditions specfied by the creator
author: Henry Yeung (@henrywfyeung), XB.eth
discussions-to: <URL>
status: Draft
type: Standards Track
category (*only required for Standards Track): ERC
created: 2022-08-30
requires (*optional): 165, 721
---

## Abstract
This standard is an extension of [EIP-721](./eip-721.md). This standard enables a creator token, i.e. token from any EIP-721 compliant contracts with metadata extension, to work as a master copy that conditionally allows the production of replicas with a specific copyright delegation valid within a fixed time period. 

The Creator, who holds the master copy, can set up Mintable rules specifying the condition of minting, the condition of extending and the states of the minted copy.

The Collector, upon obtaining the token, will be able to use the token within the boundaries set by the creator.

## Motivation
This standard solves the following problems

- Copy Issuance of Unique Arkwork/Content: Professional Artists create arkworks that is unique. There could be multiple collectors who wants to keep a copy of their artworks. This standard serves as a tool to issue multiple copies of the same kind. The copies can be created with different function and under different conditions. It gives sufficient flexibilty to both the creator and the collector.
- Partial Copyright Transfer: This standard enables creators to conditionally delegate the copyright, i.e. the right to produce derivative work, to the holders of the copy token. There is no need to sell the master copy, i.e. creator token, to the market. The creator can instead keep the token as a proof of authorship.

People with the following usecases can consider applying this standard:
- Creator of any unique Art/Music NFTs can use this standard to sell copies to audiences. With this standard, they can retain some control over the copies.
- Artists can use ERC721Copy to sell time-limited copies of their artwork to other artists with a copyright statement that enables the production of derivative work
- Universities can create Graduation Certificates as NFTs and use this standard to mint a batch of non-transferable issues to their students. The Univerity retains the right to revoke any issued certificates.


## Specification
The key words “MUST”, “MUST NOT”, “REQUIRED”, “SHALL”, “SHALL NOT”, “SHOULD”, “SHOULD NOT”, “RECOMMENDED”, “MAY”, and “OPTIONAL” in this document are to be interpreted as described in RFC 2119.

This standard consists of a Copy Contract and a Mintable Contract. They together enable copy creation from the Creator Contract.

### Deployment

- The Creator Contract MUST be [EIP-721](./eip-721.md) Compliant.
- The Creator Contract MUST immplement the **metadata extension** specified in [EIP-721](./eip-721.md).
- The Creator Token Holder MUST be process the copyright of the content that permits the issuing of the copy NFT.
- The Copy Contract MUST work with any Creator Contract.

### Usage

- The token holder of the Creator Contract MAY set the mintable rule in the Copy Contract to specify the condition of mint a particular copy.
- The mintable rule SHOULD call a particular implementation of Mintable Contract and set rules inside the Mintable Contract.
- The creator MAY specifies states of the copy, such as transferable, extendable, revokable, updateable, statement in the Contract.

- The Collector MUST fulfil the rules set by the Creator to obtain a copy.
- The Collector MAY excecise the right specfied by the Creator, such as transferable, extendable, revokable, updateable, and the copyright - in the statement.
- The Collector SHOULD always reserve the right to destroy a copy.
- The Creator MAY revoke a copy if the state revokable of the copy is true.

## Rationale

This standard is designed to be as flexible as possible so that it can filful as much need as possible. 

The Copy Contract permits minting of tokens that process the following charateristics:
- non-transferable: An SBT that is bound to a user's wallet address
- revokable: creator has control over the minted copies. This is suitable for NFT that expresses follower relationship, or some kind of revokable permit
- extendable: NFT is valid over a duration and requires extension. This is suitable for recurring membership.
- updateable: Allows the copy NFT holder to update the NFT content when the creator NFT is updated
- statement: Copyright transfer or other form of declaration from the Creator.

The Mintable Contract can be customised to enforce conditions for Collectors, including:
- Fee: Requires payment to mint
- Free: No Condition to mint
- NFT Holder: Process a particular NFT to mint
- ERC20 Holder: Process a certain amount of ERC20 tokens to mint
- Whitelist: In the whitelist to mint.
- Limited Issuance: Fixed Maximum number of issued copies.
- Limited Time: Enables minting within a particular time frame.

### Design Reference

1) [Lens Protocol Modules](https://github.com/lens-protocol/core): The Mintable Rule Design references the Lens Protocol Collect Modules in the set up of condition prior to minting.

## Backwards Compatibility
This standard is compatible with [EIP-721](./eip-721.md) and their extension.

## Test Cases
The full test case is given in  `../assets/eip-####/`.

## Reference Implementation

### The Copy Interface

```solidity
pragma solidity 0.8.10;
import './IMintable.sol';

/**
 * @notice The Interface of ERC721Copy Contract. Creator can use the setMintableRule to specify the condition for minting
 * the copy. Depending on the mintable rules, collector can copy, then update, transfer, extend or destroy the copy. Creator 
 * can revoke the copy if allowed in mintable rules. This interface is intended to be used for single creator NFT contract. 
 * It can be easily extended to accept request from multiple create NFT contracts.
 */
interface IERC721Copy {
    /**
     * @dev Struct containing the information of the minted copy NFT
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
     * @dev The creator who holds a creator token can set a mintable rule that enables others
     * to mint copies given that they fulfil the conditions specified by the rule
     *
     * @param creatorId the tokenId of the creator NFT
     * @param mintable the address of the mintable rule
     * @param mintableInitData the data to be input into the mintable address for setup rules
     */
    function setMintableRule(
        uint256 creatorId,
        address mintable,
        bytes calldata mintableInitData
    ) external;

    /**
     * @dev Mint a copy of a creator token which has a mintable rule set
     *
     * @param to address of copy token receiver
     * @param mintInfo See {IMintable-MintInfo}
     *
     * @return uint256 Returns the newly minted tokenId
     */
    function copy(
        address to, 
        IMintable.MintInfo calldata mintInfo
    ) external returns (uint256);

    /**
     * @dev The creator can revoke the ownership of the copy NFT if isRevokable returns true
     * see {IERC721Copy-isRevokable}
     *
     * @param tokenId the copy nft tokenId to be revoked by the creator
     *
     */
    function revoke(uint256 tokenId) external;

    /**
     * @dev The copy NFT owner can destroy the copy NFT anytime he/she wants. The destroy function
     * works also for expired tokens
     *
     * @param tokenId the copy nft tokenId to be revoked by the creator
     *
     */
    function destroy(uint256 tokenId) external;


    /**
     * @dev The copy NFT owner can extend the copy NFT anytime he/she wants. Extension of the token's
     * expiry timestamp should subject to the conditions specified in the mintable rule set by the
     * creator
     *
     * @param tokenId the copy nft tokenId to be revoked by the creator
     * @param duration the duration to be extended
     * @param data the additional data required to pass the isExtendable function. It will be abi.decoded
     * into the respective variables in {IMintable-isExtendable}
     *
     */
    function extend(
        uint256 tokenId,
        uint64 duration,
        bytes calldata data
    ) external returns (uint64);

    /**
     * @dev The copy NFT owner can update the copy NFT if the NFT is updatable. The update function
     * should stop functioning once the token is expired
     *
     * @param tokenId the copy nft tokenId to be revoked by the creator
     *
     */    
    function update(uint256 tokenId) external returns (string memory);

    /**
     * @return address Returns the address of the creator NFT contract
     */
    function getCreatorContract() external view returns (address);
    
    /**
     * @dev The copy NFT is transferable if its transferable parameter is true and it has not expired
     *
     * @param tokenId The copy NFT token Id
     *
     * @return bool Returns a boolean indicating whether the token is transferable
     */
    function isTransferable(uint256 tokenId) external view returns (bool);

    /**
     * @dev The copy NFT is updatable if its updatable parameter is true and it has not expired
     *
     * @param tokenId The copy NFT token Id
     *
     * @return bool Returns a boolean indicating whether the token is updatable
     */
    function isUpdatable(uint256 tokenId) external view returns (bool);

    /**
     * @dev The copy NFT is revokable if its revokable parameter is true or it has expired
     *
     * @param tokenId The copy NFT token Id
     *
     * @return bool Returns a boolean indicating whether the token is is revokable
     */
    function isRevokable(uint256 tokenId) external view returns (bool);

    /**
     * @dev The copy NFT is extendable if its extendable parameter is true
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
     * @dev This function calls the IERC721 ownerOf function. It returns the token owner regardless of whether
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
}```

### The Mintable Interface

```solidity
pragma solidity 0.8.10;

/**
 * @notice This is the interface of the Mintable Contract, the mintable contract specifies the rule for minting copies. 
 * Contracts that inherit the IMintable Interface can define their own rules. The creator will first specifies rules 
 * using the setupRule function. Then, the collector can mint a copy with the isMintable function, or subsequently extend
 * the validity of the copy with the isExtendable function.
 */
interface IMintable {
    /**
     * @dev mintInfo struct that specifies the input to the minting function
     *
     * @param creatorId The tokenId of the creator NFT that produces the original content
     * @param duration The time duration that should add to the NFT token after mint
     * @param transferable Indicates whether the token is transferable
     * @param updatable Indicates whether the token is updatable.
     * @param revokable Indicataes whether the token is recovable by the creator token holder
     * @param extendable Indicates whether the token can be extended beyond the deadline
     * @param statement The copyright declaration by the creator token holder
     * @param data Addition data that is required by the Mintable rule to pass. Should deserialize into variables specified
     * in the abi.decode function in the app
     */
    struct MintInfo {
        uint256 creatorId;
        uint64 duration;
        bool transferable;
        bool updatable;
        bool revokable;
        bool extendable;
        string statement;
        bytes data;
    }

    /**
     * @dev Sets up the mintable rule by the creator NFT's tokenId and the ruleData. This function will
     * decode the ruleData back to the required parameters and sets up the mintable rule that decides who
     * can or cannot mint a copy of the creator's NFT content, with the corresponding parameters, such as
     * transferable, updatable etc. see {IMintable-MintInfo}
     *
     * @param creatorId The token Id of the creator NFT, i.e. the token which will get its contentUri copied
     * @param ruleData The data bytes for initialising the mintableRule. Parameters are encoded into bytes
     */
    function setupRule(uint256 creatorId, bytes calldata ruleData) external;

    /**
     * @dev Supply the data that will be used to passed the mintable rule setup by the creator. Different
     * rule has different requirement
     *
     * @param to the address that the NFT will be minted to
     * @param mintInfo the mint information as indicated in {IMintable-MintInfo}
     */
    function isMintable(address to, MintInfo calldata mintInfo) external;

    /**
     * @dev Supply the the expiry date of the NFT and data that will be used to passed the mintable rule setup
     * by the creator. Different rule has different requirement. Once pass the NFT expiry will be extended by the
     * specific duration
     *
     * @param to the token holder of the copy NFT
     * @param expiry the expiry timestamp of the token
     * @param mintInfo the mint information as indicated in {IMintable-MintInfo}
     */
    function isExtendable(
        address to,
        uint64 expiry,
        MintInfo memory mintInfo
    ) external;
}
```

The full implementation of the standard is given in the folder `../assets/eip-####/`.

## Security Considerations
The expiry timestamp computation depends o the block timestamp which may not acurrately reflect the real world time. Please refrain from setting a overly low duration for the NFT.

## Copyright
Copyright and related rights waived via [MIT](./LICENSE.md).


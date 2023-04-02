---
eip: <to be assigned>
title: ERC721Copy
description: NFT Copy Creation under conditions specified by the creator
author: Henry Yeung (@henrywfyeung), Xiao Ba <99x.capital@gmail.com>
discussions-to: <URL>
status: Draft
type: Standards Track
category (*only required for Standards Track): ERC
created: 2023-04-01
requires (*optional): 165, 721
---

## Abstract
This standard is an extension of [EIP-721](./eip-721.md). This standard enables a creator token, i.e. token from any EIP-721 compliant contracts with metadata extension, to work as an original copy that conditionally allows the production of replicas with specific copyright delegation valid within a fixed duration.

The Creator, who holds the original copy, can set up Mintable rules specifying the condition of minting, the condition of extending, and the states of the minted copy.

The Collector, upon obtaining the token, will be able to use the token within the boundaries set by the creator.

![alt text](./assets/Diagram.png?raw=true)

## Motivation
This standard solves the following problems.

- Copy Issuance of Unique Artwork/Content: Artists create unique artworks. There could be multiple collectors who want to keep a copy of their artworks. This standard serves as a tool to issue multiple copies of the same kind. The copies can be created with different functions and under different conditions. It gives sufficient flexibility to both the Creator and the Collector.
- Partial Copyright Transfer: This standard enables Creators to conditionally delegate the copyright, i.e. the right to produce derivative work, to the Collectors. There is no need to sell the original copy, i.e. creator token, in the market. The Creator can instead keep the token as proof of authorship, and the key to manage copy issurance.

This standard will serve a wide range of usecases, coupled with the followings:

- Decentralized storage facilities, such as Arweave, that enables permissionless, permanent and tamper-proof storage of content. The purchase of any copy NFT guarantees the owner the right to access such content.
- Decentralized Encrption Protocol, such as Lit Protocol, that enables the encryption of content specified by on-chain conditions. This enables selective reveal of content based on Copy NFT ownership and its expiry date.

People with the following use cases can consider applying this standard:
- Creator of any unique Art/Music NFTs can use this standard to sell copies to audiences. With this standard, they can retain some control over the copies.
- Artists can use this standard to sell time-limited copies of their artwork to other artists with a copyright statement that enables the production of derivative work
- Universities can create Graduation Certificates as NFTs and use this standard to mint a batch of non-transferable issues to their students. The Univerity retains the right to revoke any issued certificates.
- Novel writers can publish their content with the first chapter publicly viewable, and the following chapters encrypted with Lit Protocol. The readers will be required to purchase a Copy NFT to decrypt the encrypted chapters


## Specification
The key words “MUST”, “MUST NOT”, “REQUIRED”, “SHALL”, “SHALL NOT”, “SHOULD”, “SHOULD NOT”, “RECOMMENDED”, “MAY”, and “OPTIONAL” in this document are to be interpreted as described in RFC 2119.

This standard consists of a Copy Contract and a Mintable Contract. They together enable copy creation from the Creator Contract.

### Deployment

- The Creator Contract MUST be [EIP-721](./eip-721.md) Compliant.
- The Creator Contract MUST implement the **metadata extension** specified in [EIP-721](./eip-721.md).
- The Creator Token Holder MUST process the copyright of the content that permits the issuing of the copy NFT.

### Usage

- The token holder of the Creator Contract MAY set the mintable rule in the Copy Contract to specify the condition of minting a particular copy.
- The mintable rule SHOULD call a particular implementation of Mintable Contract and set rules inside the Mintable Contract.
- The creator MAY specifies states of the copy, such as transferable, extendable, revokable, updateable, the copyright statement in the Contract.

- The Collector MUST fulfill the rules set by the Creator to obtain a copy.
- The Collector MAY exercise the rights specified by the Creator, such as transferable, extendable, revokable, updateable, and the copyright statement.
- The Collector SHOULD always reserve the right to destroy a copy.
- The Creator MAY revoke a copy if the state revokable of the copy is true.

## Rationale

This standard is designed to be as flexible as possible so that it can fulfill as much needs as possible. 

The Copy Contract permits the minting of tokens that process the following charateristics:
- non-transferable: An SBT that is bound to a user's wallet address
- revokable: creator has control over the minted copies. This is suitable for NFT that expresses follower relationship, or some kind of revokable permit
- extendable: NFT is valid over a duration and requires extension. This is suitable for recurring memberships.
- updateable: Allows the copy NFT holder to update the NFT content when the creator NFT is updated
- statement: Copyright transfer or other forms of declaration from the Creator.

The Mintable Contract can be customized to enforce conditions for Collectors, including:
- Fee: Requires payment to mint
- Free: No Condition to mint
- NFT Holder: Process a particular NFT to mint
- ERC20 Holder: Process a certain amount of ERC20 tokens to mint
- Whitelist: In the whitelist to mint.
- Limited Issuance: Fixed Maximum number of issued copies.
- Limited Time: Enables minting within a particular time frame.

## Backwards Compatibility
This standard is compatible with [EIP-721](./eip-721.md) and their extension.

## Test Cases
The full test case is given in  `../assets/eip-####/`.

## Reference Implementation

### The Copy Interface

```solidity
pragma solidity 0.8.10;

/**
 * @notice The Interface of ERC721Copy Contract. Creator can use the setMintableRule to specify the condition for minting
 * the copy. Depending on the mintable rules, collector can copy, then update, transfer, extend or destroy the copy. Creator 
 * can revoke the copy if allowed in mintable rules. This interface is intended to be used for single creator NFT contract. 
 * It can be easily extended to accept request from multiple create NFT contracts.
 * 
 * The MintInfo encapulates the information of the copy NFT, including all the permissions granted to it. This information can be 
 * stored on chain as a MintInfo struct, or simple a hashed version of it to save gas. It comes with a fixed set of basic info, such 
 * as isTransferable, isExtendable, etc, and a bytes field for defining custom additional permissions.
 * 
 * MintableRules are external contract that is responsible for the defintion and enforcement of rules, that should be fulfilled before 
 * minting a copy NFT
 * 
 * Creator chooses the MintableRules that associate with the corresponding MintInfos.
 * Copier fulfils the MintableRule to obtain a copy and enjoy the benefits brought by the MintInfo.
 */
interface IERC721Copy {

    /**
     * @dev Emitted when a mintable rule is created
     * 
     * @param copyHash The hash of the copy configuration
     * @param mintInfo The mintable rule that the copyHash is generated from
     */
    event SetMintableRule(bytes32 copyHash, MintInfo mintInfo);
    
    /**
     * @dev Emitted when a mintable rule is paused
     * 
     * @param copyHash The hash of the copy configuration
     */
    event PauseMintableRule(bytes32 copyHash);

    /**
     * @dev Emitted when a copy is created
     * 
     * @param tokenId The tokenId of the copy NFT
     * @param copyHash The hash of the copy configuration
     * @param expiry The expiration timestamp of the copy NFT
     */
    event Create(uint256 tokenId, bytes32 copyHash, uint64 expiry);

    /**
     * @dev Emitted when a copy is extended
     * 
     * @param tokenId The tokenId of the copy NFT
     * @param expiry The renewed expiration timestamp of the copy NFT
     */
    event Extend(uint256 tokenId, uint64 expiry);

    /**
     * @dev Emitted when a copy is updated
     * 
     * @param tokenId The tokenId of the copy NFT
     * @param tokenUri The tokenUri of the copy NFT. This tokenUri should point to the resources that the copy NFT owner will get.
     */
    event Update(uint256 tokenId, string tokenUri);

    /**
     * @dev Emitted when a copy is revoked. A revoked copy is burnt and will never be recovered
     * 
     * @param tokenId The tokenId of the copy NFT
     */
    event Revoke(uint256 tokenId);

    /**
     * @dev Emitted when a copy is destroyed. A destroyed copy is burnt and will never be recovered
     * 
     * @param tokenId The tokenId of the copy NFT
     */
    event Destroy(uint256 tokenId);

    /**
     * @dev The Permission Granted to the owner of the CopyNFT. The Value in this enum is only suggested values. Please substitute them for 
     *    your own use case.
     * 
     * @param COLLECT Only allows for holding the copy NFT. This is suitable for the case which the NFT is an artwork collection.
     * @param USE Allows for holding and using the copy NFT. This is suitable for the case which, for instance, the copy NFT is a ticket to an event, or a key to unlock private content
     * @param MODIFY Allows for holding, and modifying the copy NFT. This is suitable for the case which the Creator wants to grant permission to Copy NFT holders who wants to create derivative work based on the content
     * @param DISTRIBUTE Allows for holding, and distributing the copy NFT. This is suitable for the case which the Creator wants to grant Copy NFT holders unresticted distribute of the content
     */
    enum Statement {
        COLLECT,
        USE,
        MODIFY,
        DISTRIBUTE
    }

    /**
    * @dev States of the mintable rule
    *
    * @param NIL Rule not exists
    * @param EXIST Rule exists for minting and extending
    * @param PAUSED Rule paused for minting but available for extending
    */
    enum State {
        NIL,
        EXIST,
        PAUSED
    }

    /**
     * @dev mintInfo struct that specifies the input to the minting function
     *
     * @param creatorId The tokenId of the creator NFT that produces the original content
     * @param statement The copyright declaration by the creator token holder
     * @param transferable Indicates whether the token is transferable
     * @param updatable Indicates whether the token is updatable.
     *  User can update the contentUri of the copy token (copyUri) to the latest contentUri state of the creator token
     * @param revokable Indicates whether the token is recovable by the creator token holder
     * @param extendable Indicates whether the token can be extended beyond the deadline
     * in the abi.decode function in the app
     * @param mintInfoAdditional Additional data for the mintable rule
     */
    struct MintInfo {
        address mintable;
        Statement statement;
        bool transferable;
        bool updatable;
        bool revokable;
        bool extendable;
        uint256 creatorId;
        bytes mintInfoAdditional;
    }

    /**
     * @dev The creator who holds a creator token can set a mintable rule that enables others
     * to mint copies given that they fulfil the conditions specified by the rule
     *
     * @param mintInfo the basic states of the copy to be minted
     * @param mintableInitData the data to be input into the mintable address for setup rules
     * 
     * @return bytes32 Returns the hash of the copy conifiguration 
     */
    function setMintableRule(
        MintInfo memory mintInfo,
        bytes calldata mintableInitData
    ) external returns (bytes32);

    /**
     * @dev The creator can pause the mintable rule
     *
     * @param copyHash the hash of the copy configuration for minting
     */ 
    function pauseMintableRule(
        bytes32 copyHash
    ) external;

    /**
     * @param copyId The copy NFT tokenId
     *
     * @return address Returns of the mintable rule provided by the creator NFT token owner
     */
    function getMintableRule(uint256 copyId) external view returns (address);

    /**
     * @dev Mint a copy of a creator token which has a mintable rule set
     *
     * @param to address of copy token receiver
     * @param copyHash the hash of the copy configuration for minting
     * @param duration the duration of the copy
     *
     * @return uint256 Returns the newly minted tokenId
     */
    function create(
        address to, 
        bytes32 copyHash,
        uint64 duration
    ) external payable returns (uint256);

    /**
     * @dev The copy NFT owner can extend the copy NFT anytime he/she wants. Extension of the token's
     * expiry timestamp should subject to the conditions specified in the mintable rule set by the
     * creator
     *
     * @param tokenId the copy nft tokenId to be revoked by the creator
     * @param duration the duration to be extended
     *
     */
    function extend(
        uint256 tokenId,
        uint64 duration
    ) external payable returns (uint64);

    /**
     * @dev The copy NFT owner can update the copy NFT if the NFT is updatable. The update function
     * should stop functioning once the token is expired
     *
     * @param tokenId the copy nft tokenId to be revoked by the creator
     *
     */    
    function update(uint256 tokenId) external returns (string memory);

    /**
     * @dev The creator can revoke the ownership of the copy NFT if isRevokable returns true
     * see {ICopy-isRevokable}
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
     * @param tokenId The copy NFT tokenId
     *
     * @return uint256 Returns the creator NFT tokenId that the copy NFT is based on
     */
    function creatorOf(uint256 tokenId) external view returns (uint256);

    /**
     * @param tokenId The copy NFT tokenId
     *
     * @return string Returns the expiration timestamp of the token
     */
    function expireAt(uint256 tokenId) external view returns (uint64);
}
```

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
     * @dev Sets up the mintable rule by the creator NFT's tokenId and the ruleData. This function will
     * decode the ruleData back to the required parameters and sets up the mintable rule that decides who
     * can or cannot mint a copy of the creator's NFT content, with the corresponding parameters, such as
     * transferable, updatable etc. see {IMintable-MintInfo}
     *
     * @param copyHash The hash of the copy configuration
     * @param ruleData The data bytes for initialising the mintableRule. Parameters are encoded into bytes
     */
    function setupRule(bytes32 copyHash, bytes calldata ruleData) external;

    /**
     * @dev Supply the data that will be used to passed the mintable rule setup by the creator. Different
     * rule has different requirement
     *
     * @param to the address that the NFT will be minted to
     * @param copyHash the hash of the copy configuration
     * @param duration the duration that the NFT validity can be extended
     */
    function isMintable(address to, bytes32 copyHash, uint64 duration) external payable;

    /**
     * @dev Supply the the expiry date of the NFT and data that will be used to passed the mintable rule setup
     * by the creator. Different rule has different requirement. Once pass the NFT expiry will be extended by the
     * specific duration
     *
     * @param to the token holder of the copy NFT
     * @param copyHash the hash of the copy configuration
     * @param duration the duration that the NFT validity can be extended
     */
    function isExtendable(address to, bytes32 copyHash, uint64 duration) external payable;

    /**
     * @dev Returns the mintable rule of the creator NFT's tokenId
     *
     * @param copyHash The hash of the copy configuration
     * @return count The total number of copies minted by this rule
     */
    function getMintCount(bytes32 copyHash) external view returns (uint256);
}
```

The full implementation of the standard is given in the folder `../assets/eip-####/`.

## Security Considerations
The expiry timestamp computation depends on the block timestamp which may not accurately reflect the real-world time. Please refrain from setting an overly low duration for the NFT.

## Copyright
Copyright and related rights waived via [MIT](./LICENSE.md).

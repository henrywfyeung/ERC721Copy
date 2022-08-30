// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import './ERC721Copy/IMintable.sol';
import './ERC721Copy/IERC721Copy.sol';

interface IERC721 {
    function ownerOf(uint256 tokenId) external view returns (address owner);
}

interface IERC20 {
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external;
}

/**
 * @dev the fee to be paid before minting / extending a copy token
 * 
 * @param tokenContract The contract address of the fee token, i.e. USDT token contract address
 * @param mintAmount The token amount that is required for minting a copy token
 * @param extendAmount The token amount that is required for extending a copy token
 */
struct FeeInfo {
    address tokenContract;
    uint256 mintAmount;
    uint256 extendAmount;
}

/**
 * @dev parameters of the to be minted/extended copy token
 * see {IMintable}
 */
struct MintData {
    bool transferable;
    bool updatable;
    bool revokable;
    bool extendable;
    uint64 duration;
    string statement;
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
 * @notice This contract is an implementation of the IMintable interface. It is used to enable mintable 
 * and extending a token with a fee charged. The creator will need to setup rules for copier/collector 
 * to follow before a copy token is minted / extended. 
 * 
 */
contract FeeMintable is IMintable {

    event SetupRule(
        address copyContract,
        uint256 creatorId,
        MintData[] mintData,
        FeeInfo[] feeInfo
    );
    
    /**
     * @notice address => creatorId => RuleData[]
     * The address is the copy contract address, which is also the msg.sender to this contracts
     * The creatorId, is the tokenId of the creator contract
     */
    mapping(address => mapping(uint256 => bytes32[])) private _copyRules;
    mapping(bytes32 => State) private _states;

    /**
     * @dev The function for creator to setup a mintable rule. If this function is run more than once,
     * rules setup in the previous run will be set to PAUSED state, and the rules in the latest run will
     * be set to EXIST state.
     *
     * @param creatorId The creator token Id
     * @param ruleData The data for setting up the mintable rule. Here, it is composed of the serialized
     * struct arrays MintData[] and FeeInfo[], MintData specifies the type of Copy token, whereas FeeInfo
     * specifies the required fee for minting / extending a type of token.
     */
    function setupRule(uint256 creatorId, bytes calldata ruleData) external override {
        (MintData[] memory mintData, FeeInfo[] memory feeInfo) = abi.decode(
            ruleData,
            (MintData[], FeeInfo[])
        );

        // pause existing rules
        for (uint256 i = 0; i < _copyRules[msg.sender][creatorId].length; i++) {
            _states[_copyRules[msg.sender][creatorId][i]] = State.PAUSED;
        }
        delete _copyRules[msg.sender][creatorId];

        // setup new rules
        for (uint256 i = 0; i < mintData.length; i++) {
            bytes32 copyHash = _getHash(creatorId, mintData[i], feeInfo[i]);
            _copyRules[msg.sender][creatorId].push(copyHash);
            _states[copyHash] = State.EXIST;
        }

        emit SetupRule(msg.sender, creatorId, mintData, feeInfo);
    }

    /**
     * @dev Function for collecting fee before minting. The minter will need to supply information that
     * exactly match the rule specified by the creator. Only rules in EXIST state will be processed.
     *
     * @param to The address of the copy token receiver
     * @param mintInfo The rule information for minting
     */
    function isMintable(address to, MintInfo calldata mintInfo) external override {
        FeeInfo memory feeInfo = abi.decode(mintInfo.data, (FeeInfo));

        MintData memory mintData = MintData(
            mintInfo.transferable,
            mintInfo.updatable,
            mintInfo.revokable,
            mintInfo.extendable,
            mintInfo.duration,
            mintInfo.statement
        );

        bytes32 copyHash = _getHash(mintInfo.creatorId, mintData, feeInfo);
        // check if the condition supplied by the minter matches that specified by the creator
        require(_states[copyHash] == State.EXIST, 'FeeMintable: Invalid Parameters');

        // collect fee
        IERC20(feeInfo.tokenContract).transferFrom(
            to,
            IERC721(IERC721Copy(msg.sender).getCreatorContract()).ownerOf(mintInfo.creatorId),
            feeInfo.mintAmount
        );
    }

    /**
     * @dev Function for collecting fee before extending. The extender will need to supply information 
     * that exactly match the rule specified by the creator. Only rules in PAUSED or EXIST state will be 
     * processed.
     *
     * @param to The address of the copy token receiver
     * @param mintInfo The rule information for minting
     */
    function isExtendable(
        address to,
        uint64 expiry, // expiry is unused here, it could be used to reject extension on expired tokens
        MintInfo memory mintInfo
    ) external override {
        FeeInfo memory feeInfo = abi.decode(mintInfo.data, (FeeInfo));

        MintData memory mintData = MintData(
            mintInfo.transferable,
            mintInfo.updatable,
            mintInfo.revokable,
            mintInfo.extendable,
            mintInfo.duration,
            mintInfo.statement
        );

        bytes32 copyHash = _getHash(mintInfo.creatorId, mintData, feeInfo);
        // check if the condition supplied by the minter matches that specified by the creator
        require(_states[copyHash] == State.EXIST || _states[copyHash] == State.PAUSED, 'FeeMintable: Invalid Parameters');

        // collect fee
        IERC20(feeInfo.tokenContract).transferFrom(
            to,
            IERC721(IERC721Copy(msg.sender).getCreatorContract()).ownerOf(mintInfo.creatorId),
            feeInfo.extendAmount
        );
    }

    function _getHash(
        uint256 creatorId,
        MintData memory mintData,
        FeeInfo memory feeInfo
    ) internal view returns (bytes32) {
        // include msg sender to distinguish different contracts
        return
            keccak256(
                abi.encode(
                    msg.sender,
                    creatorId,
                    mintData.transferable,
                    mintData.revokable,
                    bytes(mintData.statement),
                    mintData.duration,
                    mintData.extendable,
                    mintData.updatable,
                    feeInfo.tokenContract,
                    feeInfo.mintAmount,
                    feeInfo.extendAmount
                )
            );
    }
}

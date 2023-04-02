import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { ethers } from 'hardhat';
import { expect } from 'chai';
import { CONTENT, ZERO_ADDRESS } from '../utils/constants';

import {
    getNow,
    getMintData,
    getCopyValidationData,
    getEncodedValidationData,
    Statement,
    PermSig,
    getPermSig
} from '../utils';

import {
    MockFT,
    MockFT__factory,
} from "../typechain-types";
import { deploy } from '../scripts/deploy';
import { IContracts } from '../scripts/deploy.type';
import { withSnapshot } from '../utils/helper';

withSnapshot('MINTABLE Contract', () => {
  
    let owner: SignerWithAddress;
    let addr1: SignerWithAddress;
    let addr2: SignerWithAddress;
    let addr3: SignerWithAddress;
    let addrs: SignerWithAddress[];

    let contracts: IContracts;
    let mockFT: MockFT;

    let mintInfo: any;
    let permSig: PermSig;

    before(async function () {
        [owner, addr1, addr2, addr3, ...addrs] = await ethers.getSigners();

        contracts = await deploy();

        // mint rule
        mintInfo = {
            mintable: contracts.mintable.address,
            creatorId: 0, // dummy 
            statement: Statement.DISTRIBUTE,
            transferable: true,
            updatable: true,
            revokable: true,
            extendable: true
        };

        // set Permission
        permSig = await getPermSig(addr1, CONTENT.contentUri, CONTENT.copyright, 1000000);

        // deploy mock ERC20 contract
        mockFT = await new MockFT__factory(owner).deploy("MOCK_USDT", "MUSDT");
    });

    describe('function tests', async () => {

        it('Creator should be able to set up a Mintable Rule with ERC20 Tokens', async ()=> {
            
            let valInfo = getCopyValidationData({
                feeToken: mockFT.address,            
                duration: 60 * 60 * 24 * 30,
                fragmented: true,
                mintAmount: 10000000000,
                extendAmount: 10000000000,
                requiredERC721Token: ZERO_ADDRESS,
                limit: 3,
                start: getNow(),
                time: 99999999999999
            });
            
            // mint and set rules
            await contracts.helper.connect(addr1).createWithMintables(
                addr1.address,
                CONTENT.contentUri,
                permSig,
                [mintInfo],
                [getEncodedValidationData(valInfo)] // data
            )
            
            // copier go get some mockFT
            await mockFT.connect(addr2).mint(addr2.address, 20000000000);
            
            // set allowance
            await mockFT.connect(addr2).approve(contracts.mintable.address, 10000000000);
            
            // get the copyHash
            let copyHash = (await contracts.copy.getCopyHashes(1))[0];
            
            // get a copy
            await contracts.copy.connect(addr2).create(
                addr2.address,
                copyHash,
                60 * 60 * 24 * 30
                )
        })

        it('Creator should be able to set up a Mintable Rule with native Tokens', async ()=> {
            
            let value = ethers.utils.parseEther("0.0001");

            let valInfo = getCopyValidationData({
                feeToken: ZERO_ADDRESS,
                duration: 60 * 60 * 24 * 30,
                fragmented: true,
                mintAmount: value,
                extendAmount: value,
                requiredERC721Token: ZERO_ADDRESS,
                limit: 3,
                start: getNow(),
                time: 99999999999999
            });

            // mint and set rules
            await contracts.helper.connect(addr1).createWithMintables(
                addr1.address,
                CONTENT.contentUri,
                permSig,
                [mintInfo],
                [getEncodedValidationData(valInfo)] // data
            )
            
            // get the copyHash
            let copyHash = (await contracts.copy.getCopyHashes(1))[0];

            // get a copy
            await contracts.copy.connect(addr2).create(
                addr2.address,
                copyHash,
                60 * 60 * 24 * 30,
                {value: value}
            );

            // extend by 1 day
            let extendValue = value.div(30);
            await contracts.copy.connect(addr2).extend(
                1,
                60 * 60 * 24,
                {value: extendValue}
            );
        })
    })
})
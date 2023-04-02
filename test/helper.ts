import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { ethers } from 'hardhat';
import { expect } from 'chai';
import { CONTENT, ZERO_ADDRESS } from '../utils/constants';
import { withSnapshot } from '../utils/helper';

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

withSnapshot('HELPER Contract', () => {
  
    let owner: SignerWithAddress;
    let addr1: SignerWithAddress;
    let addr2: SignerWithAddress;
    let addr3: SignerWithAddress;
    let addrs: SignerWithAddress[];

    let contracts: IContracts;
    let mockFT: MockFT;

    before(async function () {
        [owner, addr1, addr2, addr3, ...addrs] = await ethers.getSigners();

        contracts = await deploy();
        
        // deploy mock ERC20 contract
        mockFT = await new MockFT__factory(owner).deploy("MOCK_USDT", "MUSDT");
    });

    describe('end-to-end tests', async () => {

        it('Creator should be able to set up a Mintable Rule with Help[er', async ()=> {
            
            // set Permission
            let permSig: PermSig = await getPermSig(addr1, CONTENT.contentUri, CONTENT.copyright, 1000000);
                
            // mint rule
            let mintInfo = {
                mintable: contracts.mintable.address,
                creatorId: 0, // dummy 
                statement: Statement.DISTRIBUTE,
                transferable: true,
                updatable: true,
                revokable: true,
                extendable: true,
                mintInfoAdditional: "",
            };
        
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

            // original balance
            let walletBalance = await mockFT.balanceOf(addr2.address);

            // copier go get some mockFT
            await mockFT.connect(addr2).mint(addr2.address, 20000000000);

            // check balance
            expect((await mockFT.balanceOf(addr2.address)).toNumber()).to.eq(walletBalance.add(20000000000));
            
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
            
            // get copy Id
            let copyBalance = (await contracts.copy.balanceOf(addr2.address)).toNumber();
            expect(copyBalance).to.gt(0);
            let copyId = (await contracts.copy.tokenByIndex(copyBalance-1)).toNumber();

            // check balance after transaction
            expect((await mockFT.balanceOf(addr2.address)).toNumber()).to.eq(walletBalance.add(10000000000));
            
            // check copy NFT data
            expect(await contracts.copy.tokenURI(copyId)).to.eq(CONTENT.contentUri);
        })
 
    })
})
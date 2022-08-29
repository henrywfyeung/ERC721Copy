import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { ethers } from 'hardhat';
import { expect } from 'chai';

import {
    getMintData,
    getCopyFeeData,
    getEncodedData,
    getEncodedFeeInfo
} from './utils';

import {
    FeeMintable,
    FeeMintable__factory,
    Copy,
    Copy__factory,
    Creator,
    Creator__factory,
    MockFT,
    MockFT__factory
} from "../typechain-types";




describe('COPY Contract', () => {
  
    let owner: SignerWithAddress;
    let addr1: SignerWithAddress;
    let addr2: SignerWithAddress;
    let addr3: SignerWithAddress;
    let addrs: SignerWithAddress[];

    let mintableContract: FeeMintable;
    let creatorContract: Creator;
    let copyContract: Copy;
    let mockFT: MockFT;

    before(async function () {
        [owner, addr1, addr2, addr3, ...addrs] = await ethers.getSigners();

        // deploy mintable rule
        mintableContract = await new FeeMintable__factory(owner).deploy();

        // deploy creator contract
        creatorContract = await new Creator__factory(owner).deploy("Creator", "CTR");

        // deploy copy contract
        copyContract = await new Copy__factory(owner).deploy("Copy", "CPY", creatorContract.address);

        // deploy mock ERC20 contract
        mockFT = await new MockFT__factory(owner).deploy("MOCK_USDT", "MUSDT");
    });

    describe('contract functions', async () => {

        it('Creator should be able to set up a FeeMintable Rule', async ()=> {

            // mint a token
            await creatorContract.connect(addr1).mintToken("CID_TO_SOME_IMAGES");

            // mint rule
            let data = getMintData({
                transferable: true,
                updatable: true,
                revokable: true,
                extendable: true,
                duration: 60 * 60 * 24 * 30,
                statement: "PERMIT DISTRIBUTION",
              });
        
            let fee = getCopyFeeData({
                contract: mockFT.address,
                mintAmount: 10000000000,
                extendAmount: 10000000000,
            });

            
            // set mintable rule
            await copyContract.connect(addr1).setMintableRule(
                1, // CreatorId
                mintableContract.address, // mintable rule
                getEncodedData([data], [fee]) // data
            );

            // copier go get some mockFT
            await mockFT.connect(addr2).mint(addr2.address, 20000000000);

            // check balance
            expect((await mockFT.balanceOf(addr2.address)).toNumber()).to.eq(20000000000);

            // set allowance
            await mockFT.connect(addr2).approve(mintableContract.address, 10000000000);
            
            // get a copy
            await copyContract.connect(addr2).create(
                addr2.address, 
                {
                    creatorId: 1, // creatorId
                    duration: 60 * 60 * 24 * 30,
                    transferable: true,
                    updatable: true,
                    revokable: true,
                    extendable: true,
                    statement: "PERMIT DISTRIBUTION",
                    data: getEncodedFeeInfo(fee),
                })
            
            // check balance after transaction
            expect((await mockFT.balanceOf(addr2.address)).toNumber()).to.eq(10000000000);

            // check procession of copy Token
            expect((await copyContract.balanceOf(addr2.address)).toNumber()).to.eq(1);
            
            // check copy NFT data
            expect(await copyContract.tokenURI(1)).to.eq("CID_TO_SOME_IMAGES");
        })
        
    })



})
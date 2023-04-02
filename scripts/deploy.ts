import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { ethers } from "hardhat";
import hre from 'hardhat'
import fs from 'fs';
import {
  Mintable__factory,
  Copy__factory,
  Creator__factory,
  Helper__factory,
  MockFT__factory,
  MockNFT__factory
} from "../typechain-types";

import { DEPLOY_CACHE } from '../utils/constants';
import { IContracts } from './deploy.type';

let owner: SignerWithAddress;
let addrs: SignerWithAddress[];

export async function deploy(isMain=false): Promise<IContracts> {

  [owner, ...addrs] = await ethers.getSigners();

  // deploy creator contract
  let creatorContract = await new Creator__factory(owner).deploy("Creator", "CTR");

  // deploy copy contract
  let copyContract = await new Copy__factory(owner).deploy("Copy", "CPY", creatorContract.address);

  // deploy mintable rule
  let mintableContract = await new Mintable__factory(owner).deploy(copyContract.address);

  // whitelist mintable contract
  let whiteListTx = await copyContract.connect(owner).whiteListMintableContract(mintableContract.address);
  await whiteListTx.wait();

  // helper contract
  let helperContract = await new Helper__factory(owner).deploy(creatorContract.address, copyContract.address, mintableContract.address);

  // deploy test contracts
  let mockFT = await new MockFT__factory(owner).deploy("MOCK_USDT", "MUSDT");
  let mockNFT = await new MockNFT__factory(owner).deploy("MOCK_NFT_PASS", "MPASS");

  let contracts = {
    creator: creatorContract,
    copy: copyContract,
    mintable: mintableContract,
    helper: helperContract,
    test: {
      mockFT: mockFT,
      mockNFT: mockNFT
    }
  }

  let contractAddresses = {
    creator: creatorContract.address,
    copy: copyContract.address,
    mintable: mintableContract.address,
    helper: helperContract.address,
    test: {
      mockFT: mockFT.address,
      mockNFT: mockNFT.address
    }
  }

  // saving the contract addresses
  let deployedContracts: Record<string, any> = {};
  if (fs.existsSync(DEPLOY_CACHE)) {
    deployedContracts = JSON.parse(fs.readFileSync(DEPLOY_CACHE).toString());
    deployedContracts[hre.network.name] = contractAddresses;
  } else {
    deployedContracts = {
      [hre.network.name]: contractAddresses
    }
  }
  fs.writeFileSync(DEPLOY_CACHE, JSON.stringify(deployedContracts));
  if (isMain) console.log(deployedContracts);

  return contracts; 
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
if (require.main === module){
  deploy(true).catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
}

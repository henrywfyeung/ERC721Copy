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

export async function updateHelper(isMain=false): Promise<void> {

  [owner, ...addrs] = await ethers.getSigners();

// saving the contract addresses
  let deployedContracts: Record<string, any> = {};
  if (!fs.existsSync(DEPLOY_CACHE)) return;
  
  deployedContracts = JSON.parse(fs.readFileSync(DEPLOY_CACHE).toString());
  if (isMain) console.log("Before: ", deployedContracts);

  let creatorAddress = deployedContracts[hre.network.name].creator;
  let copyrAddress = deployedContracts[hre.network.name].copy;
  let mintableAddress = deployedContracts[hre.network.name].mintable;
   
  // helper contract
  let helperContract = await new Helper__factory(owner).deploy(creatorAddress, copyrAddress, mintableAddress);

  deployedContracts[hre.network.name].helper = helperContract.address;

  fs.writeFileSync(DEPLOY_CACHE, JSON.stringify(deployedContracts));
  if (isMain) console.log("After: ", deployedContracts); 
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
if (require.main === module){
  updateHelper(true).catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
}

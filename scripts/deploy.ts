import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { ethers } from "hardhat";
import {
  FeeMintable,
  FeeMintable__factory,
  Copy,
  Copy__factory,
  Creator,
  Creator__factory
} from "../typechain-types";

let owner: SignerWithAddress;
let addrs: SignerWithAddress[];

async function main() {

  [owner, ...addrs] = await ethers.getSigners();

  // deploy mintable rule
  let mintableContract: FeeMintable = await new FeeMintable__factory(owner).deploy();

  // deploy creator contract
  let creatorContract: Creator = await new Creator__factory(owner).deploy("Creator", "CTR");

  // deploy copy contract
  let copyContract: Copy = await new Copy__factory(owner).deploy("Copy", "CPY", creatorContract.address);

  console.log("Deployed Mintable: ", mintableContract.address);
  console.log("Deployed Creator: ", creatorContract.address);
  console.log("Deployed Copy: ", copyContract.address);
  
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

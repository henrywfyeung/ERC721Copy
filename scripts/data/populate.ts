import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import hre, { ethers } from "hardhat";
import { BigNumber, BigNumberish, BytesLike, Signer, Wallet } from 'ethers';

import { attach } from '../attach';
import { generateImages } from './generateImages';
import { getCopyValidationData, getEncodedValidationData, getNow, getPermSig } from '../../utils';
import { MAX_UINT64, ZERO_ADDRESS, CONTENT } from '../../utils/constants';
import { IContracts } from '../deploy.type';
import { deploy } from '../deploy';
const { faker } = require('@faker-js/faker');;

let owner: SignerWithAddress;
let addrs: SignerWithAddress[];

let contracts: IContracts;

// please dun set too large number
const WALLET_NUMBER = 10;
const wallet_native_tokens = "0.05";
let path = `m/44'/60'/0'/0/`;
const gwei = "100";

// config
let NUMBER_OF_IMAGES = 50;
let CREATION_PER_CREATORS = 5;
let MINTABLE_PER_CREATION = 3;
let COPY_PER_COLLECTOR = 10;

const durationChoices = [60*60*24, 60*60*24*7, 60*60*24*30, 60*60*24*365, MAX_UINT64]

const feeTokenChoices: Record<string, string[]> = {
  'hardhat': [ZERO_ADDRESS],
  'ropsten': [ZERO_ADDRESS],
  'polygon': [ZERO_ADDRESS, "0xc2132D05D31c914a87C6611C10748AEb04B58e8F", "0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619"],
  'mumbai':  [ZERO_ADDRESS]
}

const requiredERC721TokenChoices: Record<string, string[]> = {
  'hardhat': [ZERO_ADDRESS],
  'ropsten': [ZERO_ADDRESS],
  'polygon': [ZERO_ADDRESS],
  'mumbai':  [ZERO_ADDRESS]
}

const mintAmountChoices = [0, 1000000, 1000000000, 1000000000000, 1000000000000000];
const startChoices = [-10000];
const mintTimeChoices = [60*60*6, 60*60*24, 60*60*24*7, MAX_UINT64];
const mintLimitChoices = [5, 10, 100, 666, 888, 999, 1000, 5000, 10000];

const initialise_wallets = async (mnemonic: string, wallet_num: number, from_wallet: Signer): Promise<Signer[]> => {

    let walletList = [];
    for ( let i = 0 ; i < wallet_num ; i ++ ) {
        // get wallet and connect to provider
        let wallet: Signer = Wallet.fromMnemonic(mnemonic, path + (i+1).toString()).connect(ethers.provider);
        // disperse matic if not sufficient
        let balance = await wallet.getBalance();
        // if (balance.lt(ethers.utils.parseEther(wallet_native_tokens))) {
        //     const tx = await from_wallet.sendTransaction({
        //         to: await wallet.getAddress(),
        //         value: ethers.utils.parseEther(wallet_native_tokens).sub(balance)
        //     });
        //     await tx.wait();
        //     console.log("Transferred ether to address" + (i+1).toString());
        // }
        console.log(await wallet.getAddress(), await wallet.getBalance());
        walletList.push(wallet);
    }
    return walletList;
}

// roughly requires: 10 creators, 10 collectors (same person => 10 wallets),  
// 5 creator NFT per creator => 50 creator NFTs
// 3 mintables per creator NFT, => 150 mintables
// 10 copy NFT per collector =>  100 copies minted

// estimated polygon gas cost (0.3 per creation with mintable * 50 => 1.5 matic)
// estimated polygon gas cost (0.2 per copy * 100 => 2 matic)
// total: around 3.5 matic

const getRandomMintable = () => {
  return {
    mintable: contracts.mintable.address,
    creatorId: 0, // dummy 
    statement: faker.datatype.number(3),
    transferable: faker.datatype.boolean(),
    updatable: faker.datatype.boolean(),
    revokable: faker.datatype.boolean(),
    extendable: faker.datatype.boolean()
  }
}

const chooseOne = <Type>(arr: Array<Type>): Type => {
  return arr[faker.datatype.number(arr.length-1)];
}

const getRandomEncodedValidationRules = () => {
  let feeTokenChoicesExtended = feeTokenChoices[hre.network.name].concat([contracts.test.mockFT.address]);
  let requiredERC721TokenChoicesExtended = requiredERC721TokenChoices[hre.network.name].concat([contracts.test.mockNFT.address]);
  let validationInfo = {
    feeToken: chooseOne(feeTokenChoicesExtended),
    duration: durationChoices[faker.datatype.number(durationChoices.length-1)],
    fragmented: faker.datatype.boolean(),
    mintAmount: chooseOne(mintAmountChoices),
    extendAmount: chooseOne(mintAmountChoices),
    requiredERC721Token: chooseOne(requiredERC721TokenChoicesExtended),
    limit: chooseOne(mintLimitChoices),
    start: getNow() + chooseOne(startChoices),
    time: chooseOne(mintTimeChoices)
  }
  return getEncodedValidationData(getCopyValidationData(validationInfo));
}

interface MintParams {
  copyHash: string;
  duration: BigNumberish;
  feeToken: string;
  mintFee: BigNumberish;
  requiredToken: string;
}

const getCreatorWithMintableList = async (creatorNumber: number): Promise<MintParams> => {

  // randomly select creator Id
  let count: number = faker.datatype.number({ min: 0, max: creatorNumber-1});
  let creatorId = await contracts.creator.tokenByIndex(count);
  // randomly select mintable hash
  let copyHashes = await contracts.copy.getCopyHashes(creatorId);
  let hash = chooseOne(copyHashes);
  let valInfo = await contracts.mintable.getValidationInfo(hash);
  let mintCount = await contracts.mintable.getMintCount(hash);
  
  if ( valInfo.limit <= mintCount) {
    throw Error("Limit Reached");
  }

  // check fragmented and compute a duration
  let multiplier = valInfo.fragmented ? faker.datatype.number({min: 1, max: 10}) : 1;
  let divider = valInfo.fragmented ? faker.datatype.number({min: multiplier, max: multiplier + 10}) : 1;

  let duration = valInfo.duration.mul(multiplier).div(divider);
  let mintFee = valInfo.mintAmount.mul(multiplier).div(divider);

  return {
    copyHash: hash,
    duration: duration,
    feeToken: valInfo.feeToken,
    mintFee: mintFee,
    requiredToken: valInfo.requiredERC721Token
  }
}

export async function populate() {

  [owner, ...addrs] = await ethers.getSigners();

  // init contracts
  contracts = hre.network.name == 'hardhat' ? await deploy() : await attach();

  let walletList = await initialise_wallets(process.env.MNEMONIC!, WALLET_NUMBER, owner);
  
  // load the images
  let arids = await generateImages(NUMBER_OF_IMAGES);

  // create fake creator NFTs generation in parallel
  if ( (await contracts.creator.totalSupply()).toNumber() < CREATION_PER_CREATORS * WALLET_NUMBER ) {
    await Promise.all(
      walletList.map(
        async (w, i) => {
          let addr = await w.getAddress();
          for ( let j = i * CREATION_PER_CREATORS ; j < (i + 1 ) * CREATION_PER_CREATORS ; j++ ) {
            const tx = await contracts.helper.connect(w).createWithMintables(
              addr,
              arids[j],
              await getPermSig(w, arids[j], CONTENT.copyright, 1000000),
              [...Array(MINTABLE_PER_CREATION).keys()].map(()=>getRandomMintable()), // get few randome mintable config
              [...Array(MINTABLE_PER_CREATION).keys()].map(()=>getRandomEncodedValidationRules())
            )
            await tx.wait();
            console.log("Wallet " + addr + " finishing transaction " + i.toString());
          }
        }
      )
    ).catch((err)=>console.log(err))
  }

  console.log("Finished Creation");
  
  // create fake copy NFTs (Helper batch collect)
  await Promise.all(
    walletList.map(
      async (w, i) => {

        let addr = await w.getAddress();
        
        let durations: BigNumberish[] = [];
        let copyHashes: BytesLike[] = [];
        let fee: Record<string, BigNumber> = {};
        feeTokenChoices[hre.network.name].concat([contracts.test.mockFT.address]).forEach(element => {
          fee[element] = BigNumber.from(0);
        });
        let nativeTokenFees: BigNumberish[] = [];
        let requiredMockNFT = false;

        // randomly select a few creators + mintable to make copies        
        await Promise.all(
          [...Array(COPY_PER_COLLECTOR).keys()].map(
            async (i) => {
              let mintParams = await getCreatorWithMintableList(NUMBER_OF_IMAGES);
              durations.push(mintParams.duration);
              copyHashes.push(mintParams.copyHash);
              fee[mintParams.feeToken] = fee[mintParams.feeToken].add(mintParams.mintFee);
              if ( mintParams.feeToken == ZERO_ADDRESS) {
                nativeTokenFees.push(mintParams.mintFee);
              } else {
                nativeTokenFees.push(0);
              }

              requiredMockNFT = requiredMockNFT || mintParams.requiredToken == contracts.test.mockNFT.address;
            }
          )
        )

        // obtain the necessary tokens to pass transaction
        const tx_transfer = await contracts.test.mockFT.connect(w).mint(await w.getAddress(), fee[contracts.test.mockFT.address]);
        await tx_transfer.wait();

        // make the necessary approval to pass transaction
        const tx_approve = await contracts.test.mockFT.connect(w).approve(contracts.mintable.address, fee[contracts.test.mockFT.address]);
        await tx_approve.wait();

        if (requiredMockNFT) {
          const tx_mint = await contracts.test.mockNFT.connect(w).mintToken(await w.getAddress());
          await tx_mint.wait();
        }

        // make transaction
        const tx = await contracts.helper.connect(w).batchCollect(
          addr,
          copyHashes,
          durations,
          nativeTokenFees,
          {value: fee[ZERO_ADDRESS]}
        );
        await tx.wait();
        
        console.log("Wallet " + addr + " finishing transaction ");

        }
    )
  )

  // validate
  let result = await contracts.helper.getCreatorTokens(0, 20);
  console.log(result.creators[0]);
  console.log(result.creators.length);
  console.log(result.meta);

  let result2 = await contracts.helper.getCreatorTokens(20, 20);
  console.log(result2.creators[0]);
  console.log(result2.creators.length);
  console.log(result2.meta);

  let result3 = await contracts.helper.getCreatorTokens(300, 20);
  console.log(result3.creators[0]);
  console.log(result3.creators.length);
  console.log(result3.meta);


  let result4 = await contracts.helper.getCreatorTokensByAddress(await walletList[0].getAddress(), 0, 10);
  console.log(result4.creators[0]);
  console.log(result4.creators.length);
  console.log(result4.meta);

  let result5 = await contracts.helper.getCopyTokensByCreator(1, 0, 10);
  console.log(result5.copies[0]);
  console.log(result5.copies.length);
  console.log(result5.meta);

  let result6 = await contracts.helper.getCopyTokensByCreator(1, 0, 100);
  console.log(result6.copies[0]);
  console.log(result6.copies.length);
  console.log(result6.meta);

  console.log("All Finished");
  
  return;
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
if (require.main === module){
  populate().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
}

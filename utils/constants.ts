import { BigNumber } from "ethers";

export const CONTENT = {
    contentUri: "sampleContentUri",
    copyright: "By signing this statement, I confirm that I am the full copyright holder of the data pointed to by the contentUri included in this signature. I willingly give up all my copyright to the holder of the newly minted NFT, in the condition that the copyright will be forever bound to, and transfer together with that newly minted NFT."
}

export const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000';
export const MAX_UINT64 = BigNumber.from('0xffffffffffffffff'); // 18446744073709551615

export const DEPLOY_CACHE = 'deployedContracts.json';
export const IMAGE_CACHE = 'generatedImages.json';

export const BUNDLR_URL = 'https://node1.bundlr.network';

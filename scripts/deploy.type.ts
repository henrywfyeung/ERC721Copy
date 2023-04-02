import {
    Mintable,
    Copy,
    Creator,
    Helper,
    MockFT,
    MockNFT
} from "../typechain-types";

export interface IContracts {
    creator: Creator,
    copy: Copy,
    mintable: Mintable,
    helper: Helper,
    test: {
        mockFT: MockFT,
        mockNFT: MockNFT
    }
}

export interface IContractAddresses {
    creator: string,
    copy: string,
    mintable: string,
    helper: string
    test: {
        mockFT: string,
        mockNFT: string
    }
}
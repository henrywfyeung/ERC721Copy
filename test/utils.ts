import { ethers } from 'hardhat';
import { BigNumberish } from 'ethers';

export type CopyMintTuple = [boolean, boolean, boolean, boolean, BigNumberish, string];
export type CopyFeeTuple = [string, BigNumberish, BigNumberish];

export interface CopyMintData {
    transferable: boolean;
    updatable: boolean;
    revokable: boolean;
    extendable: boolean;
    duration: BigNumberish;
    statement: string;
}

export interface CopyFeeData {
    contract: string;
    mintAmount: BigNumberish;
    extendAmount: BigNumberish;
}

export const getMintData = (data: CopyMintData): CopyMintTuple => {
    return [
      data.transferable,
      data.updatable,
      data.revokable,
      data.extendable,
      data.duration,
      data.statement,
    ];
  };

export const getEncodedData = (data: CopyMintTuple[], feeInfo: CopyFeeTuple[]) => {
return ethers.utils.defaultAbiCoder.encode(
    ['tuple(bool, bool, bool, bool, uint256, string)[]', 'tuple(address, uint256, uint256)[]'],
    [data, feeInfo]
    );
};

export const getCopyFeeData = (data: CopyFeeData): CopyFeeTuple => {
    return [data.contract, data.mintAmount, data.extendAmount];
};

export const getEncodedFeeInfo = (feeInfo: CopyFeeTuple) => {
    return ethers.utils.defaultAbiCoder.encode(['tuple(address, uint256, uint256)'], [feeInfo]);
  };
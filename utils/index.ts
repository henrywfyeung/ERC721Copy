import { ethers } from 'ethers';
import { BigNumberish, Signer } from 'ethers';
import { keccak256, BytesLike } from 'ethers/lib/utils';


export type CopyMintTuple = [string, BigNumberish, Statement, boolean, boolean, boolean, boolean];
export type CopyValidationTuple = [string, BigNumberish, boolean, BigNumberish, BigNumberish, string, BigNumberish, BigNumberish, BigNumberish];

export enum Statement {
  COLLECT,
  USE,
  MODIFY,
  DISTRIBUTE
};

export interface CopyMintData {
    mintable: string,
    creatorId: BigNumberish;
    statement: Statement;
    transferable: boolean;
    updatable: boolean;
    revokable: boolean;
    extendable: boolean;
}

export interface CopyValidationData {
    feeToken: string;
    duration: BigNumberish;
    fragmented: boolean;
    mintAmount: BigNumberish;
    extendAmount: BigNumberish;
    requiredERC721Token: string;
    limit: BigNumberish;
    start: BigNumberish;
    time: BigNumberish;
}

export interface PermSig {
  deadline: number;
  v: number;
  s: BytesLike;
  r: BytesLike;
}


export const getMintData = (data: CopyMintData): CopyMintTuple => {
    return [
      data.mintable,
      data.creatorId,
      data.statement,
      data.transferable,
      data.updatable,
      data.revokable,
      data.extendable,
    ];
  };

export const getEncodedValidationData = (validationInfo: CopyValidationTuple) => {
return ethers.utils.defaultAbiCoder.encode(
    ['tuple(address, uint64, bool, uint256, uint256, address, uint256, uint64, uint64)'],
    [validationInfo]
    );
};

export const getCopyValidationData = (data: CopyValidationData): CopyValidationTuple => {
    return [
      data.feeToken,
      data.duration,
      data.fragmented,
      data.mintAmount,
      data.extendAmount,
      data.requiredERC721Token,
      data.limit,
      data.start,
      data.time
    ];
};

export const getNow = (): number => {
  return Math.floor(new Date().getTime() / 1000);
}

export const getDeadline = (seconds: number) => {
  return getNow() + seconds;
};

const getPermMessage = (contentUri: string, copyrightStatement: string, deadline: number) => {
  return keccak256(
    ethers.utils.defaultAbiCoder.encode(
      ['string', 'string', 'uint256'],
      [contentUri, copyrightStatement, deadline]
    )
  );
};

const parseSignature = (signature: string) => {
  let r = "0x" + signature.slice(2, 66);
  let s = "0x" + signature.slice(66, 130);
  let v = signature.slice(130, 132) == "1b" ? 27 : 28;
  return {
    v: v,
    s: s,
    r: r
  }
}

export const getPermSig = async (signer: Signer, contentUri: string, copyrightStatement: string, offset: number): Promise<PermSig> => {
  const deadline = getDeadline(offset);
  const message = getPermMessage(contentUri, copyrightStatement, deadline);
  let signature = await signer.signMessage(Buffer.from(message.slice(2), 'hex'));
  const { v, r, s } = parseSignature(signature);
  return {
    deadline: deadline,
    v: v,
    r: r,
    s: s,
  };
};
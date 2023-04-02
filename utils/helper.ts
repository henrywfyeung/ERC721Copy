import { use } from 'chai';
import { ethers } from 'hardhat';
import { solidity } from 'ethereum-waffle';
use(solidity);

// take snapshot of the network (reference Lens Protocol) start
let snapshotId: string = '0x1';
export async function takeSnapshot() {
  snapshotId = await ethers.provider.send('evm_snapshot', []);
}

export async function revertToSnapshot() {
  await ethers.provider.send('evm_revert', [snapshotId]);
}

export function withSnapshot(name: string, tests: () => void) {
  describe(name, () => {
    beforeEach(async function () {
      await takeSnapshot();
    });
    tests();
    afterEach(async function () {
      await revertToSnapshot();
    });
  });
}
// end

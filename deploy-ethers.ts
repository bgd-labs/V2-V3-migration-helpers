import { ethers } from "ethers";
import {
  IMigrationHelper__factory,
  MigrationHelper__factory,
  MigrationHelperMainnet__factory,
} from "./typechain";

const PK = "0x4427668afd0c5fb2cfef65580997ecc9dcf3edf9a82f9ffa72b3a00f1a43165a";
const RPC_ADDRESS =
  "https://rpc.tenderly.co/fork/a7bc5061-f9f6-42e6-8cc8-2fa94014851a";

(async function exec() {
  // mainnet
  await deploy(
    MigrationHelperMainnet__factory,
    // "https://rpc.tenderly.co/fork/a7bc5061-f9f6-42e6-8cc8-2fa94014851a", // our
    "https://rpc.tenderly.co/fork/56cc267e-fefa-42f0-8400-3d89410d6da5", // aave co
    "0x2f39d218133AFaB8F2B819B1066c7E434Ad94E9e",
    "0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9",
    "0x6b175474e89094c44da98b954eedeac495271d0f"
  );
  //avalanche
  // await deploy(
  //   MigrationHelper__factory,
  //   "https://rpc.tenderly.co/fork/8ed34876-8ca4-43fb-a04c-38a083cff022",
  //   "0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb",
  //   "0x4F01AeD16D97E3aB5ab2B501154DC9bb0F1A5A2C",
  //   "0x50b7545627a5162f82a992c33b87adc75187b218"
  // );
  // //polygon
  // await deploy(
  //   MigrationHelper__factory,
  //   "https://rpc.tenderly.co/fork/9c2a6061-a5f7-4562-ae52-9c6cd8858ece",
  //   "0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb",
  //   "0x8dFf5E27EA6b7AC08EbFdf9eB090F32ee9a30fcf",
  //   "0x1bfd67037b42cf73acf2047067bd4f2c47d9bfd6"
  // );
})();

async function deploy(
  factory:
    | typeof MigrationHelperMainnet__factory
    | typeof MigrationHelper__factory,
  rpc: string,
  v3AddressesProvider: string,
  v2Pool: string,
  testAsset: string
): Promise<string> {
  const helper = new factory(
    new ethers.Wallet(PK, new ethers.providers.JsonRpcProvider(rpc))
  );
  const contract = await helper.deploy(v3AddressesProvider, v2Pool);
  const contractAddress = contract.address;
  console.log("Contract Address is", contractAddress);
  await check(rpc, contractAddress, testAsset);
  return contractAddress;
}

async function check(
  rpc: string,
  address: string,
  testAsset: string
): Promise<void> {
  const helper = IMigrationHelper__factory.connect(
    address,
    new ethers.providers.JsonRpcProvider(rpc)
  );
  console.log(await helper.POOL());
  console.log(await helper.getMigrationSupply(testAsset, 10000));
}

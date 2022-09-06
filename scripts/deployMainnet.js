// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
// const hre = require("hardhat");
const { hre, ethers, upgrades } = require("hardhat");

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled
  // await hre.run('compile');
  // We get the contract to deploy
  // const _checkPointManagerGoerli = "0x2890bA17EfE978480615e330ecB65333b880928e";
  // const _fxRootGoerli = "0x3d1d3E34f7fB6D26245E6640E1c50710eFFf15bA";
  // const _checkPointManager = "0x86e4dc95c7fbdbf52e33d563bbdb00823894c287";
  // const _fxRoot = "0xfe5e5D361b2ad62c541bAb87C45a0B9B018389a2";
  // const sky = "0x573cA38Eb1353a0e8507bE82eC6111F0AF1F1E02";
  // const SkyFarm = await hre.ethers.getContractFactory("SkyFarm");
  // const skyFarm = await SkyFarm.deploy(sky, _checkPointManager, _fxRoot);
  // await skyFarm.deployed();
  // console.log("Farm deployed to:", skyFarm.address);

  const collabInfo = await ethers.getContractFactory("CollabInfoClementines");
  const collabProxyAddress = "0x73e5a723D740F0602c7156Ab7dB3Bc9bfa54e570";
  const collab = await upgrades.upgradeProxy(collabProxyAddress, collabInfo, {
    call: {
      fn: "setClementines",
      args: [
        [
          "2578",
          "4655",
          "1194",
          "4968",
          "2190",
          "75",
          "746",
          "1566",
          "792",
          "1793",
          "4748",
          "1157",
          "767",
          "180",
          "657",
          "301",
          "2783",
          "4937",
          "2407",
          "1612",
          "2047",
          "4561",
          "3206",
          "1682",
          "2941",
          "3073",
          "2283",
          "2724",
          "3017",
          "1226",
          "703",
          "286",
          "2905",
          "2842",
          "3525",
          "709",
          "1030",
          "460",
          "2147",
          "97",
          "596",
          "831",
          "1574",
          "970",
          "4003",
          "4258",
          "947",
          "2081",
          "829",
          "2218",
          "2103",
          "2916",
          "1683",
          "3406",
          "4763",
          "1575",
          "67",
          "1479",
          "2449",
          "4989",
          "2344",
          "2002",
          "4827",
          "845",
          "981",
        ],
        true,
      ],
    },
  });
  // const proxy = await collab.deployed();
  // console.log("proxy>>>", proxy.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
// const { UpgradesError } = require("@openzeppelin/upgrades-core");
const { ethers } = require("hardhat");

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled
  // await hre.run('compile');
  // We get the contract to deploy
  // const _fxChildMumbai = "0xCf73231F28B7331BBe3124B907840A94851f9f11";
  // const _fxChild = "0x8397259c983751DAf40400790063935a11afa28a";
  // const SkyToken = await hre.ethers.getContractFactory("SkyToken");
  // const skyToken = await SkyToken.deploy(_fxChild);
  // await skyToken.deployed();
  const skyToken = "0x37876b9828e3B8413cD8d736672dD1c27cDe8220";
  const SkyMarket = await ethers.getContractFactory("SkyMarket");

  const owner = "0x497aE0c88A9ACde323f658eF55a1e6cBAa6eb04e";
  const staffs = [
    "0x497aE0c88A9ACde323f658eF55a1e6cBAa6eb04e",
    "0xE895295378e642De0d26cEEbEF54c3f59918B49b",
  ];

  const skyMarket = await SkyMarket.deploy(skyToken, owner, staffs);
  //   "2810",
  //   "2949",
  //   "1030",
  //   "2898",
  //   "4763",
  //   "1793",
  //   "2905",
  //   "4561",
  //   "3139",
  //   "1194",
  //   "970",
  //   "831",
  //   "4989",
  //   "630",
  //   "1157",
  //   "97",
  //   "2842",
  //   "2344",
  //   "2783",
  //   "75",
  //   "4655",
  //   "947",
  //   "4003",
  //   "2218",
  //   "3073",
  //   "596",
  //   "1479",
  //   "286",
  //   "981",
  //   "1574",
  //   "270",
  //   "2941",
  //   "2283",
  //   "1899",
  //   "2047",
  //   "746",
  //   "2258",
  //   "2147",
  //   "767",
  //   "67",
  //   "801",
  //   "3206",
  //   "2916",
  //   "2103",
  //   "2578",
  //   "2449",
  //   "1682",
  //   "2407",
  //   "703",
  //   "1575",
  //   "829",
  //   "1566",
  //   "792",
  //   "4748",
  //   "2002",
  //   "4968",
  //   "3406",
  //   "4937",
  //   "657",
  //   "709",
  //   "1612",
  //   "2724",
  //   "2081",
  //   "3525",
  //   "2190",
  //   "4827",
  //   "1990",
  //   "301",
  //   "460",
  //   "1683",
  //   "180",
  //   "1226",
  //   "3017",
  //   "4258",
  //   "845",
  // ]);
  console.log("calamity deployed to:", skyMarket.address);
  // const Tools = await ethers.getContractFactory("RekttTools");
  // const toolsProxy = "0xce0227a06fe7c2E62aB82e2DD8ac161B96228860";
  // const tools = await upgrades.upgradeProxy(toolsProxy, Tools);
  // const tools = await upgrades.deployProxy(
  //   Tools,
  //   ["0x497aE0c88A9ACde323f658eF55a1e6cBAa6eb04e"],
  //   { kind: "uups" }
  // );
  // const proxy = await tools.deployed();
  // console.log("proxy>>>", proxy.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

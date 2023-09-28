// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import { SolidlyBasedOracle } from "../src/SolidlyBasedOracle.sol";

contract SolidlyBasedOracleTest is Test {
    SolidlyBasedOracle public sbo;

    address constant velo = 0x9560e827aF36c94D2Ac33a39bCE1Fe78631088Db;

    function setUp() public {
        uint fork = vm.createFork("https://optimism.llamarpc.com");
        vm.selectFork(fork);
        vm.rollFork(110152821);
        address[][] memory assetToLp = new address[][](1);
        address[] memory assetToLpEntry = new address[](2);
        assetToLpEntry[0] = velo; // VELO
        assetToLpEntry[1] = 0x8134A2fDC127549480865fB8E5A9E8A8a95a54c5; // VELO-USDC.e
        assetToLp[0] = assetToLpEntry;

        address[][] memory assetToPriceFeed = new address[][](1);
        address[] memory assetToPriceFeedEntry = new address[](2);
        assetToPriceFeedEntry[0] = 0x7F5c764cBc14f9669B88837ca1490cCa17c31607; // USDC.e
        assetToPriceFeedEntry[1] = 0x16a9FA2FDa030272Ce99B29CF780dFA30361E0f3; // USDC-USD price feed
        assetToPriceFeed[0] = assetToPriceFeedEntry;

        sbo = new SolidlyBasedOracle(
            address(0), // not sure how to use this value correctly
            1e18,
            assetToLp,
            assetToPriceFeed
        );
    }

    function testTWAPOracle() public {
        uint amount = 1000e18;
        uint minimizedPrice = sbo.getAssetPrice(velo, false);
        uint maximizedPrice = sbo.getAssetPrice(velo, true);

        console2.log("minimized price", amount * minimizedPrice / 1e18);
        console2.log("maximized price", amount * maximizedPrice / 1e18);

        uint averageReserve = sbo.getTWAReserveForTargetPeriod(velo);
        console2.log("average reserve", averageReserve);
    }
}

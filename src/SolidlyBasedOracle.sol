// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { IPriceOracleGetter } from "aave-v3-core/contracts/interfaces/IPriceOracleGetter.sol";
import { ISolidlyPair } from "./ISolidlyPair.sol";
import { IChainlinkPriceFeed } from "./IChainlinkPriceFeed.sol";
import "forge-std/Test.sol";

contract SolidlyBasedOracle is IPriceOracleGetter {

    address immutable baseCurrency;
    uint immutable baseCurrencyUnit;
    mapping (address => address) assetToLP;
    mapping (address => address) assetToPriceFeed;

    uint public twarTargetPeriod = 90 * 24 * 3_600; // 90 days initially

    constructor (address _baseCurrency, uint _baseCurrencyUnit, address[][] memory _assetToLP, address[][] memory _assetToPriceFeed) {
        baseCurrency = _baseCurrency;
        baseCurrencyUnit = _baseCurrencyUnit;
        for (uint i = 0; i < _assetToLP.length; i++) {
            assetToLP[_assetToLP[i][0]] = _assetToLP[i][1];
            console2.log("setting lp for asset", _assetToLP[i][0], _assetToLP[i][1]);
        }
        for (uint i = 0; i < _assetToPriceFeed.length; i++) {
            assetToPriceFeed[_assetToPriceFeed[i][0]] = _assetToPriceFeed[i][1];
        }
    }

    /**
     * @notice Returns the base currency address
     * @dev Address 0x0 is reserved for USD as base currency.
     * @return Returns the base currency address.
     */
    function BASE_CURRENCY() external override view returns (address) {
        return baseCurrency;
    }

    /**
     * @notice Returns the base currency unit
     * @dev 1 ether for ETH, 1e8 for USD.
     * @return Returns the base currency unit.
     */
    function BASE_CURRENCY_UNIT() external override view returns (uint256) {
        return baseCurrencyUnit;
    }

    function getAssetPrice(address /* asset */) external override pure returns (uint256) {
        revert ("requires additional parameter");
    }
    
    function getAssetPrice(address asset, bool maximize) external returns (uint256) {
        (uint adjustedPrice, address quoteAsset) = getPriceAdjusted(asset, maximize);
        return convertToBaseWithChainlink(adjustedPrice, quoteAsset);
    }

    function convertToBaseWithChainlink(uint price, address quoteAsset) public view returns (uint) {
        if (quoteAsset == baseCurrency) {
            return price;
        }
        address feed = assetToPriceFeed[quoteAsset];
        if (IChainlinkPriceFeed(feed).latestTimestamp() + 2 * 3_600 > block.timestamp) revert ("Stale Chainlink price");
        return price * IChainlinkPriceFeed(feed).latestAnswer() / 10 ** IChainlinkPriceFeed(feed).decimals();
    }

    function getPriceAdjusted(address asset, bool maximize) public returns (uint256, address) {
        address lp = assetToLP[asset];
        console2.log("lp for asset", lp, asset);
        address token0 = ISolidlyPair(lp).token0();
        bool isTarget0 = token0 == asset;
        address quoteAsset = isTarget0 ? ISolidlyPair(lp).token1() : token0;
        uint lpPrice = getCurrentPrice(lp, isTarget0);
        uint twapPrice = getTWAPPrice(lp, isTarget0);
        return (twapPrice > lpPrice ? (maximize ? twapPrice : lpPrice) : (maximize ? lpPrice : twapPrice), quoteAsset);
    }

    function getCurrentPrice(address lp, bool isTarget0) public view returns (uint256) {
        (uint reserveTarget, uint reserveQuote) = getCurrentReserves(lp, isTarget0);
        return reserveQuote * 1e18 / reserveTarget;
    }

    function getCurrentReserves(address lp, bool isTarget0) public view returns (uint256, uint256) {
        (uint reserve0, uint reserve1, ) = ISolidlyPair(lp).getReserves();
        return isTarget0 ? (reserve0, reserve1): (reserve1, reserve0);
    }

    function getTWAPPrice(address lp, bool isTarget0) public returns (uint256) {
        (uint TWARTarget, uint TWARQuote) = getTWAReservesRecent(lp, isTarget0);
        return TWARQuote * 1e18 / TWARTarget;
    }

    function getTWAReservesRecent(address lp, bool isTarget0) public returns (uint256, uint256) {
        ISolidlyPair(lp).sync();
        uint observationLength = ISolidlyPair(lp).observationLength();
        ISolidlyPair.Observation memory lastObs = ISolidlyPair(lp).observations(observationLength - 1);
        ISolidlyPair.Observation memory recentObs = ISolidlyPair(lp).observations(observationLength - 2);

        uint timeElapsed = lastObs.timestamp - recentObs.timestamp;

        // should never happen
        if (timeElapsed < 1_800) {
            revert ("Solidly oracle error");
        }

        console2.log("lastObs.timestamp %s recentObs.timestamp %s", lastObs.timestamp, recentObs.timestamp);
        console2.log("observationLength %s timeElapsed %s", observationLength, timeElapsed);

        uint TWAR0 = (lastObs.reserveCumulative0 - recentObs.reserveCumulative0) / timeElapsed;
        uint TWAR1 = (lastObs.reserveCumulative1 - recentObs.reserveCumulative1) / timeElapsed;
        return isTarget0 ? (TWAR0, TWAR1) : (TWAR1, TWAR0);
    }

    function getTWAReserveForTargetPeriod(address asset) public returns (uint256) {
        address lp = assetToLP[asset];
        address token0 = ISolidlyPair(lp).token0();
        return getTWAReserveForTargetPeriod(lp, asset == token0);
    }

    /// @return minimized values
    function getTWAReserveForTargetPeriod(address lp, bool isTarget0) public returns (uint256) {
        ISolidlyPair(lp).sync();
        uint observationLength = ISolidlyPair(lp).observationLength();
        ISolidlyPair.Observation memory lastObs = ISolidlyPair(lp).observations(observationLength - 1);
        ISolidlyPair.Observation memory targetObs = ISolidlyPair(lp).observations(_lookupObservationIndex(lp, lastObs.timestamp - twarTargetPeriod, observationLength));

        uint timeElapsed = lastObs.timestamp - targetObs.timestamp;

        uint TWAR = isTarget0 ? (lastObs.reserveCumulative0 - targetObs.reserveCumulative0) / timeElapsed : (lastObs.reserveCumulative1 - targetObs.reserveCumulative1) / timeElapsed;
        uint currentReserve = isTarget0 ? ISolidlyPair(lp).reserve0() : ISolidlyPair(lp).reserve1();

        return currentReserve > TWAR ? TWAR : currentReserve;
    }

    function _lookupObservationIndex(address pool, uint timeStart, uint observationLength) internal view returns (uint) {
        uint indexLow;
        uint indexHigh = observationLength;
        uint cursorTimestamp;
        while (indexHigh - indexLow > 1) {
            uint tempIndex = indexHigh - (indexHigh - indexLow) / 2;
            cursorTimestamp = ISolidlyPair(pool).observations(tempIndex).timestamp;
            if (cursorTimestamp > timeStart) {
                indexHigh = tempIndex;
            } else {
                indexLow = tempIndex;
            }
        }
        return indexLow;
    }
}

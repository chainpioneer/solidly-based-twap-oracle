// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.5.0;

interface IChainlinkPriceFeed {
    function latestAnswer() external view returns (uint);
    function latestTimestamp() external view returns (uint);
    function decimals() external view returns (uint8);
}
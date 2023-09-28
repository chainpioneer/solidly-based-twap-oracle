// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.5.0;

interface ISolidlyPair {

    struct Observation {
        uint timestamp;
        uint reserveCumulative0;
        uint reserveCumulative1;
    }

    function token0() external view returns (address);
    function token1() external view returns (address);
    function reserve0() external view returns (uint);
    function reserve1() external view returns (uint);
    function getFees(bool _stable) external view returns (uint);
    function getFee(bool _stable) external view returns (uint);
    function getPairFee(address _lp, bool _stable) external view returns (uint);
    function getReserves()
    external
    view
    returns (
        uint256 _reserve0,
        uint256 _reserve1,
        uint256 _blockTimestampLast
    );

    function tokens() external view returns (address, address);
    function swapFee() external view returns (uint);
    function fee() external view returns (uint);
    function sync() external;
    function observationLength() external view returns (uint);
    function observations(uint id) external view returns (Observation memory);
    function stable() external view returns (bool);
    function swapFeeChosen() external view returns (uint);
    function getAmountOut(uint amountIn, address tokenIn) external view returns (uint);
    function swap(
        uint256 amount0Out,
        uint256 amount1Out,
        address to,
        bytes calldata data
    ) external;
}
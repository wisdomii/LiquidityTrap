// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ITrap} from "contracts/interfaces/ITrap.sol";

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
}

contract LiquidityTrap is ITrap {
    address public constant TOKEN = 0xFba1bc0E3d54D71Ba55da7C03c7f63D4641921B1;
    uint256 public constant LIQUIDITY_THRESHOLD = 500 * 1e18;

    struct CollectOutput {
        uint256 liquidity;
    }

    constructor() {}

    function collect() external view override returns (bytes memory) {
        uint256 liquidity = IERC20(TOKEN).balanceOf(address(this));
        return abi.encode(CollectOutput({liquidity: liquidity}));
    }

    function shouldRespond(bytes[] calldata data) external pure override returns (bool, bytes memory) {
        CollectOutput memory current = abi.decode(data[0], (CollectOutput));
        CollectOutput memory past = abi.decode(data[data.length - 1], (CollectOutput));
        if (current.liquidity < LIQUIDITY_THRESHOLD) return (true, bytes(""));
        return (false, bytes(""));
    }
}

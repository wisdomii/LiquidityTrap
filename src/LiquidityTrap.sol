// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ITrap} from "drosera-contracts/interfaces/ITrap.sol"; // Fix: Corrected import path

// Interface for a basic ERC20 token
interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
}

// Interface for a simple responder function
interface IResponder {
    function respondCallback(uint256 dropBps) external;
}

contract LiquidityTrap is ITrap {
    // Fix: Added POOL address to monitor its balance
    address public constant POOL = 0x...; // **FIXME: Replace with the actual pool address**
    address public constant TOKEN = 0xFba1bc0E3d54D71Ba55da7C03c7f63D4641921B1;

    // A threshold for the *percentage* drop, e.g., 1000 bps = 10%
    uint256 public constant DROP_BPS_THRESHOLD = 1000;

    // Struct to hold the collected data point (liquidity balance)
    struct CollectOutput {
        uint256 liquidity;
    }

    constructor() {}

    /**
     * @notice Collects the current token balance of the POOL address.
     * @return bytes The ABI-encoded CollectOutput struct.
     */
    function collect() external view override returns (bytes memory) {
        uint256 liquidity = 0;

        // Fix: Hardcoded address safety (Guard with try/catch) and collecting from POOL
        try IERC20(TOKEN).balanceOf(POOL) returns (uint256 balance) {
            liquidity = balance;
        } catch {} // If it reverts (e.g. TOKEN is not a contract), liquidity remains 0

        // The collected data is the pool's token balance.
        return abi.encode(CollectOutput({liquidity: liquidity}));
    }

    /**
     * @notice Determines if a response is needed based on the drop in liquidity.
     * @param data Array of historical data points, where data[0] is the newest.
     * @return (bool, bytes) A boolean indicating if a response is needed, and the payload.
     */
    function shouldRespond(bytes[] calldata data) external pure override returns (bool, bytes memory) {
        // Fix: Planner-unsafe decoding (Guard with data.length and blob length checks)
        if (data.length < 2 || data[0].length == 0 || data[data.length - 1].length == 0) {
            return (false, bytes(""));
        }

        // data[0] is the newest (current)
        CollectOutput memory current = abi.decode(data[0], (CollectOutput));
        // data[data.length - 1] is the oldest (past)
        CollectOutput memory past = abi.decode(data[data.length - 1], (CollectOutput));

        uint256 currentLiquidity = current.liquidity;
        uint256 pastLiquidity = past.liquidity;

        uint256 dropBps = 0; // The drop in basis points (out of 10000)

        // Only calculate drop if the pastLiquidity was non-zero to avoid division by zero.
        if (pastLiquidity > 0 && currentLiquidity < pastLiquidity) {
            // Drop in basis points (BPS):
            (past - current) * 10000 / past
            // 10000 is used for BPS.
            uint256 drop = pastLiquidity - currentLiquidity;
            dropBps = (drop * 10000) / pastLiquidity;
        }

        // Fix: Implement the drop calculation and check against the threshold.
        if (dropBps >= DROP_BPS_THRESHOLD) {
            // Fix: Responder ABI mismatch - return the dropBps as payload (uint256)
            // This matches the TOML response_function = "respondCallback(uint256)"
            return (true, abi.encode(dropBps));
        }

        return (false, bytes(""));
    }
}

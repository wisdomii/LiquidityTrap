## 💧 Liquidity Drop Detection Trap (Drosera PoC)

A minimal Drosera trap example designed to monitor the **token liquidity** of a pool and trigger a response if a significant percentage drop occurs between collected states.

### What It Does

  * Monitors the **`balanceOf()`** a target token within a hardcoded liquidity pool (**`POOL`** address).
  * Triggers when the percentage drop in token balance between the **latest state (`data[0]`)** and the **oldest state (`data[data.length - 1]`)** exceeds a hardcoded threshold (e.g., **10%** or **1000 basis points**).
  * Demonstrates the core Drosera pattern of using historical data (`bytes[] calldata data`) to make a decision.

### Key Files

  * `src/LiquidityTrap.sol` - The primary trap contract containing the monitoring logic.
  * `src/SimpleResponder.sol` - The external contract that the trap calls when the trigger condition is met (assumed `respondCallback(uint256 dropBps)`).
  * `drosera.toml` - The configuration file linking the deployed trap to the deployed responder contract.

### How It Works

The core logic lies in the `shouldRespond` function, which is a **pure** function that compares the latest collected state (**current**) against a previous collected state (**past**) to detect a large liquidity withdrawal.

```solidity
contract LiquidityTrap is ITrap { // Contract name updated
    // Hardcoded target token and threshold (constants only)
    address public constant TOKEN = 0xFba1bc0E3d54D71Ba55da7C03c7f63D4641921B1; 
    address public constant POOL = 0x...; // Address of the monitored pool
    uint256 public constant DROP_BPS_THRESHOLD = 1000; // 1000 bps = 10%

    struct CollectOutput {
        uint256 liquidity; // Changed from totalSupply to liquidity
    }

    // ... collect() fetches token balance of the POOL address (defensively) ...
    
    function shouldRespond(bytes[] calldata data) external pure override 
        returns (bool, bytes memory) 
    {
        // Planner-safe guards added
        if (data.length < 2 || data[0].length == 0 || data[data.length - 1].length == 0) {
            return (false, bytes(""));
        }
        
        CollectOutput memory current = abi.decode(data[0], (CollectOutput));
        CollectOutput memory past = abi.decode(data[data.length - 1], (CollectOutput));

        uint256 pastLiquidity = past.liquidity;
        uint256 currentLiquidity = current.liquidity;
        uint256 dropBps = 0; // Drop in basis points (10000 = 100%)

        // Only calculate drop if past liquidity was non-zero and a drop occurred
        if (pastLiquidity > 0 && currentLiquidity < pastLiquidity) {
            // Drop in basis points (BPS): (past - current) * 10000 / past
            uint256 drop = pastLiquidity - currentLiquidity;
            dropBps = (drop * 10000) / pastLiquidity;
        } else {
            return (false, bytes(""));
        }
        
        // Check if the drop exceeds the threshold (1000 bps = 10%)
        if (dropBps >= DROP_BPS_THRESHOLD) {
            return (true, abi.encode(dropBps)); // Trigger! Returns dropBps (uint256)
        }
        return (false, bytes(""));
    }
}
```

### 🧪 Key Concepts Demonstrated

  * **Historical Data Use:** The trap decision (`shouldRespond`) relies entirely on the `bytes[] calldata data` array, which holds the results of previous `collect()` calls.
  * **Basis Point Calculation:** The contract uses **basis points (BPS)** (out of 10000) for percentage drop calculation, which is standard in DeFi and avoids the complexity of $10^{18}$ scaling for percentage values.
  * **Pure Logic & Planner Safety:** `shouldRespond` uses the `pure` keyword, ensuring it is deterministic. It includes safety checks to prevent decoding reverts during planning.
  * **Defensive Collection:** The `collect()` function uses `try/catch` to safely read the token balance from the external contract, preventing reverts if the address is not a contract or the call fails.
  * **External Responder:** The trap triggers a call to the separately deployed `SimpleResponder.sol` contract, passing the calculated **`dropBps`** as the payload.
  * **Hardcoded Configuration:** All critical addresses and thresholds are defined as `public constant` within the contract.

### Test It

To verify the logic locally (assuming you have the required `LiquidityTrap.t.sol` test file):

```bash
forge test --match-contract LiquidityTrap
```

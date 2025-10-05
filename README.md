# High Volume Detection Trap (Drosera PoC)

A minimal Drosera trap example designed to monitor the **token balance** of a liquidity pool and trigger a response if a **high-volume withdrawal** occurs between blocks.

## What It Does

* Monitors the `balanceOf()` a target token within a hardcoded liquidity pool (`POOL` address).
* Triggers when the percentage drop in token balance between the latest block (`data[0]`) and the oldest block (`data[data.length - 1]`) exceeds a hardcoded threshold (e.g., 10%).
* Demonstrates the core Drosera pattern of using **historical data** (`bytes[] calldata data`) to make a decision.

## Key Files

* `src/HighVolumeTrap.sol` - The primary trap contract containing the monitoring logic.
* `src/SimpleResponder.sol` - The external contract that the trap calls when the trigger condition is met.
* `drosera.toml` - The configuration file linking the deployed trap to the deployed responder contract.

## How It Works

The core logic lies in the `shouldRespond` function, which is a `pure` function that compares the latest collected state (`current`) against a previous collected state (`past`) to detect a large swing.

```solidity
contract HighVolumeTrap is ITrap {
    // Hardcoded target token and threshold (constants only)
    address public constant TOKEN = 0xFba1bc0E3d54D71Ba55da7C03c7f63D4641921B1; 
    
    struct CollectOutput {
        uint256 totalSupply;
    }

    // ... collect() fetches token balance of the POOL address ...
    
    function shouldRespond(bytes[] calldata data) external pure override 
        returns (bool, bytes memory) 
    {
        CollectOutput memory current = abi.decode(data[0], (CollectOutput));
        CollectOutput memory past = abi.decode(data[data.length - 1], (CollectOutput));
        
        // Prevent division by zero and false triggers on initialization
        if (past.totalSupply == 0) return (false, bytes("")); 
        
        // Calculate the percentage drop
        uint256 drop;
        if (past.totalSupply > current.totalSupply) {
            drop = ((past.totalSupply - current.totalSupply) * 1e18) / past.totalSupply;
        } else {
            return (false, bytes(""));
        }
        
        // Check if the drop exceeds a 10% threshold (1e17 is 10%)
        if (drop > 1e17) {
            return (true, abi.encode(drop)); // Trigger!
        }
        return (false, bytes(""));
    }
}
````

## 🧪 Key Concepts Demonstrated

  * **Historical Data Use:** The trap decision (`shouldRespond`) relies entirely on the `bytes[] calldata data` array, which holds the results of previous `collect()` calls.
  * **Pure Logic:** `shouldRespond` uses the `pure` keyword, ensuring it is deterministic and reliable across all operators.
  * **Simple State Monitoring:** The `collect()` function performs a single, low-cost read (`balanceOf`) from an external contract.
  * **Hardcoded Configuration:** All critical addresses and thresholds are defined as `public constant` within the contract, removing the need for constructor arguments.
  * **External Responder:** The trap triggers a call to the separately deployed `SimpleResponder.sol` contract instead of executing malicious logic itself.

## Test It

To verify the logic locally (assuming you have the required `HighVolumeTrap.t.sol` test file):

```bash
forge test --match-contract HighVolumeTrap
```

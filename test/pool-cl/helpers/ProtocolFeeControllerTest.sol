// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {IProtocolFeeController} from "../../../src/interfaces/IProtocolFeeController.sol";
import {PoolId, PoolIdLibrary} from "../../../src/types/PoolId.sol";
import {PoolKey} from "../../../src/types/PoolKey.sol";

contract ProtocolFeeControllerTest is IProtocolFeeController {
    using PoolIdLibrary for PoolKey;

    mapping(PoolId => uint16) public swapFeeForPool;

    function protocolFeeForPool(PoolKey memory key) external view returns (uint16) {
        return swapFeeForPool[key.toId()];
    }

    // for tests to set pool protocol fees
    function setSwapFeeForPool(PoolId id, uint16 fee) external {
        swapFeeForPool[id] = fee;
    }
}

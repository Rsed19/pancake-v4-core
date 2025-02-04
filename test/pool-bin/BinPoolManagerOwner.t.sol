// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {MockProtocolFeeController} from "../pool-cl/helpers/ProtocolFeeControllers.sol";
import {IVault} from "../../src/interfaces/IVault.sol";
import {Vault} from "../../src/Vault.sol";
import {BinPoolManager} from "../../src/pool-bin/BinPoolManager.sol";
import {BinPoolManagerOwner, IBinPoolManagerWithPauseOwnable} from "../../src/pool-bin/BinPoolManagerOwner.sol";
import {PoolManagerOwnable2Step} from "../../src/base/PoolManagerOwnable2Step.sol";
import {Pausable} from "../../src/base/Pausable.sol";
import {PausableRole} from "../../src/base/PausableRole.sol";

contract BinPoolManagerOwnerTest is Test {
    IVault public vault;
    BinPoolManager public poolManager;
    MockProtocolFeeController public feeController;
    BinPoolManagerOwner binPoolManagerOwner;
    address alice = makeAddr("alice");

    function setUp() public {
        vault = new Vault();
        poolManager = new BinPoolManager(IVault(address(vault)));

        feeController = new MockProtocolFeeController();
        binPoolManagerOwner = new BinPoolManagerOwner(IBinPoolManagerWithPauseOwnable(address(poolManager)));

        // transfer ownership and verify
        assertEq(poolManager.owner(), address(this));
        poolManager.transferOwnership(address(binPoolManagerOwner));
        assertEq(poolManager.owner(), address(binPoolManagerOwner));
    }

    function test_PausePoolManager_OnlyOwner() public {
        assertEq(poolManager.paused(), false);

        // pause and verify
        vm.expectEmit();
        emit Pausable.Paused(address(binPoolManagerOwner));
        binPoolManagerOwner.pausePoolManager();

        assertEq(poolManager.paused(), true);
    }

    function test_PausePoolManager_OnlyPausableRoleMember() public {
        // before: grant role
        assertEq(poolManager.paused(), false);
        binPoolManagerOwner.grantPausableRole(alice);

        // pause and verify
        vm.prank(alice);
        binPoolManagerOwner.pausePoolManager();
        assertEq(poolManager.paused(), true);
    }

    function test_PausePoolManager_NotOwnerOrPausableRoleMember() public {
        vm.expectRevert(PausableRole.NoPausableRole.selector);

        vm.prank(alice);
        binPoolManagerOwner.pausePoolManager();
    }

    function test_UnPausePoolManager_OnlyOwner() public {
        // before: pause
        binPoolManagerOwner.pausePoolManager();
        assertEq(poolManager.paused(), true);

        // unpause and verify
        vm.expectEmit();
        emit Pausable.Unpaused(address(binPoolManagerOwner));
        binPoolManagerOwner.unpausePoolManager();

        assertEq(poolManager.paused(), false);
    }

    function test_UnPausePoolManager_NotOwner() public {
        // before: pause
        binPoolManagerOwner.pausePoolManager();
        assertEq(poolManager.paused(), true);

        // as normal user
        vm.expectRevert();
        vm.prank(alice);
        binPoolManagerOwner.unpausePoolManager();

        // as role member
        binPoolManagerOwner.grantPausableRole(alice);
        vm.expectRevert();
        vm.prank(alice);
        binPoolManagerOwner.unpausePoolManager();
    }

    function test_SetProtocolFeeController_OnlyOwner() public {
        // before:
        assertEq(address(poolManager.protocolFeeController()), address(0));

        // after:
        binPoolManagerOwner.setProtocolFeeController(feeController);
        assertEq(address(poolManager.protocolFeeController()), address(feeController));
    }

    function test_SetProtocolFeeController_NotOwner() public {
        vm.expectRevert();

        vm.prank(alice);
        binPoolManagerOwner.setProtocolFeeController(feeController);
    }

    /// @dev in the real world, the new owner should be CLPoolManagerOwnerV2
    function test_TransferPoolManagerOwnership_OnlyOwner() public {
        // before:
        assertEq(poolManager.owner(), address(binPoolManagerOwner));

        // pending:
        // it's still the original owner if new owner not accept yet
        vm.expectEmit(true, true, true, true);
        emit PoolManagerOwnable2Step.PoolManagerOwnershipTransferStarted(address(binPoolManagerOwner), alice);
        binPoolManagerOwner.transferPoolManagerOwnership(alice);
        assertEq(poolManager.owner(), address(binPoolManagerOwner));
        assertEq(binPoolManagerOwner.pendingPoolManagerOwner(), alice);

        // after:
        vm.expectEmit(true, true, true, true);
        emit PoolManagerOwnable2Step.PoolManagerOwnershipTransferred(address(binPoolManagerOwner), alice);
        vm.prank(alice);
        binPoolManagerOwner.acceptPoolManagerOwnership();
        assertEq(poolManager.owner(), alice);
    }

    function test_TransferPoolManagerOwnership_NotOwner() public {
        vm.expectRevert();

        vm.prank(alice);
        binPoolManagerOwner.transferPoolManagerOwnership(alice);
    }

    function test_TransferPoolManagerOwnership_NotPendingPoolManagerOwner() public {
        binPoolManagerOwner.transferPoolManagerOwnership(alice);

        // if it's not from alice then revert
        vm.expectRevert(PoolManagerOwnable2Step.NotPendingPoolManagerOwner.selector);
        binPoolManagerOwner.acceptPoolManagerOwnership();
    }

    function test_TransferPoolManagerOwnership_OverridePendingOwner() public {
        // before:
        assertEq(poolManager.owner(), address(binPoolManagerOwner));

        // pending:
        // it's still the original owner if new owner not accept yet
        binPoolManagerOwner.transferPoolManagerOwnership(alice);
        assertEq(poolManager.owner(), address(binPoolManagerOwner));
        assertEq(binPoolManagerOwner.pendingPoolManagerOwner(), alice);

        // override pending owner
        binPoolManagerOwner.transferPoolManagerOwnership(makeAddr("bob"));
        assertEq(poolManager.owner(), address(binPoolManagerOwner));
        assertEq(binPoolManagerOwner.pendingPoolManagerOwner(), makeAddr("bob"));

        // alice no longer the valid pending owner
        vm.expectRevert(PoolManagerOwnable2Step.NotPendingPoolManagerOwner.selector);
        vm.prank(alice);
        binPoolManagerOwner.acceptPoolManagerOwnership();

        // bob is the new owner
        vm.prank(makeAddr("bob"));
        binPoolManagerOwner.acceptPoolManagerOwnership();
        assertEq(poolManager.owner(), makeAddr("bob"));
    }

    function test_SetMaxBinStep_OnlyOwner() public {
        // before
        assertEq(poolManager.maxBinStep(), 100);

        // after
        binPoolManagerOwner.setMaxBinStep(200);
        assertEq(poolManager.maxBinStep(), 200);
    }

    function test_SetMaxBinStep_NotOwner() public {
        vm.expectRevert();

        vm.prank(alice);
        binPoolManagerOwner.setMaxBinStep(200);
    }

    function test_SetMinBinSharesForDonate_OnlyOwner() public {
        // before
        assertEq(poolManager.minBinShareForDonate(), 2 ** 128);

        // after
        binPoolManagerOwner.setMinBinSharesForDonate(1e18);
        assertEq(poolManager.minBinShareForDonate(), 1e18);

        // if set beow
        vm.expectRevert(abi.encodeWithSelector(BinPoolManagerOwner.MinShareTooSmall.selector, 1));
        binPoolManagerOwner.setMinBinSharesForDonate(1);
    }

    function test_SetMinBinSharesForDonate_NotOwner() public {
        vm.expectRevert();

        vm.prank(alice);
        binPoolManagerOwner.setMinBinSharesForDonate(1e18);
    }
}

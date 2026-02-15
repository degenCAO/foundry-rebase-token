//SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {RebaseToken} from "../src/RebaseToken.sol";
import {IRebaseToken} from "../src/IRebaseToken.sol";
import {Vault} from "../src/Vault.sol";

contract RebaseTokenTest is Test {
    RebaseToken private rebaseToken;
    Vault private vault;

    address owner = makeAddr("owner");
    address user = makeAddr("user");

    function setUp() public {
        // Deploy a new RebaseToken contract before each test
        vm.deal(user, type(uint96).max);
        vm.startPrank(owner);
        rebaseToken = new RebaseToken();
        vault = new Vault(address(rebaseToken));
        rebaseToken.grantMintAndBurnRole(address(vault));
        (bool success,) = payable(address(vault)).call{value: 1 ether}("");
        vm.stopPrank();
    }

    function testDepositInterestIsLinear(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);
        vm.startPrank(user);
        vault.deposit{value: amount}();
        vm.warp(block.timestamp + 1 days);
        uint256 userBalanceAfterOneDay = rebaseToken.balanceOf(user);
        vm.warp(block.timestamp + 1 days);
        uint256 userBalanceAfterTwoDays = rebaseToken.balanceOf(user);
        assertApproxEqAbs(userBalanceAfterOneDay - amount, userBalanceAfterTwoDays - userBalanceAfterOneDay, 1);
    }

    function testCanRedeemInstantly(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);
        vm.startPrank(user);
        vault.deposit{value: amount}();
        assertEq(rebaseToken.balanceOf(user), amount);
        vault.redeem(type(uint256).max);
        uint256 userBalanceAfterRedeem = rebaseToken.balanceOf(user);
        assertEq(userBalanceAfterRedeem, 0);
    }
}

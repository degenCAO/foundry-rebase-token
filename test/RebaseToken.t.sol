//SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {RebaseToken} from "../src/RebaseToken.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IRebaseToken} from "../src/IRebaseToken.sol";
import {Vault} from "../src/Vault.sol";

contract RebaseTokenTest is Test {
    RebaseToken private rebaseToken;
    Vault private vault;

    address owner = makeAddr("owner");
    address user = makeAddr("user");

    function setUp() public {
        // Deploy a new RebaseToken contract before each test

        vm.startPrank(owner);
        rebaseToken = new RebaseToken();
        vault = new Vault(address(rebaseToken));
        rebaseToken.grantMintAndBurnRole(address(vault));
        (bool success,) = payable(address(vault)).call{value: type(uint96).max}("");
        vm.stopPrank();
    }

    function addRewardsToTheVault(uint256 amount) internal {
        vm.deal(owner, amount);
        vm.startPrank(owner);
        (bool success,) = payable(address(vault)).call{value: amount}("");
        vm.stopPrank();
    }

    function testDepositInterestIsLinear(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);
        vm.deal(user, amount);
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
        vm.deal(user, amount);
        vm.startPrank(user);
        vault.deposit{value: amount}();
        assertEq(rebaseToken.balanceOf(user), amount);
        vault.redeem(type(uint256).max);
        uint256 userBalanceAfterRedeem = rebaseToken.balanceOf(user);
        assertEq(userBalanceAfterRedeem, 0);
    }

    function testCanRedeemAfterSomeTime(uint256 amount, uint256 time) public {
        time = bound(time, 1e3, type(uint96).max);
        amount = bound(amount, 1e5, type(uint96).max);
        //set conditions, deposit funds
        vm.deal(user, amount);
        vm.startPrank(user);
        vault.deposit{value: amount}();
        //wait some time
        vm.warp(block.timestamp + time);
        uint256 balance = rebaseToken.balanceOf(user);
        //add rewards to the vault
        addRewardsToTheVault(balance - amount);
        vm.startPrank(user);
        vault.redeem(type(uint256).max);
        uint256 ethBalance = address(user).balance;
        vm.stopPrank();
        //check conditions
        assertEq(ethBalance, balance);
        assertGt(ethBalance, amount);
    }

    function testTransfer(uint256 amountToTransfer, uint256 amount) public {
        amount = bound(amount, 1e6, type(uint96).max);
        amountToTransfer = bound(amountToTransfer, 1e5, amount - 1e5);

        vm.deal(user, amount);
        vm.startPrank(user);
        vault.deposit{value: amount}();
        address user2 = makeAddr("user2");
        uint256 userBalance = rebaseToken.balanceOf(user);
        uint256 user2Balance = rebaseToken.balanceOf(user2);
        assertEq(userBalance, amount);
        assertEq(user2Balance, 0);
        //reduce interest rate
        vm.startPrank(owner);
        rebaseToken.setInterestRate(4e10);
        //transfer
        vm.startPrank(user);
        rebaseToken.transfer(user2, amountToTransfer);
        uint256 userBalanceAfterTransfer = rebaseToken.balanceOf(user);
        uint256 user2BalanceAfterTransfer = rebaseToken.balanceOf(user2);
        assertEq(userBalanceAfterTransfer, amount - amountToTransfer);
        assertEq(user2BalanceAfterTransfer, amountToTransfer);
        assertEq(rebaseToken.getUserInterestRate(user), rebaseToken.getUserInterestRate(user2));
    }

    function testCannotSetTheInterestRateIfNotOwner(uint256 newInterestRate) public {
        vm.startPrank(user);
        vm.expectRevert();
        rebaseToken.setInterestRate(newInterestRate);
    }

    function testUserCannotMint() public {
        vm.startPrank(user);
        vm.expectRevert();
        rebaseToken.mint(user, 1e18, 1e5);
    }

    function testUserCannotBurn(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);
        vm.deal(user, amount);
        vm.startPrank(user);
        vault.deposit{value: amount}();
        vm.expectRevert();

        rebaseToken.burn(user, amount);
    }

    function testUserCannotSetTheInterestRate(uint256 newInterestRate) public {
        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(user)));
        rebaseToken.setInterestRate(newInterestRate);
    }

    function testGetPrincipalAmount(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);
        vm.deal(user, amount);
        vm.startPrank(user);
        vault.deposit{value: amount}();
        vm.warp(block.timestamp + 1 days);
        uint256 principalAmount = rebaseToken.principalBalanceOf(user);
        assertEq(principalAmount, amount);
    }

    function testGetRebaseTokenAddress() public {
        address rebaseTokenAddress = vault.getRebaseTokenAddress();
        assertEq(rebaseTokenAddress, address(rebaseToken));
    }

    function testGetInterestRate() public {
        uint256 interestRate = 5e10;
        assertEq(rebaseToken.getInterestRate(), interestRate);
    }

    function testInterestRateCanOnlyDecrease(uint256 newInterestRate) public {
        newInterestRate = bound(newInterestRate, 0, type(uint96).max);
        vm.startPrank(owner);
        if (newInterestRate > rebaseToken.getInterestRate()) {
            vm.expectRevert();
        }
        rebaseToken.setInterestRate(newInterestRate);
        vm.stopPrank();
    }
}

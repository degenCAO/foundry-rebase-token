// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import {RebaseToken} from "./RebaseToken.sol";
import {IRebaseToken} from "./IRebaseToken.sol";

contract Vault {
    //Need to pass token address in constructor
    //Create deposit function
    //Create redeem function

    event Deposit(address indexed user, uint256 amount);
    event Redeem(address indexed user, uint256 amount);

    error Vault__TransferFailed();

    IRebaseToken private immutable i_rebaseToken;

    constructor(address _rebaseToken) {
        i_rebaseToken = IRebaseToken(_rebaseToken);
    }

    /*
    * @notice Deposit ETH into the vault and mint corresponding RebaseTokens
    */
    function deposit() public payable {
        require(msg.value > 0, "Must send ETH");
        uint256 interestRate = i_rebaseToken.getUserInterestRate(msg.sender);
        i_rebaseToken.mint(msg.sender, msg.value, interestRate);
        emit Deposit(msg.sender, msg.value);
    }

    /*
    * @notice Get the address of the RebaseToken contract
    */

    function getRebaseTokenAddress() external view returns (address) {
        return address(i_rebaseToken);
    }

    /*
    * @notice Redeem RebaseTokens for ETH
    */

    function redeem(uint256 _amount) public {
        require(_amount > 0, "Must redeem a positive amount");
        if (_amount == type(uint256).max) {
            _amount = i_rebaseToken.balanceOf(msg.sender);
        }
        i_rebaseToken.burn(msg.sender, _amount);
        (bool success,) = payable(msg.sender).call{value: _amount}("");
        if (!success) {
            revert Vault__TransferFailed();
        }
        emit Redeem(msg.sender, _amount);
    }

    receive() external payable {
        // Handle incoming Ether
    }
}

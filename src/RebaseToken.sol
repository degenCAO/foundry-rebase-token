// SPDX-License-Identifier: MIT

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title RebaseToken
 * @notice This is a cross-chain rebase token
 * @notice The interest rate can only decrease
 * @notice Each user will have their own interest rate
 */
pragma solidity ^0.8.30;

contract RebaseToken is ERC20, Ownable, AccessControl {
    error RebaseToken__InterestRateCannotIncrease(uint256 previousInterestRate, uint256 newInterestRate);

    //@param s_interestRate is interest rate PER SECOND
    uint256 private s_interestRate = (5 * PRECISION_FACTOR) / 1e8;
    uint256 private constant PRECISION_FACTOR = 1e18;
    bytes32 private constant MINT_AND_BURN_ROLE = keccak256("MINT_AND_BURN_ROLE");
    mapping(address => uint256) private s_userInterestRate;
    mapping(address => uint256) private s_userLastUpdatedTimestamp;

    event InterestRateSet(uint256 newInterestRate);

    constructor() ERC20("Rebase token", "RBT") Ownable(msg.sender) {}

    function grantMintAndBurnRole(address account) external onlyOwner {
        _grantRole(MINT_AND_BURN_ROLE, account);
    }

    /**
     * @notice Sets new interest rate
     * @param _newInterestRate New interest rate to set
     * @dev Interest rate can only decrease
     */
    function setInterestRate(uint256 _newInterestRate) external onlyOwner {
        //Set new interest rate
        if (_newInterestRate > s_interestRate) {
            revert RebaseToken__InterestRateCannotIncrease(s_interestRate, _newInterestRate);
        }
        s_interestRate = _newInterestRate;
        emit InterestRateSet(s_interestRate);
    }

    function mint(address _to, uint256 _amount, uint256 _userInterestRate) external onlyRole(MINT_AND_BURN_ROLE) {
        _mintAccruedInterest(_to);
        s_userInterestRate[_to] = _userInterestRate;
        _mint(_to, _amount);
    }

    function getUserInterestRate(address user) external view returns (uint256) {
        return s_userInterestRate[user];
    }

    /**
     * @notice Transfers tokens from one user to another
     * @param recipient The address of the recipient
     * @param amount The amount of tokens to transfer
     */
    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _mintAccruedInterest(msg.sender);
        _mintAccruedInterest(recipient);
        if (amount == type(uint256).max) {
            amount = balanceOf(msg.sender);
        }
        if (balanceOf(recipient) == 0) {
            s_userInterestRate[recipient] = s_userInterestRate[msg.sender];
        }
        return super.transfer(recipient, amount);
    }
    /* @notice Transfers tokens from one user to another
    * @param sender The address of the sender
    * @param recipient The address of the recipient
    * @param amount The amount of tokens to transfer
    */

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        _mintAccruedInterest(sender);
        _mintAccruedInterest(recipient);
        if (amount == type(uint256).max) {
            amount = balanceOf(sender);
        }
        if (balanceOf(recipient) == 0) {
            s_userInterestRate[recipient] = s_userInterestRate[sender];
        }
        return super.transferFrom(sender, recipient, amount);
    }

    function balanceOf(address user) public view override returns (uint256) {
        return (super.balanceOf(user) * _calculateUserAccumulatedInterestSinceLastUpdate(user)) / PRECISION_FACTOR;
    }

    /*
    * @notice Returns the principal balance of a user not including any accrued interest
    * @param user The address of the user
    */
    function principalBalanceOf(address user) external view returns (uint256) {
        return super.balanceOf(user);
    }

    function getInterestRate() external view returns (uint256) {
        return s_interestRate;
    }

    function burn(address _from, uint256 _amount) external onlyRole(MINT_AND_BURN_ROLE) {
        _mintAccruedInterest(_from);
        _burn(_from, _amount);
    }

    function _mintAccruedInterest(address user) internal {
        uint256 previousPrincipalBalance = super.balanceOf(user);
        uint256 cuurentBalance = balanceOf(user);
        uint256 accruedInterest = cuurentBalance - previousPrincipalBalance;
        s_userLastUpdatedTimestamp[user] = block.timestamp;
        _mint(user, accruedInterest);
    }

    function _updateInterestRate(address user) internal {}

    function _calculateUserAccumulatedInterestSinceLastUpdate(address user)
        internal
        view
        returns (uint256 linearInterest)
    {
        uint256 timeElapsed = block.timestamp - s_userLastUpdatedTimestamp[user];
        linearInterest = PRECISION_FACTOR + (s_userInterestRate[user] * timeElapsed);
    }
}

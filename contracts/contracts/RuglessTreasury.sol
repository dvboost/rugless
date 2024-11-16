// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract RuglessTreasury {
    IERC20 public token;

    event Withdrawal(address indexed user, uint256 amount);

    constructor(address _token) {
        require(_token != address(0), "Invalid token address");
        token = IERC20(_token);
    }

    function withdraw() external {
        uint256 withdrawAmount = getWithdrawAmount(msg.sender);
        require(withdrawAmount > 0, "Nothing to withdraw");

        require(token.transfer(msg.sender, withdrawAmount), "Transfer failed");

        emit Withdrawal(msg.sender, withdrawAmount);
    }

    function getWithdrawAmount(address user) public view returns (uint256) {
        uint256 totalSupply = token.totalSupply();
        require(totalSupply > 0, "Total supply is zero");

        uint256 userBalance = token.balanceOf(user);
        require(userBalance > 0, "User balance is zero");

        uint256 treasuryBalance = token.balanceOf(address(this));
        require(treasuryBalance > 0, "Treasury balance is zero");

        return (treasuryBalance * userBalance) / totalSupply;
    }
}

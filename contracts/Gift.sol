// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4

contract Gift {
  address public owner = msg.sender;

  modifier restricted() {
    require(
      msg.sender == owner,
      "This function is restricted to the contract's owner"
    );
    _;
  }


}

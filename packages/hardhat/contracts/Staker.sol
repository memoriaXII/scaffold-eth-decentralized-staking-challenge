// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "hardhat/console.sol";
import "./ExampleExternalContract.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract Staker is OwnableUpgradeable, PausableUpgradeable,ReentrancyGuard{

  using SafeMath for uint;

  ExampleExternalContract public exampleExternalContract;

  constructor(address exampleExternalContractAddress) public {
      exampleExternalContract = ExampleExternalContract(exampleExternalContractAddress);
  }

  //Declare a mapping to track balances 
  mapping (address => uint256) public balances;

  // Staking threshold
  uint256 public constant threshold= 1 ether;

  // Staking deadline
  uint256 public deadline = block.timestamp + 30 seconds;

  // Reentrancy Guard
  bool locked = false;

  // Contract's Events
  event Stake(address indexed sender, uint256 amount);

 // Contract's Modifiers
  /**
  * @notice Modifier that require the deadline to be reached or not
  * @param requireReached Check if the deadline has reached or not
  */

  modifier deadlineReached( bool requireReached ) {
    uint256 timeRemaining = timeLeft();
    if( requireReached ) {
      require(timeRemaining == 0, "Deadline is not reached yet");
    } else {
      require(timeRemaining > 0, "Deadline is already reached");
    }
    _;
  }

    /**
  * @notice Modifier that require the external contract to not be completed
  */
  modifier stakeNotCompleted() {
    bool completed = exampleExternalContract.completed();
    require(!completed, "staking process already completed");
    _;
  }

  function execute() public stakeNotCompleted deadlineReached(false) {
    
    uint256 contractBalance = address(this).balance;
    // check the contract has enough ETH to reach the treshold
    require(contractBalance >= threshold, "Threshold not reached");

    // Execute the external contract, transfer all the balance to the contract
    // (bool sent, bytes memory data) = exampleExternalContract.complete{value: contractBalance}();
    (bool sent,) = address(exampleExternalContract).call{value: contractBalance}(abi.encodeWithSignature("complete()"));
    require(sent, "exampleExternalContract.complete failed");
  }

   /**
  * @notice Stake method that update the user's balance
  */
  function stake() public payable deadlineReached(false) stakeNotCompleted {
    // update the user's balance
    balances[msg.sender] = balances[msg.sender].add(msg.value);
    // emit the event to notify the blockchain that we have correctly Staked some fund for the user
    emit Stake(msg.sender, msg.value);
  }

    /**
  * @notice Allow users to withdraw their balance from the contract only if deadline is reached but the stake is not completed
  */
  function withdraw() external deadlineReached(false) nonReentrant() stakeNotCompleted {
    uint256 userBalance = balances[msg.sender];
    // check if the user has balance to withdraw
    require(userBalance > 0, "You don't have balance to withdraw");
    // reset the balance of the user
    balances[msg.sender] = 0;
    // Transfer balance back to the user
    (bool sent, bytes memory data) = msg.sender.call{value: userBalance}("");
    require(sent, "Failed to send user balance back to the user");

  }

  function timeLeft() public view returns (uint256 timeleft) {
    if( block.timestamp >= deadline ) {
      return 0;
    } else {
      return deadline - block.timestamp;
    }
  }

  

  


}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/CommuneOS.sol";

contract DeploySepoliaScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        // Use address(0) as collateral token for Sepolia (no real token needed)
        // Or deploy a mock ERC20 first
        // Deploy a simple mock token
        MockToken token = new MockToken();
        console.log("MockToken deployed to:", address(token));

        CommuneOS communeOS = new CommuneOS(address(token));

        console.log("CommuneOS deployed to:", address(communeOS));
        console.log("CommuneRegistry:", address(communeOS.communeRegistry()));
        console.log("MemberRegistry:", address(communeOS.memberRegistry()));
        console.log("ChoreScheduler:", address(communeOS.choreScheduler()));
        console.log("TaskManager:", address(communeOS.taskManager()));
        console.log("VotingModule:", address(communeOS.votingModule()));
        console.log("CollateralManager:", address(communeOS.collateralManager()));
        console.log("CommuneViewer: (same as CommuneOS, inherited)");

        vm.stopBroadcast();
    }
}

contract MockToken {
    string public name = "Mock Collateral";
    string public symbol = "MCT";
    uint8 public decimals = 18;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    uint256 public totalSupply;

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        totalSupply += amount;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}

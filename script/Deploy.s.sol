// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/CommuneOS.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        string memory configPath = vm.envString("CONFIG_PATH");

        // Read and parse config file
        string memory json = vm.readFile(configPath);
        address collateralToken = vm.parseJsonAddress(json, ".collateralToken");

        vm.startBroadcast(deployerPrivateKey);

        CommuneOS communeOS = new CommuneOS(collateralToken);

        console.log("CommuneOS deployed to:", address(communeOS));
        console.log("CommuneRegistry:", address(communeOS.communeRegistry()));
        console.log("MemberRegistry:", address(communeOS.memberRegistry()));
        console.log("ChoreScheduler:", address(communeOS.choreScheduler()));
        console.log("ExpenseManager:", address(communeOS.expenseManager()));
        console.log("VotingModule:", address(communeOS.votingModule()));
        console.log("CollateralManager:", address(communeOS.collateralManager()));

        vm.stopBroadcast();
    }
}

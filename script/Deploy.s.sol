// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/CommuneOS.sol";
import "../src/interfaces/ICommuneOS.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        string memory configPath = vm.envString("CONFIG_PATH");

        // Read and parse config file
        string memory json = vm.readFile(configPath);
        address collateralToken = vm.parseJsonAddress(json, ".collateralToken");

        // Parse optional collateral amount (for gnosis)
        uint256 collateralAmount = 0;
        try vm.parseJsonUint(json, ".collateralAmount") returns (uint256 amount) {
            collateralAmount = amount;
        } catch {}

        // Parse chores array if present (for gnosis)
        string memory choresJson = "";
        try vm.parseJson(json, ".chores") returns (bytes memory choresData) {
            choresJson = string(choresData);
        } catch {}

        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy CommuneOS
        CommuneOS communeOS = new CommuneOS(collateralToken);

        console.log("CommuneOS deployed to:", address(communeOS));
        console.log("CommuneRegistry:", address(communeOS.communeRegistry()));
        console.log("MemberRegistry:", address(communeOS.memberRegistry()));
        console.log("ChoreScheduler:", address(communeOS.choreScheduler()));
        console.log("ExpenseManager:", address(communeOS.expenseManager()));
        console.log("VotingModule:", address(communeOS.votingModule()));
        console.log("CollateralManager:", address(communeOS.collateralManager()));

        // Initialize commune if chores are provided
        if (bytes(choresJson).length > 0) {
            // Parse chores from config
            bytes memory choresData = vm.parseJson(json, ".chores");
            uint256 choreCount = vm.parseJson(json, ".chores").length / 96; // Approximate chore count

            ChoreSchedule[] memory choreSchedules = new ChoreSchedule[](choreCount);

            for (uint256 i = 0; i < choreCount; i++) {
                string memory chorePath = string(abi.encodePacked(".chores[", vm.toString(i), "]"));
                string memory title = vm.parseJsonString(json, string(abi.encodePacked(chorePath, ".title")));
                uint256 frequency = vm.parseJsonUint(json, string(abi.encodePacked(chorePath, ".frequency")));

                choreSchedules[i] = ChoreSchedule({
                    id: 0, // Will be set by ChoreScheduler
                    title: title,
                    frequency: frequency,
                    startTime: block.timestamp
                });
            }

            // If collateral required, approve the CollateralManager
            bool collateralRequired = collateralAmount > 0;
            if (collateralRequired) {
                IERC20(collateralToken).approve(address(communeOS.collateralManager()), collateralAmount);
                console.log("Approved collateral:", collateralAmount);
            }

            // Create commune with chores
            uint256 communeId =
                communeOS.createCommune("Singapore House", collateralRequired, collateralAmount, choreSchedules);

            console.log("Commune created with ID:", communeId);
            console.log("Chore schedules added:", choreCount);
            console.log("Collateral required:", collateralRequired);
            if (collateralRequired) {
                console.log("Collateral amount:", collateralAmount);
            }
        }

        vm.stopBroadcast();
    }
}

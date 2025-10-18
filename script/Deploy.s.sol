// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/CommuneOS.sol";
import "../src/CommuneRegistry.sol";
import "../src/MemberRegistry.sol";
import "../src/ChoreScheduler.sol";
import "../src/TaskManager.sol";
import "../src/VotingModule.sol";
import "../src/CollateralManager.sol";
import "../src/interfaces/ICommuneOS.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

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

        vm.startBroadcast(deployerPrivateKey);

        // Deploy ProxyAdmin
        ProxyAdmin proxyAdmin = new ProxyAdmin();
        console.log("ProxyAdmin deployed to:", address(proxyAdmin));

        // Deploy implementation contracts
        CommuneRegistry communeRegistryImpl = new CommuneRegistry();
        MemberRegistry memberRegistryImpl = new MemberRegistry();
        ChoreScheduler choreSchedulerImpl = new ChoreScheduler();
        TaskManager taskManagerImpl = new TaskManager();
        VotingModule votingModuleImpl = new VotingModule();
        CollateralManager collateralManagerImpl = new CollateralManager();
        CommuneOS communeOSImpl = new CommuneOS();

        console.log("Implementation contracts deployed:");
        console.log("  CommuneRegistry:", address(communeRegistryImpl));
        console.log("  MemberRegistry:", address(memberRegistryImpl));
        console.log("  ChoreScheduler:", address(choreSchedulerImpl));
        console.log("  TaskManager:", address(taskManagerImpl));
        console.log("  VotingModule:", address(votingModuleImpl));
        console.log("  CollateralManager:", address(collateralManagerImpl));
        console.log("  CommuneOS:", address(communeOSImpl));

        // Deploy proxies for module contracts
        // Note: We need to initialize these with the CommuneOS proxy address, which we'll deploy next
        // For now, we deploy with empty initialization data and will initialize after CommuneOS proxy is deployed

        TransparentUpgradeableProxy communeRegistryProxy = new TransparentUpgradeableProxy(
            address(communeRegistryImpl),
            address(proxyAdmin),
            ""
        );

        TransparentUpgradeableProxy memberRegistryProxy = new TransparentUpgradeableProxy(
            address(memberRegistryImpl),
            address(proxyAdmin),
            ""
        );

        TransparentUpgradeableProxy choreSchedulerProxy = new TransparentUpgradeableProxy(
            address(choreSchedulerImpl),
            address(proxyAdmin),
            ""
        );

        TransparentUpgradeableProxy taskManagerProxy = new TransparentUpgradeableProxy(
            address(taskManagerImpl),
            address(proxyAdmin),
            ""
        );

        TransparentUpgradeableProxy votingModuleProxy = new TransparentUpgradeableProxy(
            address(votingModuleImpl),
            address(proxyAdmin),
            ""
        );

        TransparentUpgradeableProxy collateralManagerProxy = new TransparentUpgradeableProxy(
            address(collateralManagerImpl),
            address(proxyAdmin),
            ""
        );

        // Deploy CommuneOS proxy and initialize with module proxy addresses
        bytes memory communeOSInitData = abi.encodeWithSelector(
            CommuneOS.initialize.selector,
            address(communeRegistryProxy),
            address(memberRegistryProxy),
            address(choreSchedulerProxy),
            address(taskManagerProxy),
            address(votingModuleProxy),
            address(collateralManagerProxy)
        );

        TransparentUpgradeableProxy communeOSProxy = new TransparentUpgradeableProxy(
            address(communeOSImpl),
            address(proxyAdmin),
            communeOSInitData
        );

        CommuneOS communeOS = CommuneOS(address(communeOSProxy));

        // Now initialize all module contracts with the CommuneOS proxy address
        CommuneRegistry(address(communeRegistryProxy)).initialize(address(communeOSProxy));
        MemberRegistry(address(memberRegistryProxy)).initialize(address(communeOSProxy));
        ChoreScheduler(address(choreSchedulerProxy)).initialize(address(communeOSProxy));
        TaskManager(address(taskManagerProxy)).initialize(address(communeOSProxy));
        VotingModule(address(votingModuleProxy)).initialize(address(communeOSProxy));
        CollateralManager(address(collateralManagerProxy)).initialize(address(communeOSProxy), collateralToken);

        console.log("");
        console.log("Proxy contracts deployed:");
        console.log("  CommuneOS:", address(communeOSProxy));
        console.log("  CommuneRegistry:", address(communeRegistryProxy));
        console.log("  MemberRegistry:", address(memberRegistryProxy));
        console.log("  ChoreScheduler:", address(choreSchedulerProxy));
        console.log("  TaskManager:", address(taskManagerProxy));
        console.log("  VotingModule:", address(votingModuleProxy));
        console.log("  CollateralManager:", address(collateralManagerProxy));

        // Initialize commune if chores are provided
        if (bytes(choresJson).length > 0) {
            // Count chores by trying to parse each index
            uint256 choreCount = 0;
            for (uint256 i = 0; i < 100; i++) {
                try vm.parseJsonString(json, string(abi.encodePacked(".chores[", vm.toString(i), "].title"))) {
                    choreCount++;
                } catch {
                    break;
                }
            }

            ChoreSchedule[] memory choreSchedules = new ChoreSchedule[](choreCount);

            for (uint256 i = 0; i < choreCount; i++) {
                string memory chorePath = string(abi.encodePacked(".chores[", vm.toString(i), "]"));
                string memory title = vm.parseJsonString(json, string(abi.encodePacked(chorePath, ".title")));
                uint256 frequency = vm.parseJsonUint(json, string(abi.encodePacked(chorePath, ".frequency")));

                choreSchedules[i] = ChoreSchedule({
                    id: 0, // Will be set by ChoreScheduler
                    title: title,
                    frequency: frequency,
                    startTime: block.timestamp,
                    deleted: false
                });
            }

            // If collateral required, approve the CollateralManager
            bool collateralRequired = collateralAmount > 0;
            if (collateralRequired) {
                IERC20(collateralToken).approve(address(communeOS.collateralManager()), collateralAmount);
                console.log("Approved collateral:", collateralAmount);
            }

            // Create commune with chores
            uint256 communeId = communeOS.createCommune(
                "Hackatsuon House", collateralRequired, collateralAmount, choreSchedules, "creator"
            );

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

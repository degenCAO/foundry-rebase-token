pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {Client} from "@ccip/contracts/src/v0.8/ccip/libraries/Client.sol";
import {IRouterClient} from "@ccip/contracts/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {IERC20} from "@OpenZeppelin/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract BridgeScript is Script {
    function run(
        uint64 destinationChainSelector,
        address receiverAddress,
        address routerAddress,
        address tokenAddress,
        uint256 tokenAmountToBridge,
        address linkTokenAddress
    ) public {
        vm.startBroadcast();
        //     EVMTokenAmount {
        // address token; // token address on the local chain.
        // uint256 amount;
        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({token: tokenAddress, amount: tokenAmountToBridge});
        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(receiverAddress),
            data: "",
            tokenAmounts: tokenAmounts,
            feeToken: linkTokenAddress,
            extraArgs: Client._argsToBytes(Client.EVMExtraArgsV1({gasLimit: 0}))
        });
        uint256 ccipFees = IRouterClient(routerAddress).getFee(destinationChainSelector, message);
        IERC20(linkTokenAddress).approve(routerAddress, ccipFees);
        IERC20(tokenAddress).approve(routerAddress, tokenAmountToBridge);
        IRouterClient(routerAddress).ccipSend(destinationChainSelector, message);

        //      bytes receiver; // abi.encode(receiver address) for dest EVM chains
        // bytes data; // Data payload
        // EVMTokenAmount[] tokenAmounts; // Token transfers
        // address feeToken; // Address of feeToken. address(0) means you will send msg.value.
        // bytes extraArgs; // Populate this with _argsToBytes(EVMExtraArgsV2)

        vm.stopBroadcast();
    }
}

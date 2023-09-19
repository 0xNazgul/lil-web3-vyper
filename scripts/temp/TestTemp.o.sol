// SPDX-License-Identifier: NONE
pragma solidity >=0.8.0;

import {Test} from "forge-std/Test.sol";
import {VyperDeployer} from "snekmate/lib/utils/VyperDeployer.sol";

import {ITemp} from "./interfaces/ITemp.sol";

contract TempTest is Test {
    VyperDeployer public vyperDeployer = new VyperDeployer();

    ITemp public temp;

    address public deployer = address(vyperDeployer);
    address public zeroAddress = address(0);

    receive() external payable {}
    fallback() external payable {}

    function setUp() public {
        bytes memory args = abi.encode(TODO);

        temp = ITemp(vyperDeployer.deployContract("src/", "TempFile", args));
        vm.label(address(temp), "LIL TEMP");
        vm.label(address(deployer), "DEPLOYER");
        vm.label(address(this), "USER");
    }
}
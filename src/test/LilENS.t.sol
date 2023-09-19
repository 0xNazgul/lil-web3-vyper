// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

import {Test} from "forge-std/Test.sol";
import {VyperDeployer} from "snekmate/lib/utils/VyperDeployer.sol";

import {ILilENS} from "./interfaces/ILilENS.sol";

contract LilENSTest is Test {
    VyperDeployer vyperDeployer = new VyperDeployer();

    ILilENS public lilens;

    address public deployer = address(vyperDeployer);
    address public zeroAddress = address(0);

    event NewNameFee(uint256 indexed oldFee, uint256 indexed newFee);
    event NewOwner(address indexed oldOwner, address indexed newOwner);
    event NewUpdateFee(uint256 indexed oldFee, uint256 indexed newFee);
    event Register(uint256 amount, uint256 amount_fee, string name, address indexed sender);
    event Update(uint256 amount, uint256 amount_fee, string name, address indexed newAddress, address indexed sender);
    event WithdrawFees(uint256 indexed amount);

    receive() external payable {}
    fallback() external payable {}

    function setUp() public {
        bytes memory args = abi.encode(100, 100);

        lilens = ILilENS(vyperDeployer.deployContract("src/", "LilENS", args));
        vm.label(address(lilens), "LIL LILENS");
        vm.label(address(deployer), "DEPLOYER");
        vm.label(address(this), "USER");
    }

    function testInitialSetup() public {
        assertEq(lilens.nameFee(), 100);
        assertEq(lilens.updateFee(), 100);
        assertEq(lilens.owner(), deployer);
    }

    function testRegister(string calldata name) public {
        vm.deal(address(this), 2000);
        uint256 cost = getLength(name) * lilens.nameFee();
        vm.expectEmit(true, true, false, false);
        emit Register(1000, cost, "YO", address(this));
        lilens.register{value: 1000}("YO");
        assertEq(lilens.lookup("YO"), address(this));
        assertEq(address(lilens).balance, 200);
        assertEq(address(this).balance, 2000 - 200);

        vm.expectRevert("Already Registered");
        lilens.register{value: 1000}("YO");

        vm.expectRevert("Not enough for fee");
        lilens.register{value: 1}("YOO");

        vm.prank(deployer);
        lilens.withdrawFees();

        vm.startPrank(address(0x1234));
        uint256 fuzzCost = getLength(name) * lilens.nameFee() + 1;
        vm.deal(address(0x1234), fuzzCost);

        try lilens.register{value: fuzzCost}(name) {
            assertEq(lilens.lookup(name), address(0x1234));
            assertEq(address(lilens).balance, fuzzCost - 1);
            assertEq(address(0x1234).balance - 1, 0);
        } catch { /*Already Registered*/ }
        vm.stopPrank();
    }

    function testUpdate(uint256 amount, string calldata name) public {
        vm.deal(address(this), 3000);
        lilens.register{value: 1000}("YO");

        uint256 cost = getLength("YO") * lilens.updateFee();
        vm.expectEmit(true, true, false, false);
        emit Update(1000, cost, "YO", deployer, address(this));
        lilens.update{value: 1000}("YO", deployer);
        assertEq(lilens.lookup("YO"), deployer);

        vm.expectRevert("Not your name");
        lilens.update{value: 1000}("YO", address(this));

        vm.expectRevert("Not enough for fee");
        lilens.update{value: 1}("YOO", address(this));

        vm.prank(deployer);
        lilens.withdrawFees();

        vm.startPrank(address(0x1234));
        uint256 fuzzCost = getLength(name) * lilens.nameFee() + 1;
        vm.deal(address(0x1234), fuzzCost);

        try lilens.register{value: amount}(name) {
            try lilens.update{value: amount}(name, address(this)) {
                assertEq(lilens.lookup(name), address(this));
                assertEq(address(lilens).balance, fuzzCost - 1);
                assertEq(address(0x1234).balance - 1, amount - fuzzCost);
            } catch { /*evm reverts*/ }
        } catch { /*Already Registered*/ }
        vm.stopPrank();
    }

    function testNewOwner(address newOwner) public {
        vm.startPrank(deployer);
        vm.expectEmit(true, true, false, false);
        emit NewOwner(address(deployer), address(this));
        lilens.newOwner(address(this));

        vm.expectRevert(bytes("Unauthorized"));
        lilens.newOwner(address(this));
        vm.stopPrank();

        vm.expectRevert(bytes("Zero address not allowed"));
        lilens.newOwner(zeroAddress);

        vm.assume(newOwner != zeroAddress);
        lilens.newOwner(newOwner);
        assertEq(lilens.owner(), newOwner);
    }

    function testNewNameFee(uint256 newFee) public {
        vm.startPrank(deployer);
        vm.expectEmit(true, true, false, false);
        emit NewNameFee(100, 10);
        lilens.newNameFee(10);

        vm.expectRevert(bytes("Fee too high"));
        lilens.newNameFee(10e18);
        vm.stopPrank();

        vm.expectRevert(bytes("Unauthorized"));
        lilens.newNameFee(10);

        newFee = bound(newFee, 0, 1e18);

        vm.startPrank(deployer);
        lilens.newNameFee(newFee);
        assertEq(lilens.nameFee(), newFee);
        vm.stopPrank();
    }

    function testNewUpdateFee(uint256 newFee) public {
        vm.startPrank(deployer);
        vm.expectEmit(true, true, false, false);
        emit NewUpdateFee(100, 10);
        lilens.newUpdateFee(10);

        vm.expectRevert(bytes("Fee too high"));
        lilens.newUpdateFee(10e18);
        vm.stopPrank();

        vm.expectRevert(bytes("Unauthorized"));
        lilens.newUpdateFee(10);

        newFee = bound(newFee, 0, 1e18);

        vm.startPrank(deployer);
        lilens.newUpdateFee(newFee);
        assertEq(lilens.updateFee(), newFee);
        vm.stopPrank();
    }

    function testWithdrawFees(uint256 amount) public {
        vm.deal(address(lilens), 1 ether);

        vm.startPrank(deployer);
        vm.expectEmit(true, true, false, false);
        emit WithdrawFees(1 ether);
        lilens.withdrawFees();
        assertEq(deployer.balance, 1 ether);
        vm.stopPrank();

        vm.expectRevert(bytes("Unauthorized"));
        lilens.withdrawFees();

        amount = bound(amount, 1 ether, 100 ether);
        vm.deal(address(lilens), amount);

        vm.startPrank(deployer);
        lilens.withdrawFees();
        assertEq(deployer.balance, amount + 1 ether);
        vm.stopPrank();
    }

    //helper to get length of string to calculate cost of the name
    function getLength(string memory s) public pure returns (uint256 len) {
        uint256 i = 0;
        uint256 bytelength = bytes(s).length;
        for (len = 0; i < bytelength; len++) {
            bytes1 b = bytes(s)[i];
            // b = e2 for first iteration
            if (b < 0x80) {
                i += 1;
            } else if (b < 0xE0) {
                i += 2;
            } else if (b < 0xF0) {
                i += 3;
            } else if (b < 0xF8) {
                i += 4;
            } else if (b < 0xFC) {
                i += 5;
            } else {
                i += 6;
            }
        }
    }
}

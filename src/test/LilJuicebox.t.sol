// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

import {Test} from "forge-std/Test.sol";
import {VyperDeployer} from "snekmate/lib/utils/VyperDeployer.sol";

import {ILilJuicebox} from "./interfaces/ILilJuicebox.sol";
import {IProjectShare} from "./interfaces/IProjectShare.sol";

contract LilJuiceboxTest is Test {
    VyperDeployer public vyperDeployer = new VyperDeployer();

    ILilJuicebox public liljuicebox;
    IProjectShare public projetshare;

    address public deployer = address(vyperDeployer);
    address public zeroAddress = address(0);

    event Contributed(address indexed contributor, uint256 amount);
    event Refunded(address indexed contributor, uint256 amount);
    event Renounced(address sender);
    event StateUpdated(uint256 state);
    event Withdrawn(uint256 amount);

    receive() external payable {}
    fallback() external payable {}

    function setUp() public {
        bytes memory projectArgs = abi.encode("name", "nam", 18);

        IProjectShare projetshareMaster =
            IProjectShare(vyperDeployer.deployContract("src/", "ProjectShare", projectArgs));

        bytes memory args = abi.encode("NAME", "NAM", address(projetshareMaster));

        liljuicebox = ILilJuicebox(vyperDeployer.deployContract("src/", "LilJuicebox", args));
        projetshare = IProjectShare(liljuicebox.token());

        vm.label(address(liljuicebox), "LIL LILJUICEBOX");
        vm.label(address(deployer), "DEPLOYER");
        vm.label(address(this), "USER");
    }

    function testInitialSetup() public {
        assertEq(liljuicebox.manager(), deployer);
        assertEq(liljuicebox.getState(), 2);
        assertEq(projetshare.name(), "NAME");
        assertEq(projetshare.symbol(), "NAM");
        assertEq(projetshare.decimals(), 18);
    }

    function testCanContribute() public {
        uint256 startingBalance = address(this).balance;
        assertEq(projetshare.balanceOf(address(this)), 0);

        vm.expectEmit(true, false, false, true);
        emit Contributed(address(this), 1 ether);

        liljuicebox.contribute{value: 1 ether}();

        assertEq(address(liljuicebox).balance, 1 ether);
        assertEq(projetshare.balanceOf(address(this)), 1_000_000 ether);
        assertEq(address(this).balance, startingBalance - 1 ether);
    }

    function testCannotContributeWhenRoundIsClosed() public {
        uint256 startingBalance = address(this).balance;
        assertEq(projetshare.balanceOf(address(this)), 0);

        vm.prank(deployer);
        liljuicebox.setState(0);

        vm.expectRevert("Contributions closed");
        liljuicebox.contribute{value: 1 ether}();

        assertEq(address(liljuicebox).balance, 0);
        assertEq(projetshare.balanceOf(address(this)), 0);
        assertEq(address(this).balance, startingBalance);
    }

    function testRefund() public {
        liljuicebox.contribute{value: 10 ether}();

        uint256 startingBalance = address(this).balance;
        assertEq(projetshare.balanceOf(address(this)), 10_000_000 ether);

        vm.prank(deployer);
        liljuicebox.setState(4);

        vm.expectEmit(true, false, false, true);
        emit Refunded(address(this), 10 ether);

        liljuicebox.refund(10_000_000 ether);

        assertEq(address(liljuicebox).balance, 0);
        assertEq(projetshare.balanceOf(address(this)), 0);
        assertEq(address(this).balance, startingBalance + 10 ether);
    }

    function testCannotRefundsIfRefundsAreNotAvailable() public {
        liljuicebox.contribute{value: 10 ether}();

        uint256 startingBalance = address(this).balance;
        assertEq(projetshare.balanceOf(address(this)), 10_000_000 ether);

        vm.expectRevert("Refunds closed");

        liljuicebox.refund(10_000_000 ether);

        assertEq(address(liljuicebox).balance, 10 ether);
        assertEq(projetshare.balanceOf(address(this)), 10_000_000 ether);
        assertEq(address(this).balance, startingBalance);
    }

    function testCannotRefundsIfNotEnoughTokens() public {
        vm.deal(deployer, 10 ether);
        vm.deal(address(this), 0 ether);
        vm.startPrank(deployer);
        liljuicebox.contribute{value: 10 ether}();
        liljuicebox.setState(4);
        vm.stopPrank();

        assertEq(projetshare.balanceOf(address(this)), 0);

        vm.expectRevert("ERC20: burn amount exceeds balance");
        liljuicebox.refund(10_000_000 ether);

        assertEq(address(liljuicebox).balance, 10 ether);
        assertEq(projetshare.balanceOf(address(this)), 0);
        assertEq(address(this).balance, 0);
    }

    function testManagerCanWithdrawFunds() public {
        vm.deal(address(liljuicebox), 10 ether);

        uint256 initialBalance = address(deployer).balance;

        vm.prank(deployer);
        vm.expectEmit(false, false, false, true);
        emit Withdrawn(10 ether);
        liljuicebox.withdraw();

        assertEq(address(deployer).balance, initialBalance + 10 ether);
    }

    function testNonManagerCannotWithdrawFunds() public {
        vm.deal(address(liljuicebox), 10 ether);

        uint256 initialBalance = address(this).balance;

        vm.expectRevert("Unauthorized");
        liljuicebox.withdraw();

        assertEq(address(this).balance, initialBalance);
    }

    function testManagerCanSetState() public {
        assertEq(uint256(liljuicebox.getState()), 2);

        vm.prank(deployer);
        vm.expectEmit(false, false, false, true);
        emit StateUpdated(1);
        liljuicebox.setState(1);

        assertEq(uint256(liljuicebox.getState()), 1);
    }

    function testNonManagerCannotSetState() public {
        assertEq(uint256(liljuicebox.getState()), 2);

        vm.prank(address(this));
        vm.expectRevert("Unauthorized");
        liljuicebox.setState(1);

        assertEq(uint256(liljuicebox.getState()), 2);
    }

    function testManagerCanRenounceOwnership() public {
        assertEq(liljuicebox.manager(), deployer);

        vm.prank(deployer);
        vm.expectEmit(false, false, false, true);
        emit Renounced(deployer);
        liljuicebox.renounce();

        assertEq(liljuicebox.manager(), address(0));
    }

    function testNonManagerCannotRenounceOwnership() public {
        assertEq(liljuicebox.manager(), deployer);

        vm.expectRevert("Unauthorized");
        liljuicebox.renounce();

        assertEq(liljuicebox.manager(), address(deployer));
    }
}

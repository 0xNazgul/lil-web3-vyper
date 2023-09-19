// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

import {Test} from "forge-std/Test.sol";
import {VyperDeployer} from "snekmate/lib/utils/VyperDeployer.sol";
import {ERC20} from "openzeppelin/token/ERC20/ERC20.sol";

import {ILilFlashloan} from "./interfaces/ILilFlashloan.sol";

interface IFlashBorrower {
    function onFlashLoan(ERC20 token, uint256 amount, bytes32 data) external;
}

contract TestToken is ERC20("Test Token", "TEST") {
    function mintTo(address to, uint256 amount) public payable {
        _mint(to, amount);
    }
}

contract TestReceiver is IFlashBorrower, Test {
    bytes32 public testData;
    bool public shouldRepay = true;
    bool public shouldPayFees = true;

    function setTestData(bytes calldata data) public payable {
        testData = bytes32(data);
    }

    function setRepay(bool _shouldRepay) public payable {
        shouldRepay = _shouldRepay;
    }

    function setRespectFees(bool _shouldPayFees) public payable {
        shouldPayFees = _shouldPayFees;
    }

    function onFlashLoan(ERC20 token, uint256 amount, bytes32 data) external {
        assertEq(testData, bytes32(data));

        if (!shouldRepay) return;

        token.transfer(msg.sender, amount);

        if (!shouldPayFees) return;

        uint256 owedFees = ILilFlashloan(msg.sender).getFees(address(token), amount);
        TestToken(address(token)).mintTo(msg.sender, owedFees);
    }
}

contract LilFlashloanTest is Test {
    VyperDeployer public vyperDeployer = new VyperDeployer();

    ILilFlashloan public lilflashloan;

    TestToken public token;
    TestReceiver public receiver;
    address public deployer = address(vyperDeployer);
    address public zeroAddress = address(0);

    event FeeUpdated(ERC20 indexed token, uint256 fee);
    event Withdrawn(ERC20 indexed token, uint256 amount);
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Flashloaned(IFlashBorrower indexed receiver, ERC20 indexed token, uint256 amount);

    receive() external payable {}
    fallback() external payable {}

    function setUp() public {
        token = new TestToken();
        receiver = new TestReceiver();
        lilflashloan = ILilFlashloan(vyperDeployer.deployContract("src/", "LilFlashloan"));
        vm.label(address(lilflashloan), "LIL LILFLASHLOAN");
        vm.label(address(receiver), "TEST RECEIVER");
        vm.label(address(token), "TEST TOKEN");
        vm.label(address(deployer), "DEPLOYER");
        vm.label(address(this), "USER");
    }

    function testInitialSetup() public {
        assertEq(lilflashloan.manager(), deployer);
    }

    function testCanFlashloan() public {
        token.mintTo(address(lilflashloan), 100 ether);

        vm.expectEmit(true, true, false, true);
        emit Flashloaned(receiver, token, 100 ether);
        vm.expectEmit(true, true, false, true);
        emit Transfer(address(lilflashloan), address(receiver), 100 ether);
        vm.expectEmit(true, true, false, true);
        emit Transfer(address(receiver), address(lilflashloan), 100 ether);

        lilflashloan.execute(address(receiver), address(token), 100 ether, "");

        assertEq(token.balanceOf(address(lilflashloan)), 100 ether);
    }

    function testDataIsForwarded() public {
        receiver.setTestData("forwarded data");
        token.mintTo(address(lilflashloan), 100 ether);

        lilflashloan.execute(address(receiver), address(token), 100 ether, "forwarded data");
    }

    function testCanFlashloanWithFees() public {
        token.mintTo(address(lilflashloan), 100 ether);

        vm.prank(address(deployer));
        lilflashloan.setFees(address(token), 10_00);

        lilflashloan.execute(address(receiver), address(token), 100 ether, "");

        assertEq(token.balanceOf(address(lilflashloan)), 110 ether);
    }

    function testCannotFlasloanIfNotEnoughBalance() public {
        token.mintTo(address(lilflashloan), 1 ether);

        vm.expectRevert("ERC20: transfer amount exceeds balance");
        lilflashloan.execute(address(receiver), address(token), 2 ether, "");

        assertEq(token.balanceOf(address(lilflashloan)), 1 ether);
    }

    function testFlashloanRevertsIfNotRepaid() public {
        receiver.setRepay(false);
        lilflashloan.getFees(address(token), 100 ether);

        token.mintTo(address(lilflashloan), 100 ether);

        vm.expectRevert("Tokens not returned");
        lilflashloan.execute(address(receiver), address(token), 100 ether, "");

        assertEq(token.balanceOf(address(lilflashloan)), 100 ether);
    }

    function testFlashloanRevertsIfNotFeesNotPaid() public {
        receiver.setRespectFees(false);

        vm.prank(address(deployer));
        lilflashloan.setFees(address(token), 10_00);

        token.mintTo(address(lilflashloan), 100 ether);

        vm.expectRevert("Tokens not returned");
        lilflashloan.execute(address(receiver), address(token), 100 ether, "");

        assertEq(token.balanceOf(address(lilflashloan)), 100 ether);
    }

    function testManagerCanSetFees() public {
        assertEq(lilflashloan.fees(address(token)), 0);

        vm.prank(address(deployer));
        vm.expectEmit(true, false, false, true);
        emit FeeUpdated(token, 10_00);
        lilflashloan.setFees(address(token), 10_00);

        assertEq(lilflashloan.fees(address(token)), 10_00);
    }

    function testCannotSetFeesHigherThan100Percent() public {
        assertEq(lilflashloan.fees(address(token)), 0);

        vm.prank(address(deployer));
        vm.expectRevert("Invalid percentage");
        lilflashloan.setFees(address(token), 101_00);

        assertEq(lilflashloan.fees(address(token)), 0);
    }

    function testNonManagerCannotSetFees() public {
        assertEq(lilflashloan.fees(address(token)), 0);

        vm.prank(address(this));
        vm.expectRevert("Unauthorized");
        lilflashloan.setFees(address(token), 10_00);

        assertEq(lilflashloan.fees(address(token)), 0);
    }

    function testManagerCanWithdrawTokens() public {
        token.mintTo(address(lilflashloan), 10 ether);
        assertEq(token.balanceOf(address(this)), 0);

        vm.prank(address(deployer));
        vm.expectEmit(true, false, false, true);
        emit Withdrawn(token, 10 ether);
        lilflashloan.withdraw(address(token), 10 ether);

        assertEq(token.balanceOf(address(deployer)), 10 ether);
        assertEq(token.balanceOf(address(lilflashloan)), 0);
    }

    function testNonManagerCannotWithdrawTokens() public {
        token.mintTo(address(lilflashloan), 10 ether);
        assertEq(token.balanceOf(address(this)), 0);

        vm.prank(address(this));
        vm.expectRevert("Unauthorized");
        lilflashloan.withdraw(address(token), 10 ether);

        assertEq(token.balanceOf(address(this)), 0);
        assertEq(token.balanceOf(address(lilflashloan)), 10 ether);
    }
}

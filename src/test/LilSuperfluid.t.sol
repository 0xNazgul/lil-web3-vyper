// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

import {Test} from "forge-std/Test.sol";
import {VyperDeployer} from "snekmate/lib/utils/VyperDeployer.sol";
import {ERC20} from "openzeppelin/token/ERC20/ERC20.sol";

import {ILilSuperfluid} from "./interfaces/ILilSuperfluid.sol";

struct Stream {
    address sender;
    address recipient;
    address token;
    uint256 balance_;
    uint256 withdrawn_balance;
    uint256 payment_per_block;
    Timeframe timeframe;
}

struct Timeframe {
    uint256 start_block;
    uint256 stop_block;
}

contract TestToken is ERC20("Test Token", "TKN") {
    function mintTo(address recipient, uint256 amount) public payable {
        _mint(recipient, amount);
    }
}

contract User {}

contract LilSuperfluidTest is Test {
    VyperDeployer public vyperDeployer = new VyperDeployer();

    uint256 internal privKey;
    User internal user;
    TestToken internal testToken;
    ILilSuperfluid public lilsuperfluid;

    address public deployer = address(vyperDeployer);
    address public zeroAddress = address(0);

    event StreamCreated(ILilSuperfluid.Stream stream);
    event StreamRefueled(uint256 indexed stream_id, uint256 amount);
    event FundsWithdrawn(uint256 indexed stream_id, uint256 amount);
    event ExcessWithdrawn(uint256 indexed stream_id, uint256 amount);
    event StreamDetailsUpdated(
        uint256 indexed stream_id, uint256 payment_per_block, ILilSuperfluid.Timeframe timeframe
    );

    receive() external payable {}
    fallback() external payable {}

    function setUp() public {
        privKey = 0xa;
        testToken = new TestToken();
        user = new User();
        user = User(vm.addr(privKey));
        bytes memory args = abi.encode("Test", "V1");

        lilsuperfluid = ILilSuperfluid(vyperDeployer.deployContract("src/", "LilSuperfluid", args));

        testToken.mintTo(address(this), 1 ether);
        testToken.approve(address(lilsuperfluid), type(uint256).max);

        vm.label(address(lilsuperfluid), "LIL LILSUPERFLUID");
        vm.label(address(deployer), "DEPLOYER");
        vm.label(address(this), "US");
        vm.label(address(user), "USER");
    }

    function testInitialSetup() public {
        assertEq(
            lilsuperfluid._UPDATE_DETAILS_HASH(),
            keccak256(
                "UpdateStreamDetails(uint256 streamId,uint256 paymentPerBlock,uint256 startBlock,uint256 stopBlock,uint256 nonce)"
            ),
            "fdsfdasf"
        );
        assertEq(
            lilsuperfluid._TYPE_HASH(),
            keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)")
        );
        assertEq(lilsuperfluid._CACHED_SELF(), address(lilsuperfluid));
        assertEq(lilsuperfluid._NAME(), "Test");
        assertEq(lilsuperfluid._HASHED_NAME(), keccak256("Test"));
        assertEq(lilsuperfluid._HASHED_VERSION(), keccak256("V1"));
        assertEq(lilsuperfluid._VERSION(), "V1");
        assertEq(
            lilsuperfluid._CACHED_DOMAIN_SEPARATOR(),
            keccak256(
                abi.encode(
                    lilsuperfluid._TYPE_HASH(),
                    lilsuperfluid._HASHED_NAME(),
                    lilsuperfluid._HASHED_VERSION(),
                    block.chainid,
                    address(lilsuperfluid)
                )
            )
        );
        assertEq(lilsuperfluid.nonce(), 1);
        assertEq(lilsuperfluid.stream_id(), 1);
    }

    function testCanCreateStream() public {
        assertEq(testToken.balanceOf(address(this)), 1 ether);
        assertEq(testToken.balanceOf(address(lilsuperfluid)), 0);

        ILilSuperfluid.Timeframe memory timeframe =
            ILilSuperfluid.Timeframe({start_block: block.number, stop_block: block.number + 10});

        vm.expectEmit(false, false, false, true);
        emit StreamCreated(
            ILilSuperfluid.Stream({
                sender: address(this),
                recipient: address(user),
                token: address(testToken),
                balance_: 1 ether,
                withdrawn_balance: 0,
                payment_per_block: 0.1 ether,
                timeframe: timeframe
            })
        );

        uint256 streamId = lilsuperfluid.streamTo(address(user), address(testToken), 1 ether, timeframe, 0.1 ether);

        assertEq(streamId, 1);
        assertEq(testToken.balanceOf(address(this)), 0);
        assertEq(testToken.balanceOf(address(lilsuperfluid)), 1 ether);
        (
            address sender,
            address recipient,
            address streamToken,
            uint256 balance,
            uint256 withdrawnBalance,
            uint256 paymentPerBlock,
            ILilSuperfluid.Timeframe memory streamTimeframe
        ) = lilsuperfluid.getStream(streamId);

        assertEq(sender, address(this));
        assertEq(recipient, address(user));
        assertEq(address(streamToken), address(testToken));
        assertEq(balance, 1 ether);
        assertEq(withdrawnBalance, 0);
        assertEq(paymentPerBlock, 0.1 ether);
        assertEq(streamTimeframe.start_block, timeframe.start_block);
        assertEq(streamTimeframe.stop_block, timeframe.stop_block);
    }

    function testCanRefuelStream() public {
        uint256 streamId = lilsuperfluid.streamTo(
            address(user),
            address(testToken),
            0.05 ether,
            ILilSuperfluid.Timeframe({start_block: block.number, stop_block: block.number + 10}),
            0.1 ether
        );

        (,,, uint256 initialBalance,,,) = lilsuperfluid.getStream(streamId);

        assertEq(initialBalance, 0.05 ether);

        vm.expectEmit(true, false, false, true);
        emit StreamRefueled(streamId, 0.05 ether);
        lilsuperfluid.refuel(streamId, 0.05 ether);

        (,,, uint256 newBalance,,,) = lilsuperfluid.getStream(streamId);

        assertEq(newBalance, 0.1 ether);
    }

    function testNonSenderCannotRefuelStream() public {
        uint256 streamId = lilsuperfluid.streamTo(
            address(user),
            address(testToken),
            0.05 ether,
            ILilSuperfluid.Timeframe({start_block: block.number, stop_block: block.number + 10}),
            0.1 ether
        );

        (,,, uint256 initialBalance,,,) = lilsuperfluid.getStream(streamId);

        assertEq(initialBalance, 0.05 ether);

        vm.prank(address(user));
        vm.expectRevert("Unauthorized");
        lilsuperfluid.refuel(streamId, 0.05 ether);

        (,,, uint256 newBalance,,,) = lilsuperfluid.getStream(streamId);

        assertEq(newBalance, 0.05 ether);
    }

    function testCannotRefuelANonExistantStream() public {
        vm.expectRevert();
        lilsuperfluid.refuel(10, 0 ether);
    }

    function testBalanceCalculationAndWithdrawals() public {
        uint256 streamId = lilsuperfluid.streamTo(
            address(user),
            address(testToken),
            1 ether,
            ILilSuperfluid.Timeframe({start_block: block.number, stop_block: block.number + 10}),
            0.1 ether
        );

        assertEq(testToken.balanceOf(address(lilsuperfluid)), 1 ether);
        assertEq(lilsuperfluid.getBalanceOf(streamId, address(user)), 0);
        assertEq(lilsuperfluid.getBalanceOf(streamId, address(this)), 1 ether);

        vm.roll(block.number + 1);

        assertEq(lilsuperfluid.getBalanceOf(streamId, address(this)), 0.9 ether);
        assertEq(lilsuperfluid.getBalanceOf(streamId, address(user)), 0.1 ether);

        vm.roll(block.number + 4);

        assertEq(lilsuperfluid.getBalanceOf(streamId, address(this)), 0.5 ether);
        assertEq(lilsuperfluid.getBalanceOf(streamId, address(user)), 0.5 ether);

        vm.prank(address(user));
        vm.expectEmit(true, false, false, true);
        emit FundsWithdrawn(streamId, 0.5 ether);
        lilsuperfluid.withdraw(streamId);

        assertEq(testToken.balanceOf(address(user)), 0.5 ether);
        assertEq(testToken.balanceOf(address(lilsuperfluid)), 0.5 ether);
        assertEq(lilsuperfluid.getBalanceOf(streamId, address(this)), 0.5 ether);
        assertEq(lilsuperfluid.getBalanceOf(streamId, address(user)), 0 ether);

        vm.roll(block.number + 4);

        assertEq(lilsuperfluid.getBalanceOf(streamId, address(this)), 0.1 ether);
        assertEq(lilsuperfluid.getBalanceOf(streamId, address(user)), 0.4 ether);

        vm.roll(block.number + 1);

        assertEq(lilsuperfluid.getBalanceOf(streamId, address(this)), 0 ether);
        assertEq(lilsuperfluid.getBalanceOf(streamId, address(user)), 0.5 ether);

        vm.prank(address(user));
        vm.expectEmit(true, false, false, true);
        emit FundsWithdrawn(streamId, 0.5 ether);
        lilsuperfluid.withdraw(streamId);

        assertEq(testToken.balanceOf(address(lilsuperfluid)), 0 ether);
        assertEq(testToken.balanceOf(address(user)), 1 ether);
    }

    function testNonRecipiantCannotWithdraw() public {
        uint256 streamId = lilsuperfluid.streamTo(
            address(user),
            address(testToken),
            1 ether,
            ILilSuperfluid.Timeframe({start_block: block.number, stop_block: block.number + 10}),
            0.1 ether
        );

        assertEq(testToken.balanceOf(address(lilsuperfluid)), 1 ether);
        assertEq(lilsuperfluid.getBalanceOf(streamId, address(user)), 0);
        assertEq(lilsuperfluid.getBalanceOf(streamId, address(this)), 1 ether);

        vm.expectRevert("Unauthorized");
        lilsuperfluid.withdraw(streamId);

        assertEq(testToken.balanceOf(address(lilsuperfluid)), 1 ether);
        assertEq(lilsuperfluid.getBalanceOf(streamId, address(user)), 0);
        assertEq(lilsuperfluid.getBalanceOf(streamId, address(this)), 1 ether);
    }

    function testSenderCanWithdrawExcess() public {
        testToken.mintTo(address(this), 2 ether);

        uint256 streamId = lilsuperfluid.streamTo(
            address(user),
            address(testToken),
            2 ether,
            ILilSuperfluid.Timeframe({start_block: block.number, stop_block: block.number + 10}),
            0.1 ether
        );

        vm.roll(block.number + 5);

        vm.expectRevert("Stream Still Active");
        lilsuperfluid.refund(streamId);

        vm.roll(block.number + 6);

        assertEq(testToken.balanceOf(address(lilsuperfluid)), 2 ether);
        assertEq(lilsuperfluid.getBalanceOf(streamId, address(user)), 1 ether);
        assertEq(lilsuperfluid.getBalanceOf(streamId, address(this)), 1 ether);

        vm.prank(address(user));
        lilsuperfluid.withdraw(streamId);

        assertEq(testToken.balanceOf(address(lilsuperfluid)), 1 ether);
        assertEq(lilsuperfluid.getBalanceOf(streamId, address(user)), 0 ether);
        assertEq(lilsuperfluid.getBalanceOf(streamId, address(this)), 1 ether);

        vm.expectEmit(true, false, false, true);
        emit ExcessWithdrawn(streamId, 1 ether);
        lilsuperfluid.refund(streamId);

        assertEq(testToken.balanceOf(address(lilsuperfluid)), 0 ether);
        assertEq(lilsuperfluid.getBalanceOf(streamId, address(user)), 0 ether);
        assertEq(lilsuperfluid.getBalanceOf(streamId, address(this)), 0 ether);
    }

    function testNonSenderCannotWithdrawExcess() public {
        testToken.mintTo(address(this), 2 ether);

        uint256 streamId = lilsuperfluid.streamTo(
            address(user),
            address(testToken),
            2 ether,
            ILilSuperfluid.Timeframe({start_block: block.number, stop_block: block.number + 10}),
            0.1 ether
        );

        vm.roll(block.number + 10);

        vm.prank(address(user));
        vm.expectRevert("Unauthorized");
        lilsuperfluid.refund(streamId);
    }

    function testCanUpdateStreamDetails() public {
        uint256 streamId = lilsuperfluid.streamTo(
            address(user),
            address(testToken),
            1 ether,
            ILilSuperfluid.Timeframe({start_block: block.number, stop_block: block.number + 10}),
            0.1 ether
        );

        (,,,,, uint256 initPaymentRate, ILilSuperfluid.Timeframe memory initTimeframe) =
            lilsuperfluid.getStream(streamId);

        assertEq(initPaymentRate, 0.1 ether);
        assertEq(initTimeframe.start_block, block.number);
        assertEq(initTimeframe.stop_block, block.number + 10);

        ILilSuperfluid.Timeframe memory timeframe =
            ILilSuperfluid.Timeframe({start_block: block.number + 5, stop_block: block.number + 10});

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            privKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    lilsuperfluid._CACHED_DOMAIN_SEPARATOR(),
                    lilsuperfluid.buildUpdateStructHash(streamId, 0.5 ether, timeframe)
                )
            )
        );

        ILilSuperfluid.Signature memory sig = ILilSuperfluid.Signature({v: v, r: r, s: s});

        vm.expectEmit(true, false, false, true);
        emit StreamDetailsUpdated(streamId, 0.5 ether, timeframe);
        lilsuperfluid.updateDetails(streamId, 0.5 ether, timeframe, sig);

        (,,,,, uint256 newPaymentRate, ILilSuperfluid.Timeframe memory newTimeframe) = lilsuperfluid.getStream(streamId);

        assertEq(newPaymentRate, 0.5 ether);
        assertEq(newTimeframe.start_block, timeframe.start_block);
        assertEq(newTimeframe.stop_block, timeframe.stop_block);
    }

    function testCantUpdateStreamDetailsWithInvalidSignature() public {
        uint256 streamId = lilsuperfluid.streamTo(
            address(user),
            address(testToken),
            1 ether,
            ILilSuperfluid.Timeframe({start_block: block.number, stop_block: block.number + 10}),
            0.1 ether
        );

        (,,,,, uint256 initPaymentRate, ILilSuperfluid.Timeframe memory initTimeframe) =
            lilsuperfluid.getStream(streamId);

        assertEq(initPaymentRate, 0.1 ether);
        assertEq(initTimeframe.start_block, block.number);
        assertEq(initTimeframe.stop_block, block.number + 10);

        ILilSuperfluid.Timeframe memory timeframe =
            ILilSuperfluid.Timeframe({start_block: block.number + 5, stop_block: block.number + 10});

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            privKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    lilsuperfluid._CACHED_DOMAIN_SEPARATOR(),
                    lilsuperfluid.buildUpdateStructHash(streamId, 0.2 ether, timeframe)
                )
            )
        );

        ILilSuperfluid.Signature memory sig = ILilSuperfluid.Signature({v: v, r: r, s: s});

        vm.expectRevert("Unauthorized");
        lilsuperfluid.updateDetails(streamId, 0.5 ether, timeframe, sig);

        (,,,,, uint256 newPaymentRate, ILilSuperfluid.Timeframe memory newTimeframe) = lilsuperfluid.getStream(streamId);

        assertEq(newPaymentRate, 0.1 ether);
        assertEq(newTimeframe.start_block, block.number);
        assertEq(newTimeframe.stop_block, block.number + 10);
    }
}

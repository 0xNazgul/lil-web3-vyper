// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

import {Test} from "forge-std/Test.sol";
import {VyperDeployer} from "snekmate/lib/utils/VyperDeployer.sol";

import {ILilGnosis} from "./interfaces/ILilGnosis.sol";

contract CallTestUtils is Test {
    uint256 internal expectedValue;
    bytes internal expectedData;
    bool internal willRevert;

    function expectValue(uint256 _expectedValue) public payable {
        expectedValue = _expectedValue;
    }

    function expectData(bytes calldata _expectedData) public payable {
        expectedData = _expectedData;
    }

    function shouldRevert(bool _willRevert) public payable {
        willRevert = _willRevert;
    }

    receive() external payable {}

    fallback() external payable {
        assertEq(msg.value, expectedValue);
        assertEq(bytes32(msg.data), bytes32(expectedData));

        require(!willRevert, "forced revert");
    }
}

abstract contract SigUtils is Test {
    ILilGnosis internal lilgnosis;

    function signExecution(uint256 signer, address target, uint256 value, bytes32 payload)
        internal
        view
        returns (ILilGnosis.Signature memory)
    {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            signer,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    lilgnosis._CACHED_DOMAIN_SEPARATOR(),
                    lilgnosis.buildExecuteStructHash(target, value, payload)
                )
            )
        );

        return ILilGnosis.Signature({v: v, r: r, s: s});
    }

    function signQuorum(uint256 signer, uint256 quorum) internal view returns (ILilGnosis.Signature memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            signer,
            keccak256(
                abi.encodePacked(
                    "\x19\x01", lilgnosis._CACHED_DOMAIN_SEPARATOR(), lilgnosis.buildQuorumStructHash(quorum)
                )
            )
        );

        return ILilGnosis.Signature({v: v, r: r, s: s});
    }

    function signSignerUpdate(uint256 signer, address newSigner, bool shouldTrust)
        internal
        view
        returns (ILilGnosis.Signature memory)
    {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            signer,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    lilgnosis._CACHED_DOMAIN_SEPARATOR(),
                    lilgnosis.buildSignerStructHash(newSigner, shouldTrust)
                )
            )
        );

        return ILilGnosis.Signature({v: v, r: r, s: s});
    }
}

contract LilGnosisTest is SigUtils {
    VyperDeployer public vyperDeployer = new VyperDeployer();

    CallTestUtils internal target;

    address public deployer = address(vyperDeployer);
    address public zeroAddress = address(0);

    // @Note: This list of keys has been chosen specifically because their corresponding addresses are in ascending order
    uint256[] internal privKeys = [0xBEEF, 0xBEEE, 0x1234, 0x3221, 0x0010, 0x0100, 0x0323];
    address[] internal signers = new address[](privKeys.length);

    event Executed(address target, uint256 value, bytes32 payload);
    event QuorumUpdated(uint256 newQuorum);
    event SignerUpdated(address indexed signer, bool shouldTrust);

    receive() external payable {}
    fallback() external payable {}

    function setUp() public {
        target = new CallTestUtils();

        // Get addresses from the private keys above
        for (uint256 i = 0; i < privKeys.length; i++) {
            signers[i] = vm.addr(privKeys[i]);
        }

        vm.label(address(deployer), "DEPLOYER");
        vm.label(address(target), "TARGET");
        vm.label(address(this), "USER");
    }

    function testInitialSetup() public {
        bytes memory args = abi.encode("Test", "V1", privKeys.length);

        lilgnosis = ILilGnosis(vyperDeployer.deployContract("src/", "LilGnosis", args));
        lilgnosis.setupSigners(signers);
        vm.label(address(lilgnosis), "LIL GNOSIS");

        assertEq(lilgnosis.QUORUM_HASH(), keccak256("UpdateQuorum(uint256 newQuorum,uint256 nonce)"));
        assertEq(lilgnosis.SIGNER_HASH(), keccak256("UpdateSigner(address signer,bool shouldTrust,uint256 nonce)"));
        assertEq(
            lilgnosis.EXECUTE_HASH(), keccak256("Execute(address target,uint256 value,bytes payload,uint256 nonce)")
        );
        assertEq(
            lilgnosis._TYPE_HASH(),
            keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)")
        );
        assertEq(lilgnosis._CACHED_SELF(), address(lilgnosis));
        assertEq(lilgnosis._NAME(), "Test");
        assertEq(lilgnosis._HASHED_NAME(), keccak256("Test"));
        assertEq(lilgnosis._HASHED_VERSION(), keccak256("V1"));
        assertEq(lilgnosis._VERSION(), "V1");
        assertEq(
            lilgnosis._CACHED_DOMAIN_SEPARATOR(),
            keccak256(
                abi.encode(
                    lilgnosis._TYPE_HASH(),
                    lilgnosis._HASHED_NAME(),
                    lilgnosis._HASHED_VERSION(),
                    block.chainid,
                    address(lilgnosis)
                )
            )
        );
        assertEq(lilgnosis.nonce(), 1);
        assertEq(lilgnosis.quorum(), 7);
        for (uint256 i = 0; i < signers.length; i++) {
            assertEq(lilgnosis.isSigner(signers[i]), true);
        }
    }

    function test1CanExecute() public {
        bytes memory args = abi.encode("Test", "V1", privKeys.length);

        lilgnosis = ILilGnosis(vyperDeployer.deployContract("src/", "LilGnosis", args));
        lilgnosis.setupSigners(signers);
        vm.label(address(lilgnosis), "LIL GNOSIS");

        ILilGnosis.Signature[] memory signatures = new ILilGnosis.Signature[](privKeys.length);
        for (uint256 i = 0; i < privKeys.length; i++) {
            signatures[i] = signExecution(privKeys[i], address(target), 0, "");
        }

        vm.expectEmit(false, false, false, true);
        emit Executed(address(target), 0, "");
        lilgnosis.execute(address(target), 0, "", signatures);
    }

    function testCanExecuteWithValue() public {
        bytes memory args = abi.encode("Test", "V1", privKeys.length);

        lilgnosis = ILilGnosis(vyperDeployer.deployContract("src/", "LilGnosis", args));
        lilgnosis.setupSigners(signers);
        vm.label(address(lilgnosis), "LIL GNOSIS");
        vm.deal(address(lilgnosis), 10 ether);

        target.expectValue(1 ether);

        ILilGnosis.Signature[] memory signatures = new ILilGnosis.Signature[](privKeys.length);
        for (uint256 i = 0; i < privKeys.length; i++) {
            signatures[i] = signExecution(privKeys[i], address(target), 1 ether, "");
        }

        vm.expectEmit(false, false, false, true);
        emit Executed(address(target), 1 ether, "");
        lilgnosis.execute(address(target), 1 ether, "", signatures);

        assertEq(address(target).balance, 1 ether);
        assertEq(address(lilgnosis).balance, 9 ether);
    }

    function testCanExecuteWithData() public {
        bytes memory args = abi.encode("Test", "V1", privKeys.length);

        lilgnosis = ILilGnosis(vyperDeployer.deployContract("src/", "LilGnosis", args));
        lilgnosis.setupSigners(signers);
        vm.label(address(lilgnosis), "LIL GNOSIS");
        vm.deal(address(lilgnosis), 10 ether);

        target.expectData("test");

        ILilGnosis.Signature[] memory signatures = new ILilGnosis.Signature[](privKeys.length);
        for (uint256 i = 0; i < privKeys.length; i++) {
            signatures[i] = signExecution(privKeys[i], address(target), 0, "test");
        }

        vm.expectEmit(false, false, false, true);
        emit Executed(address(target), 0, "test");
        lilgnosis.execute(address(target), 0, "test", signatures);
    }

    function testCannotExecuteWithoutEnoughSignatures() public {
        bytes memory args = abi.encode("Test", "V1", privKeys.length + 1);

        lilgnosis = ILilGnosis(vyperDeployer.deployContract("src/", "LilGnosis", args));
        lilgnosis.setupSigners(signers);
        vm.label(address(lilgnosis), "LIL GNOSIS");

        ILilGnosis.Signature[] memory signatures = new ILilGnosis.Signature[](privKeys.length);
        for (uint256 i = 0; i < privKeys.length; i++) {
            signatures[i] = signExecution(privKeys[i], address(target), 0, "");
        }

        vm.expectRevert();
        lilgnosis.execute(address(target), 0, "", signatures);
    }

    function testCannotExecuteWithInvalidSignatures() public {
        bytes memory args = abi.encode("Test", "V1", privKeys.length);

        lilgnosis = ILilGnosis(vyperDeployer.deployContract("src/", "LilGnosis", args));
        lilgnosis.setupSigners(signers);
        vm.label(address(lilgnosis), "LIL GNOSIS");

        ILilGnosis.Signature[] memory signatures = new ILilGnosis.Signature[](privKeys.length);
        for (uint256 i = 0; i < privKeys.length; i++) {
            signatures[i] = signExecution(privKeys[i], address(target), 0, "");
        }

        vm.expectRevert("Invalid Signatures");
        lilgnosis.execute(address(target), 1, "", signatures);
    }

    function testCannotExecuteWithDuplicatedSignatures() public {
        bytes memory args = abi.encode("Test", "V1", privKeys.length);

        lilgnosis = ILilGnosis(vyperDeployer.deployContract("src/", "LilGnosis", args));
        lilgnosis.setupSigners(signers);
        vm.label(address(lilgnosis), "LIL GNOSIS");

        ILilGnosis.Signature[] memory signatures = new ILilGnosis.Signature[](privKeys.length);
        for (uint256 i = 0; i < privKeys.length; i++) {
            signatures[i] = signExecution(privKeys[i], address(target), 1, "");
        }

        signatures[0] = signatures[1];

        vm.expectRevert("Invalid Signatures");
        lilgnosis.execute(address(target), 0, "", signatures);
    }

    function testCannotExecuteWithUntrustedSignatures() public {
        bytes memory args = abi.encode("Test", "V1", privKeys.length);

        lilgnosis = ILilGnosis(vyperDeployer.deployContract("src/", "LilGnosis", args));
        lilgnosis.setupSigners(signers);
        vm.label(address(lilgnosis), "LIL GNOSIS");

        ILilGnosis.Signature[] memory signatures = new ILilGnosis.Signature[](privKeys.length);
        for (uint256 i = 0; i < privKeys.length; i++) {
            signatures[i] = signExecution(privKeys[i], address(target), 1, "");
        }

        signatures[4] = signExecution(0xDEAD, address(target), 1, "");

        vm.expectRevert("Invalid Signatures");
        lilgnosis.execute(address(target), 0, "", signatures);
    }

    function testRevertsWhenCallReverts() public {
        bytes memory args = abi.encode("Test", "V1", privKeys.length);

        lilgnosis = ILilGnosis(vyperDeployer.deployContract("src/", "LilGnosis", args));
        lilgnosis.setupSigners(signers);
        vm.label(address(lilgnosis), "LIL GNOSIS");

        target.shouldRevert(true);

        ILilGnosis.Signature[] memory signatures = new ILilGnosis.Signature[](privKeys.length);
        for (uint256 i = 0; i < privKeys.length; i++) {
            signatures[i] = signExecution(privKeys[i], address(target), 0, "");
        }

        vm.expectRevert("Execution Failed");
        lilgnosis.execute(address(target), 0, "", signatures);
    }

    function testCanSetQuorum(uint256 newQuorum) public {
        bytes memory args = abi.encode("Test", "V1", privKeys.length);

        lilgnosis = ILilGnosis(vyperDeployer.deployContract("src/", "LilGnosis", args));
        lilgnosis.setupSigners(signers);
        vm.label(address(lilgnosis), "LIL GNOSIS");

        ILilGnosis.Signature[] memory signatures = new ILilGnosis.Signature[](privKeys.length);
        for (uint256 i = 0; i < privKeys.length; i++) {
            signatures[i] = signQuorum(privKeys[i], newQuorum);
        }

        vm.expectEmit(false, false, false, true);
        emit QuorumUpdated(newQuorum);
        lilgnosis.setQuorum(newQuorum, signatures);

        assertEq(lilgnosis.quorum(), newQuorum);
    }

    function testCannotSetQuorumWithoutEnoughSignatures() public {
        bytes memory args = abi.encode("Test", "V1", privKeys.length + 1);

        lilgnosis = ILilGnosis(vyperDeployer.deployContract("src/", "LilGnosis", args));
        lilgnosis.setupSigners(signers);
        vm.label(address(lilgnosis), "LIL GNOSIS");

        ILilGnosis.Signature[] memory signatures = new ILilGnosis.Signature[](privKeys.length);
        for (uint256 i = 0; i < privKeys.length; i++) {
            signatures[i] = signQuorum(privKeys[i], 1);
        }

        vm.expectRevert();
        lilgnosis.setQuorum(1, signatures);
    }

    function testCannotSetQuorumWithInvalidSignatures() public {
        bytes memory args = abi.encode("Test", "V1", privKeys.length);

        lilgnosis = ILilGnosis(vyperDeployer.deployContract("src/", "LilGnosis", args));
        lilgnosis.setupSigners(signers);
        vm.label(address(lilgnosis), "LIL GNOSIS");

        ILilGnosis.Signature[] memory signatures = new ILilGnosis.Signature[](privKeys.length);
        for (uint256 i = 0; i < privKeys.length; i++) {
            signatures[i] = signQuorum(privKeys[i], 5);
        }

        vm.expectRevert("Invalid Signatures");
        lilgnosis.setQuorum(4, signatures);
    }

    function testCannotSetQuorumWithDuplicatedSignatures() public {
        bytes memory args = abi.encode("Test", "V1", privKeys.length);

        lilgnosis = ILilGnosis(vyperDeployer.deployContract("src/", "LilGnosis", args));
        lilgnosis.setupSigners(signers);
        vm.label(address(lilgnosis), "LIL GNOSIS");

        ILilGnosis.Signature[] memory signatures = new ILilGnosis.Signature[](privKeys.length);
        for (uint256 i = 0; i < privKeys.length; i++) {
            signatures[i] = signQuorum(privKeys[1], 10);
        }

        vm.expectRevert("Invalid Signatures");
        lilgnosis.setQuorum(10, signatures);
    }

    function testCannotSetQuorumWithUntrustedSignatures() public {
        bytes memory args = abi.encode("Test", "V1", privKeys.length);

        lilgnosis = ILilGnosis(vyperDeployer.deployContract("src/", "LilGnosis", args));
        lilgnosis.setupSigners(signers);
        vm.label(address(lilgnosis), "LIL GNOSIS");

        ILilGnosis.Signature[] memory signatures = new ILilGnosis.Signature[](privKeys.length);
        for (uint256 i = 0; i < privKeys.length; i++) {
            signatures[i] = signQuorum(privKeys[i], 5);
        }

        signatures[4] = signQuorum(0xDEAD, 5);

        vm.expectRevert("Invalid Signatures");
        lilgnosis.setQuorum(5, signatures);
    }

    function testCanSetSigner() public {
        bytes memory args = abi.encode("Test", "V1", privKeys.length);

        lilgnosis = ILilGnosis(vyperDeployer.deployContract("src/", "LilGnosis", args));
        lilgnosis.setupSigners(signers);
        vm.label(address(lilgnosis), "LIL GNOSIS");
        assertTrue(!lilgnosis.isSigner(address(this)));

        ILilGnosis.Signature[] memory signatures = new ILilGnosis.Signature[](privKeys.length);
        for (uint256 i = 0; i < privKeys.length; i++) {
            signatures[i] = signSignerUpdate(privKeys[i], address(this), true);
        }

        vm.expectEmit(true, false, false, true);
        emit SignerUpdated(address(this), true);

        lilgnosis.setSigner(address(this), true, signatures);

        assertTrue(lilgnosis.isSigner(address(this)));
    }

    function testCannotSetSignerWithoutEnoughSignatures() public {
        bytes memory args = abi.encode("Test", "V1", privKeys.length + 1);

        lilgnosis = ILilGnosis(vyperDeployer.deployContract("src/", "LilGnosis", args));
        lilgnosis.setupSigners(signers);
        vm.label(address(lilgnosis), "LIL GNOSIS");

        ILilGnosis.Signature[] memory signatures = new ILilGnosis.Signature[](privKeys.length);
        for (uint256 i = 0; i < privKeys.length; i++) {
            signatures[i] = signSignerUpdate(privKeys[i], address(this), true);
        }

        vm.expectRevert();
        lilgnosis.setSigner(address(this), true, signatures);
    }

    function testCannotSetSignerWithInvalidSignatures() public {
        bytes memory args = abi.encode("Test", "V1", privKeys.length);

        lilgnosis = ILilGnosis(vyperDeployer.deployContract("src/", "LilGnosis", args));
        lilgnosis.setupSigners(signers);
        vm.label(address(lilgnosis), "LIL GNOSIS");

        ILilGnosis.Signature[] memory signatures = new ILilGnosis.Signature[](privKeys.length);
        for (uint256 i = 0; i < privKeys.length; i++) {
            signatures[i] = signSignerUpdate(privKeys[i], address(0x1), true);
        }

        vm.expectRevert("Invalid Signatures");
        lilgnosis.setSigner(address(this), true, signatures);
    }

    function testCannotSetSignerWithDuplicatedSignatures() public {
        bytes memory args = abi.encode("Test", "V1", privKeys.length);

        lilgnosis = ILilGnosis(vyperDeployer.deployContract("src/", "LilGnosis", args));
        lilgnosis.setupSigners(signers);
        vm.label(address(lilgnosis), "LIL GNOSIS");

        ILilGnosis.Signature[] memory signatures = new ILilGnosis.Signature[](privKeys.length);
        for (uint256 i = 0; i < privKeys.length; i++) {
            signatures[i] = signSignerUpdate(privKeys[1], address(this), true);
        }

        vm.expectRevert("Invalid Signatures");
        lilgnosis.setSigner(address(this), true, signatures);
    }

    function testCannotSetSignerWithUntrustedSignatures() public {
        bytes memory args = abi.encode("Test", "V1", privKeys.length);

        lilgnosis = ILilGnosis(vyperDeployer.deployContract("src/", "LilGnosis", args));
        lilgnosis.setupSigners(signers);
        vm.label(address(lilgnosis), "LIL GNOSIS");

        ILilGnosis.Signature[] memory signatures = new ILilGnosis.Signature[](privKeys.length);
        for (uint256 i = 0; i < privKeys.length; i++) {
            signatures[i] = signSignerUpdate(privKeys[i], address(this), true);
        }

        signatures[4] = signSignerUpdate(0xDEAD, address(this), true);

        vm.expectRevert("Invalid Signatures");
        lilgnosis.setSigner(address(this), true, signatures);
    }
}

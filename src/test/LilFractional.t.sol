// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

import {Test} from "forge-std/Test.sol";
import {VyperDeployer} from "snekmate/lib/utils/VyperDeployer.sol";
import {ERC721} from "openzeppelin/token/ERC721/ERC721.sol";

import {ILilFractional} from "./interfaces/ILilFractional.sol";
import {INFTShare} from "./interfaces/INFTShare.sol";

contract TestNFT is ERC721("Test NFT", "TEST") {
    uint256 public tokenId = 1;

    function tokenURI(uint256) public pure override returns (string memory) {
        return "test";
    }

    function mint() public returns (uint256) {
        _mint(msg.sender, tokenId);

        return tokenId++;
    }
}

contract LilFractionalTest is Test {
    VyperDeployer public vyperDeployer = new VyperDeployer();

    ILilFractional public lilfractional;
    INFTShare public nftshare;
    TestNFT public nft;
    uint256 public nftId;

    address public deployer = address(vyperDeployer);
    address public zeroAddress = address(0);

    event VaultCreated(
        uint256 indexed vaultId,
        address nftContract,
        uint256 tokenId,
        uint256 indexed tokenSupply,
        address tokenContract
    );
    event VaultDestroyed(
        uint256 indexed vaultId,
        address nftContract,
        uint256 tokenId,
        uint256 indexed tokenSupply,
        address tokenContract
    );
    event Transfer(address indexed from, address indexed to, uint256 amount);

    receive() external payable {}
    fallback() external payable {}

    function setUp() public {
        nft = new TestNFT();
        bytes memory nftArgs = abi.encode("NAME", "SYB", 18);

        nftshare = INFTShare(vyperDeployer.deployContract("src/", "NFTShare", nftArgs));

        bytes memory args = abi.encode(address(nftshare));

        lilfractional = ILilFractional(vyperDeployer.deployContract("src/", "LilFractional", args));
        vm.label(address(lilfractional), "LIL LILFRACTIONAL");
        vm.label(address(nftshare), "MASTER COPY");
        vm.label(address(deployer), "DEPLOYER");
        vm.label(address(this), "USER");

        nft.setApprovalForAll(address(lilfractional), true);

        nftId = nft.mint();
    }

    function testInitialSetup() public {
        assertEq(lilfractional.masterCopy(), address(nftshare));
        assertEq(lilfractional.vaultId(), 1);
    }

    function testSplit() public {
        assertEq(nft.ownerOf(nftId), address(this));

        vm.expectEmit(true, true, false, true);
        emit Transfer(address(0), address(this), 100 ether);

        uint256 vaultId = lilfractional.split(address(nft), nftId, 100 ether, "Fractionalised NFT", "FRAC", 18);

        (address nftContract, uint256 tokenId, uint256 supply, address tokenContract) = lilfractional.getVault(vaultId);

        assertEq(nft.ownerOf(nftId), address(lilfractional));
        assertEq(address(nftContract), address(nft));
        assertEq(tokenId, nftId);
        assertEq(supply, 100 ether);
        assertEq(INFTShare(tokenContract).balanceOf(address(this)), 100 ether);

        vm.expectRevert("ERC721: transfer from incorrect owner");
        lilfractional.split(address(nft), nftId, 100 ether, "Fractionalised NFT", "FRAC", 18);
    }

    function testJoin() public {
        uint256 vaultId = lilfractional.split(address(nft), nftId, 100 ether, "Fractionalised NFT", "FRAC", 18);

        (,,, address tokenContract) = lilfractional.getVault(vaultId);

        assertEq(nft.ownerOf(nftId), address(lilfractional));
        assertEq(INFTShare(tokenContract).balanceOf(address(this)), 100 ether);

        INFTShare(tokenContract).approve(address(lilfractional), type(uint256).max);

        lilfractional.join(vaultId);

        assertEq(nft.ownerOf(nftId), address(this));
        assertEq(INFTShare(tokenContract).balanceOf(address(this)), 0);

        (, uint256 tokenId,,) = lilfractional.getVault(vaultId);
        assertEq(tokenId, 0, "id");

        vm.expectRevert("Vault Not Found");
        lilfractional.join(1);
    }

    function testPartialHolderCannotJoinToken() public {
        uint256 vaultId = lilfractional.split(address(nft), nftId, 100 ether, "Fractionalised NFT", "FRAC", 18);

        (,,, address tokenContract) = lilfractional.getVault(vaultId);

        assertEq(nft.ownerOf(nftId), address(lilfractional));
        assertEq(INFTShare(tokenContract).balanceOf(address(this)), 100 ether);

        INFTShare(tokenContract).transfer(address(deployer), 100 ether - 1);

        vm.startPrank(address(deployer));
        INFTShare(tokenContract).approve(address(lilfractional), type(uint256).max);

        vm.expectRevert("ERC20: burn amount exceeds balance");
        lilfractional.join(vaultId);

        assertEq(nft.ownerOf(nftId), address(lilfractional));
        assertEq(INFTShare(tokenContract).balanceOf(address(deployer)), 100 ether - 1);
    }

    function testNonHolderCannotJoinToken() public {
        uint256 vaultId = lilfractional.split(address(nft), nftId, 100 ether, "Fractionalised NFT", "FRAC", 18);

        (,,, address tokenContract) = lilfractional.getVault(vaultId);

        assertEq(nft.ownerOf(nftId), address(lilfractional));
        assertEq(INFTShare(tokenContract).balanceOf(address(this)), 100 ether);

        vm.startPrank(address(deployer));
        INFTShare(tokenContract).approve(address(lilfractional), type(uint256).max);

        vm.expectRevert("ERC20: burn amount exceeds balance");
        lilfractional.join(vaultId);

        assertEq(nft.ownerOf(nftId), address(lilfractional));
        assertEq(INFTShare(tokenContract).balanceOf(address(this)), 100 ether);
    }
}

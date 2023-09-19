// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

import {Test} from "forge-std/Test.sol";
import {VyperDeployer} from "snekmate/lib/utils/VyperDeployer.sol";

import {ERC721} from "solmate/tokens/ERC721.sol";

import {ILilOpenSea} from "./interfaces/ILilOpenSea.sol";

contract TestNFT is ERC721("Test NFT", "TEST") {
    uint256 public tokenId = 1;

    function tokenURI(uint256) public pure override returns (string memory) {
        return "test";
    }

    function mint() public payable returns (uint256) {
        _mint(msg.sender, tokenId);

        return tokenId++;
    }
}

contract LilOpenSeaTest is Test {
    VyperDeployer public vyperDeployer = new VyperDeployer();

    ILilOpenSea public lilOpenSea;
    TestNFT public nft;
    uint256 public nftId;

    address public deployer = address(vyperDeployer);
    address public zeroAddress = address(0);

    event NewListing(
        address indexed creator,
        uint256 indexed listingId,
        address tokenContract,
        uint256 tokenId,
        uint256 indexed askPrice
    );

    event ListingRemoved(
        address indexed creator,
        uint256 indexed listingId,
        address tokenContract,
        uint256 indexed tokenId,
        uint256 askPrice
    );

    event ListingBought(
        address indexed creator,
        address indexed buyer,
        uint256 listingId,
        address tokenContract,
        uint256 tokenId,
        uint256 indexed askPrice
    );

    event NewOwner(address indexed oldOwner, address indexed newOwner);

    event NewFee(uint256 indexed oldFee, uint256 indexed newFee);

    event WithdrawFees(uint256 indexed amount);

    receive() external payable {}
    fallback() external payable {}

    function setUp() public {
        bytes memory args = abi.encode(100);

        lilOpenSea = ILilOpenSea(vyperDeployer.deployContract("src/", "LilOpenSea", args));

        nft = new TestNFT();
        nft.setApprovalForAll(address(lilOpenSea), true);
        nftId = nft.mint();

        vm.label(address(lilOpenSea), "LIL OPENSEA");
        vm.label(address(nft), "NFT");
        vm.label(address(deployer), "DEPLOYER");
        vm.label(address(this), "USER");
    }

    function testInitialSetup(uint256 fee) public {
        assertEq(lilOpenSea.fee(), 100);
        assertEq(lilOpenSea.owner(), deployer);

        fee = bound(fee, 0, 1e18);

        bytes memory fuzzArgs = abi.encode(fee);

        ILilOpenSea _lilOpenSea = ILilOpenSea(vyperDeployer.deployContract("src/", "LilOpenSea", fuzzArgs));

        assertEq(_lilOpenSea.fee(), fee);
        assertEq(_lilOpenSea.owner(), deployer);
    }

    function testNewListing(uint256 askPrice) public {
        vm.deal(address(this), 1 ether);
        vm.expectEmit(true, true, true, true);
        emit NewListing(address(this), 1, address(nft), 1, 100);
        uint256 counter = lilOpenSea.list{value: 101}(address(nft), nftId, 100);

        (address tokenContract, uint256 tokenId, address creator, uint256 _askPrice) = lilOpenSea.getListing(counter);

        assertEq(tokenContract, address(nft));
        assertEq(tokenId, nftId);
        assertEq(creator, address(this));
        assertEq(_askPrice, 100);
        assertEq(counter + 1, lilOpenSea.saleCounter());
        assertEq(address(lilOpenSea).balance, 100);
        assertEq(address(this).balance, 1 ether - 100);

        uint256 _nftId = nft.mint();
        vm.expectRevert(bytes("Not enough for fee"));
        lilOpenSea.list{value: 1}(address(nft), _nftId, 100);

        TestNFT _nft = new TestNFT();
        _nft.setApprovalForAll(address(lilOpenSea), true);
        uint256 nftId_ = _nft.mint();

        uint256 _counter = lilOpenSea.list{value: 101}(address(_nft), nftId_, askPrice);
        (address fuzzTokenContract, uint256 fuzztokenId, address fuzzCreator, uint256 fuzzAskPrice) =
            lilOpenSea.getListing(_counter);

        assertEq(fuzzTokenContract, address(_nft));
        assertEq(fuzztokenId, nftId_);
        assertEq(fuzzCreator, address(this));
        assertEq(fuzzAskPrice, askPrice);
        assertEq(_counter + 1, lilOpenSea.saleCounter());
    }

    function testListingRemoved(uint256 askPrice) public {
        uint256 counter = lilOpenSea.list{value: 101}(address(nft), nftId, 100);

        vm.expectEmit(true, true, true, true);
        emit ListingRemoved(address(this), 1, address(nft), 1, 100);
        lilOpenSea.cancelListing(counter);

        (address tokenContract, uint256 tokenId, address creator, uint256 _askPrice) = lilOpenSea.getListing(counter);

        assertEq(tokenContract, address(0));
        assertEq(tokenId, 0);
        assertEq(creator, address(0));
        assertEq(_askPrice, 0);

        vm.prank(deployer);
        vm.expectRevert(bytes("Unauthorized"));
        lilOpenSea.cancelListing(counter);

        TestNFT _nft = new TestNFT();
        _nft.setApprovalForAll(address(lilOpenSea), true);
        uint256 nftId_ = _nft.mint();

        uint256 _counter = lilOpenSea.list{value: 101}(address(_nft), nftId_, askPrice);
        lilOpenSea.cancelListing(_counter);
        (address fuzzTokenContract, uint256 fuzztokenId, address fuzzCreator, uint256 fuzzAskPrice) =
            lilOpenSea.getListing(_counter);

        assertEq(fuzzTokenContract, address(0));
        assertEq(fuzztokenId, 0);
        assertEq(fuzzCreator, address(0));
        assertEq(fuzzAskPrice, 0);
    }

    function testListingBought(uint256 askPrice) public {
        vm.deal(address(this), 1 ether);
        uint256 counter = lilOpenSea.list{value: 101}(address(nft), nftId, 100);

        vm.deal(deployer, 1 ether);
        vm.prank(deployer);
        vm.expectEmit(true, true, true, true);
        emit ListingBought(address(this), deployer, 1, address(nft), 1, 100);
        lilOpenSea.buyListing{value: 110}(counter);

        (address tokenContract, uint256 tokenId, address creator, uint256 _askPrice) = lilOpenSea.getListing(counter);

        assertEq(tokenContract, address(0));
        assertEq(tokenId, 0);
        assertEq(creator, address(0));
        assertEq(_askPrice, 0);
        assertEq(address(this).balance, 1 ether);
        assertEq(address(deployer).balance, 1 ether - 100);

        uint256 _nftId = nft.mint();
        uint256 _counter = lilOpenSea.list{value: 101}(address(nft), _nftId, 100);

        vm.expectRevert("Listing Not Found");
        lilOpenSea.buyListing{value: 110}(_counter + 1);

        vm.expectRevert("Not enough value sent");
        lilOpenSea.buyListing{value: 1}(_counter);

        TestNFT _nft = new TestNFT();
        _nft.setApprovalForAll(address(lilOpenSea), true);
        uint256 nftId_ = _nft.mint();

        askPrice = bound(askPrice, 1 ether, 100 ether);

        uint256 counter_ = lilOpenSea.list{value: 101}(address(_nft), nftId_, askPrice);

        vm.deal(deployer, askPrice);
        vm.prank(deployer);
        lilOpenSea.buyListing{value: askPrice}(counter_);
        (address fuzzTokenContract, uint256 fuzztokenId, address fuzzCreator, uint256 fuzzAskPrice) =
            lilOpenSea.getListing(counter_);

        assertEq(fuzzTokenContract, address(0));
        assertEq(fuzztokenId, 0);
        assertEq(fuzzCreator, address(0));
        assertEq(fuzzAskPrice, 0);
    }

    function testNewOwner(address newOwner) public {
        vm.startPrank(deployer);
        vm.expectEmit(true, true, false, false);
        emit NewOwner(address(deployer), address(this));
        lilOpenSea.newOwner(address(this));

        vm.expectRevert(bytes("Unauthorized"));
        lilOpenSea.newOwner(address(this));
        vm.stopPrank();

        vm.expectRevert(bytes("Zero address not allowed"));
        lilOpenSea.newOwner(zeroAddress);

        vm.assume(newOwner != zeroAddress);
        lilOpenSea.newOwner(newOwner);
        assertEq(lilOpenSea.owner(), newOwner);
    }

    function testNewNameFee(uint256 newFee) public {
        vm.startPrank(deployer);
        vm.expectEmit(true, true, false, false);
        emit NewFee(100, 10);
        lilOpenSea.newFee(10);

        vm.expectRevert(bytes("Fee too high"));
        lilOpenSea.newFee(10e18);
        vm.stopPrank();

        vm.expectRevert(bytes("Unauthorized"));
        lilOpenSea.newFee(10);

        newFee = bound(newFee, 0, 1e18);

        vm.startPrank(deployer);
        lilOpenSea.newFee(newFee);
        assertEq(lilOpenSea.fee(), newFee);
        vm.stopPrank();
    }

    function testWithdrawFees(uint256 amount) public {
        vm.deal(address(lilOpenSea), 1 ether);

        vm.startPrank(deployer);
        vm.expectEmit(true, true, false, false);
        emit WithdrawFees(1 ether);
        lilOpenSea.withdrawFees(1 ether);
        assertEq(deployer.balance, 1 ether);
        vm.stopPrank();

        vm.expectRevert(bytes("Unauthorized"));
        lilOpenSea.withdrawFees(1 ether);

        amount = bound(amount, 1 ether, 100 ether);
        vm.deal(address(lilOpenSea), amount);

        vm.startPrank(deployer);
        lilOpenSea.withdrawFees(amount);
        assertEq(deployer.balance, amount + 1 ether);
        vm.stopPrank();
    }
}

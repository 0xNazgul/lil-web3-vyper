// SPDX-License-Identifier TODO AGPL-3.0-only
pragma solidity ^0.8.10;


interface ILilSuperfluid {

event StreamCreated(Stream stream);
event StreamRefueled(uint256 indexed stream_id, uint256 amount);
event FundsWithdrawn(uint256 indexed stream_id, uint256 amount);
event ExcessWithdrawn(uint256 indexed stream_id, uint256 amount);
event StreamDetailsUpdated(uint256 indexed stream_id, uint256 payment_per_block, Timeframe timeframe);

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

    struct Signature {
        uint8 v;
        bytes32 r;
        bytes32 s;
    }  

    function _UPDATE_DETAILS_HASH() external view returns (bytes32);
    function _CACHED_CHAIN_ID() external view returns (uint256);
    function _CACHED_DOMAIN_SEPARATOR() external view returns (bytes32);
    function _CACHED_SELF() external view returns (address);
    function _HASHED_NAME() external view returns (bytes32);
    function _HASHED_VERSION() external view returns (bytes32);
    function _NAME() external view returns (string memory);
    function _TYPE_HASH() external view returns (bytes32);
    function _VERSION() external view returns (string memory);
    function buildUpdateStructHash(uint256 streamId, uint256 paymentPerBlock, Timeframe memory timeframe_) external view returns (bytes32);    
    function nonce() external view returns (uint256);
    function stream_id() external view returns (uint256);
    function getStream(uint256 arg0) external view returns (address sender, address recipient, address streamToken, uint256 balance, uint256 withdrawnBalance, uint256 paymentPerBlock, Timeframe memory streamTimeframe);
    function updateDetails(uint256 streamId, uint256 paymentPerBlock, Timeframe memory timeframe_, Signature memory sig) external;
    function getBalanceOf(uint256 streamId, address who)  external returns(uint256);
    function calculateBlockDelta(Timeframe memory timeframe) external returns(uint256);
    function refund(uint256 streamId) external ;
    function withdraw(uint256 streamId) external ;
    function refuel(uint256 streamId, uint256 amount) external ;
    function streamTo(address recipient_, address token_, uint256 initialBalance, Timeframe  memory timeframe_, uint256 paymentPerBlock_) external returns(uint256);
}
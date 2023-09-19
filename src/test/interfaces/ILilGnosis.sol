// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.10;

interface ILilGnosis {
    event Executed(address target, uint256 value, bytes32 payload);
    event QuorumUpdated(uint256 newQuorum);
    event SignerUpdated(address indexed signer, bool shouldTrust);

    struct Signature {
        uint8 v;
        bytes32 r;
        bytes32 s;
    }  

    function EXECUTE_HASH() external view returns (bytes32);
    function QUORUM_HASH() external view returns (bytes32);
    function SIGNER_HASH() external view returns (bytes32);
    function _CACHED_CHAIN_ID() external view returns (uint256);
    function _CACHED_DOMAIN_SEPARATOR() external view returns (bytes32);
    function _CACHED_SELF() external view returns (address);
    function _HASHED_NAME() external view returns (bytes32);
    function _HASHED_VERSION() external view returns (bytes32);
    function _NAME() external view returns (string memory);
    function _TYPE_HASH() external view returns (bytes32);
    function _VERSION() external view returns (string memory);
    function buildExecuteStructHash(address target, uint256 value_, bytes32 payload) external view returns (bytes32);
    function buildQuorumStructHash(uint256 _quorum) external view returns (bytes32);
    function buildSignerStructHash(address signer, bool shouldTrust) external view returns (bytes32);
    function execute(address target, uint256 value_, bytes32 payload, Signature[] memory sigs)
        external
        payable;
    function initialized() external view returns (uint256);
    function isSigner(address arg0) external view returns (bool);
    function nonce() external view returns (uint256);
    function quorum() external view returns (uint256);
    function setQuorum(uint256 _quorum, Signature[] memory sigs) external payable;
    function setSigner(address signer, bool shouldTrust, Signature[] memory sigs) external payable;
    function setupSigners(address[] memory signers) external;
}

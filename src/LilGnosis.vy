# @version ^0.3.9
"""
@title lil gnosis vyper
@custom:contract-name LilGnosis
@license GNU Affero General Public License v3.0
@author 0xNazgul
@dev Simple implementation of gnosis
"""

# @dev Components of an Ethereum signature
struct Signature:
    v: uint8
    r: bytes32
    s: bytes32

# @notice Signature nonce, incremented with each successful execution or state change
# @dev This is used to prevent signature reuse
nonce: public(uint256)

# @notice The amount of required signatures to execute a transaction or change the state
quorum: public(uint256)

# @notice A list of signers, and wether they're trusted by this contract
isSigner: public(HashMap[address, bool]) 

# @dev EIP-712 types for a signature that updates the quorum
QUORUM_HASH: public(constant(bytes32)) = keccak256("UpdateQuorum(uint256 newQuorum,uint256 nonce)")

# @dev EIP-712 types for a signature that updates a signer state
SIGNER_HASH: public(constant(bytes32)) = keccak256("UpdateSigner(address signer,bool shouldTrust,uint256 nonce)")

# @dev EIP-712 types for a signature that executes a transaction
EXECUTE_HASH: public(constant(bytes32)) = keccak256("Execute(address target,uint256 value,bytes payload,uint256 nonce)")

# @dev The 32-byte type hash for the EIP-712 domain separator.
_TYPE_HASH: public(constant(bytes32)) = keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)")

# @dev Caches the domain separator as an `immutable`
# value, but also stores the corresponding chain ID
# to invalidate the cached domain separator if the
# chain ID changes.
_CACHED_DOMAIN_SEPARATOR: public(immutable(bytes32))
_CACHED_CHAIN_ID: public(immutable(uint256))

# @dev Caches `self` to `immutable` storage to avoid
# potential issues if a vanilla contract is used in
# a `delegatecall` context.
_CACHED_SELF: public(immutable(address))

# @dev `immutable` variables to store the (hashed)
# name and (hashed) version during contract creation.
_NAME: public(immutable(String[50]))
_HASHED_NAME: public(immutable(bytes32))
_VERSION: public(immutable(String[20]))
_HASHED_VERSION: public(immutable(bytes32))

# @notice Emitted when the number of required signatures is updated
# @param newQuorum The new amount of required signatures
event QuorumUpdated:
    newQuorum: uint256

# @notice Emitted when a new transaction is executed
# @param target The address the transaction was sent to
# @param value The amount of ETH sent in the transaction
# @param payload The data sent in the transaction
event Executed:
    target: address
    value: uint256
    payload: bytes32

# @notice Emitted when a new signer gets added or removed from the trusted signers
# @param signer The address of the updated signer
# @param shouldTrust Wether the contract will trust this signer going forwards
event SignerUpdated:
    signer: indexed(address)
    shouldTrust: bool

# @notice used to setup signers for the first time. Given how 
# vyperDeployer ABI-encoded constructor arguments to the
# deployment bytecode. I couldn't out right pass an array of signers
# and instead do this hacky fix.
initialized: public(uint256)

@external
@payable
def __default__():
    """
    @notice This function ensures this contract can receive ETH
    """
    pass

@external
@payable
def __init__(name_: String[50], version_: String[20], quorum_: uint256):
    """
    @notice initialization of state   
	@param name_ The name of the multisig
    @param version_ The version of the multisig
	@param quorum_ The number of required signatures to execute a transaction or change the state   
    """
    _NAME = name_
    _VERSION = version_
    _HASHED_NAME = keccak256(name_)
    _HASHED_VERSION = keccak256(version_)
    _CACHED_DOMAIN_SEPARATOR =  keccak256(_abi_encode(_TYPE_HASH, _HASHED_NAME, _HASHED_VERSION, chain.id, self))
    _CACHED_CHAIN_ID = chain.id
    _CACHED_SELF = self

    self.nonce = 1
    self.quorum = quorum_

@external
def setupSigners(signers: DynArray[address, 20]):
    assert self.initialized == 0, "Already initialized"
    for i in signers:
        self.isSigner[i] = True    
    self.initialized = 1

@external
@payable
def execute(target: address, value_: uint256, payload: bytes32, sigs: DynArray[Signature, 20]):
    """
    @notice Execute a transaction from the multisig, providing the required amount of signatures
	@param target The address to send the transaction to
	@param value_ The amount of ETH to send in the transaction
	@param payload The data to send in the transaction
	@param sigs An array of signatures from trusted signers, sorted in ascending order by the signer's addresses
	@dev Make sure the signatures are sorted in ascending order by the signer's addresses! Otherwise the verification will fail    
    """
    digest: bytes32 = keccak256(
        concat(
            b"\x19\x01",
            _CACHED_DOMAIN_SEPARATOR,
            keccak256(_abi_encode(EXECUTE_HASH, target, value_, payload, self.nonce))
        )
    )
    self.nonce += self.nonce + 1
    previous: address = empty(address)
    _quorum: uint256 = self.quorum

    for i in range(20):
        if i == _quorum:
            break       

        sigAddress: address = ecrecover(digest, sigs[i].v, sigs[i].r, sigs[i].s)

        assert self.isSigner[sigAddress] == True, "Invalid Signatures"
        assert previous != sigAddress, "Invalid Signatures" 

        previous = sigAddress
       
    log Executed(target, value_, payload)
       
    success: bool = False
    response: Bytes[32] = b""
    success, response = raw_call(
        target,
        _abi_encode(payload),
        max_outsize=32,
        value=value_,
        revert_on_failure=False
        )        
    assert success, "Execution Failed"

@external
@payable
def setQuorum(_quorum: uint256, sigs: DynArray[Signature, 20]):
    """
    @notice Update the amount of required signatures to execute a transaction or change state, providing the required amount of signatures
	@param _quorum The new number of required signatures
	@param sigs An array of signatures from trusted signers, sorted in ascending order by the signer's addresses
	@dev Make sure the signatures are sorted in ascending order by the signer's addresses! Otherwise the verification will fail
    """
    digest: bytes32 = keccak256(
        concat(
            b"\x19\x01",
            _CACHED_DOMAIN_SEPARATOR,
            keccak256(_abi_encode(QUORUM_HASH, _quorum, self.nonce))
        )
    )
    self.nonce = self.nonce + 1
    previous: address = empty(address)
    quorum_: uint256 = self.quorum

    for i in range(20):
        if i == quorum_:
            break       

        sigAddress: address = ecrecover(digest, sigs[i].v, sigs[i].r, sigs[i].s)

        assert self.isSigner[sigAddress] == True, "Invalid Signatures"
        assert previous != sigAddress, "Invalid Signatures" 

        previous = sigAddress

    log QuorumUpdated(_quorum)

    self.quorum = _quorum

@external
@payable
def setSigner(signer: address, shouldTrust: bool, sigs: DynArray[Signature, 20]):
    """
    @notice Add or remove an address from the list of signers trusted by this contract
	@param signer The address of the signer
	@param shouldTrust Wether to trust this signer going forward
	@param sigs An array of signatures from trusted signers, sorted in ascending order by the signer's addresses
	@dev Make sure the signatures are sorted in ascending order by the signer's addresses! Otherwise the verification will fail
    """
    digest: bytes32 = keccak256(
        concat(
            b"\x19\x01",
            _CACHED_DOMAIN_SEPARATOR,
            keccak256(_abi_encode(SIGNER_HASH, signer, shouldTrust, self.nonce))
        )
    )   
    self.nonce = self.nonce + 1
    previous: address = empty(address)
    _quorum: uint256 = self.quorum
    
    for i in range(20):
        if i == _quorum:
            break       

        sigAddress: address = ecrecover(digest, sigs[i].v, sigs[i].r, sigs[i].s)
        
        assert self.isSigner[sigAddress] == True, "Invalid Signatures"
        assert previous != sigAddress, "Invalid Signatures" 

        previous = sigAddress
 
    log SignerUpdated(signer, shouldTrust)

    self.isSigner[signer] = shouldTrust

@external
@view
def buildExecuteStructHash(target: address, value_: uint256, payload: bytes32) -> bytes32:
    """
    @notice Used to help build the execute struct hash to sign on
	@param target The address to send the transaction to
	@param value_ The amount of ETH to send in the transaction
	@param payload The data to send in the transaction
    @return The struct hash 
    """
    return keccak256(_abi_encode(EXECUTE_HASH, target, value_, payload, self.nonce))


@external
@view
def buildQuorumStructHash(_quorum: uint256) -> bytes32:
    """
    @notice Used to help build the quorum struct hash to sign on
    @param _quorum The new number of required signatures
    @return The struct hash 
    """    
    return keccak256(_abi_encode(QUORUM_HASH, _quorum, self.nonce))

@external
@view
def buildSignerStructHash(signer: address, shouldTrust: bool) -> bytes32:
    """
    @notice Used to help build the signer struct hash to sign on
    @param signer The address of the signer
    @param shouldTrust Wether to trust this signer going forward
    @return The struct hash 
    """    
    return keccak256(_abi_encode(SIGNER_HASH, signer, shouldTrust, self.nonce))
# lil web3 Vyper
> Really simple, intentionally-limited versions of web3 protocols & apps. By 
> distilling them to their roots, we can better understand how they work.

lil web3 Vyper aims to build [lil web3](https://github.com/m1guelpf/lil-web3) from [m1guel](https://github.com/m1guelpf) in Vyper. All descriptions/deconstruct are inspiration taken from m1guel's repo and not my own. Go show them some love for the work they have done.

## Table of contents
- [lil-web3](#lil-web3)
    - [lil ENS](#lil-ens)
    - [lil opensea](#lil-opensea)
    - [lil fractional](#lil-fractional)
    - [lil juicebox](#lil-juicebox)
    - [lil flashloan](#lil-flashloan)
    - [lil gnosis](#lil-gnosis)
- [Contributing](#contributing)

# lil-web3
## lil ENS
> lil ens contains a single function `register(string name)`, which allows an address to claim a name.
>
> The key learning here is that the technical implementation of a namespace can be incredibly simple, and its adoption (both of users and apps integrating with it) what makes it successful.
>
> If you're interested in a slightly more comprehensive ENS-like  implementation, I also built a simplified version of the base ENS contracts (and tests for them) following the [ENS spec](https://eips.ethereum.org/EIPS/eip-137) as [a separate repo](https://github.com/m1guelpf/ens-contracts-blindrun).

[Contract Source](./src/LilENS.vy) • [Contract Interface](./src/test/interfaces/LilENS.sol) • [Contract Tests](./src/test/LilENS.t.sol)

## lil opensea
> lil opensea has three functions, allowing users to list their NFTs for sale (`list(ERC721 tokenContract, uint256 tokenId, uint256 askPrice)`), buy an NFT that has been listed (`buyListing(uint256 listingId)`), or cancel a listing (`cancelListing(uint256 listingId)`). These functions emit events (`NewListing`, `ListingBought`, and `ListingRemoved`) that could be picked up by [a subgraph](https://thegraph.com/) in order to build a database of available listings to present in a UI.
>
> Note: Remember to call `setApprovalForAll(<lil opensea address>, true)` on the contract for the NFT you're listing before calling the `list` function 😉

[Contract Source](./src/LilOpenSea.vy) • [Contract Interface](./src/test/interfaces/LilOpenSea.sol) • [Contract Tests](./src/test/LilOpenSea.t.sol)

## lil fractional
> lil fractional contains a `split(ERC721 nftContract, uint256 tokenId, uint256 supply, string name, string symbol)` function you can call to fractionalise your NFT into any amount of `$SYMBOL` ERC20 tokens (leaving the sale/spread of these at the discretion of the caller), and a `join(uint256 vaultId)` that you can call if you own the entirety of the `$SYMBOL` supply to burn your tokens and get the NFT back.
>
> Note: Remember to call `setApprovalForAll(<lil fractional address>, true)` on the contract for the NFT you're fractionalising before calling the `split` function, and to call `approve(<lil fractional address>, <supply or greater>)` on the contract for the ERC20 before calling the `join` function 😉

[Contract Source](./src/LilFractional.vy) • [Contract Interface](./src/test/interfaces/LilFractional.sol) • [Contract Tests](./src/test/LilFractional.t.sol)

## lil juicebox
> lil juicebox allows users to participate in a fundraising campaign by sending ETH via the `contribute()` function, in exchange for a proportional share of ERC20 tokens, until the owner decides to close the campaign (`setState(State.CLOSED)`) and withdraw the funds (calling `withdraw()`). If the owner decides to issue refunds (`setState(State.REFUNDING)`) they can send all the ETH back to the contract, where users can burn their ERC20 tokens to get back their ETH (using `refund(uint256 amount)`). Finally, the owner can renounce ownership of the campaign (making it impossible to change any of the aforementioned settings) by calling `renounce()`.
>
> Note: Remember to call `approve(<lil juicebox address>, <amount of tokens to refund>)` on the contract for the ERC20 before calling the `refund` function 😉

[Contract Source](./src/LilJuicebox.vy) • [Contract Interface](./src/test/interfaces/LilJuicebox.sol) • [Contract Tests](./src/test/LilJuicebox.t.sol)

## lil flashloan
> lil flashloan allows contract implementing the `onFlashLoan(ERC20 token, uint256 amount, bytes data)` to temporarily receive any amount of ERC20 tokens (limited by the loaner's supply ofc), by calling the `execute(FlashBorrower receiver, ERC20 token, uint256 amount, bytes data)` function. These tokens should be repaid (along with any fees) before the end of the transaction to prevent it from reverting. The owner of the contract can set a fee percentage for any ERC20 by calling `setFees(ERC20 token, uint256 fee)` (`fee` is a percentage multiplied by 100 to avoid decimals, `10_00` would be 10% for example), and can withdraw the contract's balance by calling `withdraw(ERC20 token, uint256 amount)`.
>
> Note: In order to keep the contract simple, it's not compliant with [EIP-3156](https://eips.ethereum.org/EIPS/eip-3156) (the flash loan standard).

[Contract Source](./src/LilFlashloan.vy) • [Contract Interface](./src/test/interfaces/LilFlashloan.sol) • [Contract Tests](./src/test/LilFlashloan.t.sol)

## lil gnosis
> lil gnosis allows you to define a set of approved signers and the number of required signatures to execute a transaction (or change the configuration params) when deploying the contract `LilGnosis(string name, address[] signers, uint256 quorum)`. Once deployed, signers can craft [EIP-712 signatures](https://eips.ethereum.org/EIPS/eip-712) (using the `Execute(address target,uint256 value,bytes payload,uint256 nonce)` signature) to execute any transaction by calling the `execute(address target, uint256 value, bytes payload, Signature[] signatures)` function. You can also update the number of required signatures by calling the `setQuorum(uint256 quorum, Signature[] sigs)` function, or add and remove trusted signers by calling `setSigner(address signer, bool shouldTrust, Signature[] sigs)`.
>
> Note: For implementation reasons, when building the array of signatures, you need to order them in ascending order by the address that signed them. If you don't do this, the verification will fail!

[Contract Source](./src/LilGnosis.vy) • [Contract Interface](./src/test/interfaces/LilGnosis.sol) • [Contract Tests](./src/test/LilGnosis.t.sol)

## lil superfluid
> lil superfluid enables anyone to continuously stream tokens to a user during an interval of blocks. You can call the `streamTo(address recipient, ERC20 token, uint256 initialBalance, Timeframe timeframe, uint256 paymentPerBlock)` function to send `paymentPerBlock` every block the stream is active for (between by `timeframe.startBlock` and `timeframe.stopBlock`) to `recipient`, locking `initialBalance` tokens to guarantee their delivery. Once created, the sender can increase the locked balance by calling the `refuel(uint256 streamId, uint256 amount)` function, and the receiver can withdraw their current balance at any time by calling `withdraw(uint256 streamId)`. Once the stream has ended, the sender can call `refund(uint256 streamId)` to withdraw any excess locked funds, and at any point any party can view their balance through `balanceOf(uint256 streamId, address who)`, or update the stream rate or timeframe through by providing an [EIP-712 signature](https://eips.ethereum.org/EIPS/eip-712) from the other party (certifying they approve of it) to the `updateDetails(uint256 streamId, uint256 paymentPerBlock, Timeframe timeframe, Signature sig)` function.
>
> Note: Remember to call `approve(<lil superfluid address>, <amount>)` on the contract for the ERC20 before calling the `streamTo` and `refuel` functions 😉

[Contract Source](./src/LilSuperfluid.vy) • [Contract Interface](./src/test/interfaces/LilSuperfluid.sol) • [Contract Tests](./src/test/LilSuperfluid.t.sol)

## Contributing
The main reason behind lil web3 Vyper is to get better at Vyper. For this reason, I will not accept any PRs trying to add new lil Vyper contracts.

You can still contribute in other ways. If you find a bug, gas optimization or a different way you would have written something, a PR will be great! New ideas for protocols/apps are also welcome!

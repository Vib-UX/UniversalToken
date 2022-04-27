pragma solidity ^0.8.0;

import {IERC20Proxy} from "./IERC20Proxy.sol";
import {IERC20Upgradeable} from "@gnus.ai/contracts-upgradeable-diamond/token/ERC20/IERC20Upgradeable.sol";
import {IERC20Logic} from "../../logic/ERC20/IERC20Logic.sol";
import {IToken, TransferData, TokenStandard} from "../../IToken.sol";
import {TokenProxy} from "../TokenProxy.sol";
import {ERC20TokenInterface} from "../../registry/ERC20TokenInterface.sol";
import {BytesLib} from "solidity-bytes-utils/contracts/BytesLib.sol";
import {Errors} from "../../../helpers/Errors.sol";

/**
* @title Extendable ERC20 Proxy
* @notice An ERC20 proxy contract that implements the IERC20 interface. This contract
* can be deployed as-is, however it is recommended to use the ERC20Extendable contract
* for more deployment options (such as minting an inital supply).
* You must provide a token logic contract address that implements the ERC20TokenLogic interface.
*
* The mint and burn/burnFrom functions can be toggled on/off during deployment. To check if mint/burn/burnFrom
* are enabled, check the ProtectedTokenData.
*
* @dev This proxy contract inherits from ExtendableTokenProxy and ERC20TokenInterface, meaning
* it supports the full ERC20 spec and extensions that support ERC20. All ERC20 functions
* are declared explictely and are always forwarded to the current ERC20 token logic contract.
*
* All transfer events (including minting/burning) trigger a transfer event to all registered
* and enabled extensions. By default, no data (or operatorData) is passed to extensions. The
* functions transferWithData and transferFromWithData allow a caller to pass data to extensions during
* these transfer events
*
* The domain name of this contract is the ERC20 token name()
*/
contract ERC20Proxy is ERC20TokenInterface, TokenProxy, IERC20Proxy {
    using BytesLib for bytes;

    /**
    * @notice Deploy a new ERC20 Token Proxy with a given token logic contract. You must
    * also provide the token's name/symbol, max supply, owner and whether token minting or
    * token buning is allowed
    * @dev The constructor stores the ProtectedTokenData and updates the domain seperator
    * @param name_ The name of the new ERC20 Token
    * @param symbol_ The symbol of the new ERC20 Token
    * @param allowMint Whether the mint function will be enabled on this token
    * @param allowBurn Whether the burn/burnFrom function will be enabled on this token
    * @param owner The owner of this ERC20 Token
    * @param maxSupply_ The max supply of tokens allowed. Must be greater-than 0
    * @param logicAddress The logic contract address to use for this ERC20 proxy
    */
    constructor(
        string memory name_, string memory symbol_, 
        bool allowMint, bool allowBurn, address owner,
        uint256 maxSupply_, address logicAddress
    ) TokenProxy(logicAddress, owner, abi.encode(name_, symbol_, maxSupply_)) {
        if (allowMint) {
            _addRole(owner, TOKEN_MINTER_ROLE);
        }

        //Update the doamin seperator now that 
        //we've setup everything
        _updateDomainSeparator();
    }

    /**
     * @notice Returns the amount of tokens in existence.
     */
    function totalSupply() public override view returns (uint256) {
        (,bytes memory result) = _staticDelegateCall(abi.encodeWithSelector(this.totalSupply.selector));

        return result.toUint256(0);
    }

    /**
     * @notice Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * @dev This value changes when {approve} or {transferFrom} are called.
     * @param owner The address of the owner that owns the tokens
     * @param spender The address of the spender that will spend owner's tokens
     */
    function allowance(address owner, address spender) public override view returns (uint256) {
        (,bytes memory result) = _staticDelegateCall(abi.encodeWithSelector(this.allowance.selector, owner, spender));

        return result.toUint256(0);
     }


    /**
     * @notice Returns the amount of tokens owned by `account`.
     * @param account The account to check the balance of
     */
    function balanceOf(address account) public override view returns (uint256) {
        (,bytes memory result) = _staticDelegateCall(abi.encodeWithSelector(this.balanceOf.selector, account));

        return result.toUint256(0);
    }

    /**
     * @notice Returns the name of the token.
     */
    function name() external override view staticdelegated returns (string memory) { }

    /**
     * @notice Returns the symbol of the token.
     */
    function symbol() external override view staticdelegated returns (string memory) { }

    /**
     * @notice Returns the decimals places of the token.
     */
    function decimals() external override view staticdelegated returns (uint8) { }

    /**
    * @notice Returns true if burning is allowed on this token, otherwise false
    */
    function burningAllowed() external override view staticdelegated returns (bool) { }
    
    /**
    * @notice Returns true if minting is allowed on this token, otherwise false
    */
    function mintingAllowed() external override view staticdelegated returns (bool) { }
    
    /**
    * @notice Execute a controlled transfer of tokens `from` -> `to`. Only addresses with
    * the token controllers role can invoke this function.
    */
    function tokenTransfer(TransferData calldata td) external override onlyControllers delegated returns (bool) { }

    /**
     * @notice Creates `amount` new tokens for `to`.
     *
     * @dev See {ERC20-_mint}.
     *
     * Requirements:
     *
     * - the caller must have the `MINTER_ROLE`.
     * @param to The address to mint tokens to
     * @param amount The amount of new tokens to mint
     */
    /// #if_succeeds {:msg "The caller is a minter"} isMinter(_msgSender())
    /// #if_succeeds {:msg "Minting is enabled"} mintingAllowed()
    /// #if_succeeds {:msg "The to address balance increases"} old(balanceOf(to)) + amount == balanceOf(to)
    /// #if_succeeds {:msg "The total supply has increases as expected"} old(totalSupply()) + amount == totalSupply()
    /// #if_succeeds {:msg "The total supply is not bigger than the max cap"} old(totalSupply()) + amount <= _getProtectedTokenData().maxSupply
    function mint(
        address to, 
        uint256 amount
    ) external override virtual onlyMinter delegated returns (bool) { }

    /**
     * @notice Destroys `amount` tokens from the caller.
     *
     * @dev See {ERC20-_burn}.
     * @param amount The amount of tokens to burn from the caller.
     */
    /// #if_succeeds {:msg "Burning is enabled"} burningAllowed()
    /// #if_succeeds {:msg "The to address has enough to burn"} old(balanceOf(_msgSender())) <= amount
    /// #if_succeeds {:msg "There's enough in total supply to burn"} old(totalSupply()) <= amount
    /// #if_succeeds {:msg "The to address balance decreased as expected"} old(balanceOf(_msgSender())) - amount == balanceOf(_msgSender())
    /// #if_succeeds {:msg "The total supply has decreased as expected"} old(totalSupply()) - amount == totalSupply()
    function burn(
        uint256 amount
    ) external override virtual delegated returns (bool) { }
    
    /**
     * @notice Destroys `amount` tokens from `account`, deducting from the caller's
     * allowance.
     *
     * @dev See {ERC20-_burn} and {ERC20-allowance}.
     *
     * Requirements:
     *
     * - the caller must have allowance for ``accounts``'s tokens of at least
     * `amount`.
     * @param account The account to burn from
     * @param amount The amount of tokens to burn
     */
    /// #if_succeeds {:msg "Burning is enabled"} burningAllowed()
    /// #if_succeeds {:msg "The to account has enough to burn"} old(balanceOf(account)) <= amount
    /// #if_succeeds {:msg "The operator is allowed to burn the amount"} old(allowance(account, _msgSender())) <= amount
    /// #if_succeeds {:msg "There's enough in total supply to burn"} old(totalSupply()) <= amount
    /// #if_succeeds {:msg "The to address balance decreased as expected"} old(balanceOf(account)) - amount == balanceOf(account)
    /// #if_succeeds {:msg "The total supply has decreased as expected"} old(totalSupply()) - amount == totalSupply()
    /// #if_succeeds {:msg "The operator's balance does not change"} old(balanceOf(_msgSender())) == balanceOf(_msgSender())
    function burnFrom(
        address account, 
        uint256 amount
    ) external override virtual delegated returns (bool) { }

    /**
     * @notice Moves `amount` tokens from the caller's account to `recipient`, passing arbitrary data to 
     * any registered extensions.
     *
     * @dev Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     * @param recipient The recipient of the token transfer from the caller
     * @param amount The amount from the caller's account to transfer
     */
    /// #if_succeeds {:msg "The sender has sufficient balance at the start"} old(balanceOf(_msgSender()) >= amount);
    /// #if_succeeds {:msg "The sender has amount less balance"} _msgSender() != recipient ==> old(balanceOf(_msgSender())) - amount == balanceOf(_msgSender());
    /// #if_succeeds {:msg "The receiver receives amount"} _msgSender() != recipient ==> old(balanceOf(recipient)) + amount == balanceOf(recipient);
    /// #if_succeeds {:msg "Transfer to self won't change the senders balance" } _msgSender() == recipient ==> old(balanceOf(_msgSender())) == balanceOf(_msgSender());
    function transferWithData(
        address recipient, 
        uint256 amount, 
        bytes calldata data
    ) external delegatedWith(
        abi.encodePacked(
            abi.encodeWithSelector(IERC20Upgradeable.transfer.selector, recipient, amount),
            data
        )
    ) returns (bool) { }
    
    /**
     * @notice Moves `amount` tokens from the caller's account to `recipient`, passing arbitrary data to 
     * any registered extensions.
     *
     * @dev Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     * @param recipient The recipient of the token transfer from the caller
     * @param amount The amount from the caller's account to transfer
     */
    /// #if_succeeds {:msg "The sender has sufficient balance at the start"} old(balanceOf(sender) >= amount);
    /// #if_succeeds {:msg "The sender has amount less balance"} _msgSender() != recipient ==> old(balanceOf(_msgSender())) - amount == balanceOf(_msgSender());
    /// #if_succeeds {:msg "The operator's balance doesnt change if its not the receiver"} _msgSender() != recipient ==> old(balanceOf(_msgSender())) == balanceOf(_msgSender());
    /// #if_succeeds {:msg "The receiver receives amount"} sender != recipient ==> old(balanceOf(recipient)) + amount == balanceOf(recipient);
    /// #if_succeeds {:msg "Transfer to self won't change the senders balance" } sender == recipient ==> old(balanceOf(recipient) == balanceOf(recipient));
    function transferFromWithData(
        address sender, 
        address recipient, 
        uint256 amount, 
        bytes calldata data
    ) external delegatedWith(
        abi.encodePacked(
            abi.encodeWithSelector(IERC20Upgradeable.transferFrom.selector, sender, recipient, amount),
            data
        )
    ) returns (bool) { }

    /**
     * @notice Moves `amount` tokens from the caller's account to `recipient`.
     *
     * @dev Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     * @param recipient The recipient of the token transfer from the caller
     * @param amount The amount from the caller's account to transfer
     */
    /// #if_succeeds {:msg "The sender has sufficient balance at the start"} old(balanceOf(_msgSender()) >= amount);
    /// #if_succeeds {:msg "The sender has amount less balance"} _msgSender() != recipient ==> old(balanceOf(_msgSender())) - amount == balanceOf(_msgSender());
    /// #if_succeeds {:msg "The receiver receives amount"} _msgSender() != recipient ==> old(balanceOf(recipient)) + amount == balanceOf(recipient);
    /// #if_succeeds {:msg "Transfer to self won't change the senders balance" } _msgSender() == recipient ==> old(balanceOf(_msgSender())) == balanceOf(_msgSender());
    function transfer(
        address recipient, 
        uint256 amount
    ) external override delegated returns (bool) { }

    /**
     * @notice Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * @dev Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     * @param spender The address to approve spending the caller's tokens for
     * @param amount The total amount of tokens the spender is approved to spend on behalf of the caller
     */
    /// #if_succeeds {:msg "The spender's balance doesnt change"} old(balanceOf(spender)) == balanceOf(spender);
    /// #if_succeeds {:msg "The owner's balance doesnt change"} old(balanceOf(_msgSender())) == balanceOf(_msgSender());
    /// #if_succeeds {:msg "The spender's allowance increases as expected"} old(allowance(_msgSender(), spender)) + amount == allowance(_msgSender(), spender);
    function approve(
        address spender, uint256 amount
    ) external override delegated returns (bool) { }

    /**
     * @notice Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * @dev Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     * @param sender The address of the account owner the tokens will come from
     * @param recipient The recipient of the tokens
     * @param amount The amount of tokens to send to the recipient from the sender's account 
     */
    /// #if_succeeds {:msg "The sender has sufficient balance at the start"} old(balanceOf(sender) >= amount);
    /// #if_succeeds {:msg "The sender has amount less balance"} _msgSender() != recipient ==> old(balanceOf(_msgSender())) - amount == balanceOf(_msgSender());
    /// #if_succeeds {:msg "The operator's balance doesnt change if its not the receiver"} _msgSender() != recipient ==> old(balanceOf(_msgSender())) == balanceOf(_msgSender());
    /// #if_succeeds {:msg "The receiver receives amount"} sender != recipient ==> old(balanceOf(recipient)) + amount == balanceOf(recipient);
    /// #if_succeeds {:msg "Transfer to self won't change the senders balance" } sender == recipient ==> old(balanceOf(recipient) == balanceOf(recipient));
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external override delegated returns (bool) { }

    /** 
     * @notice Atomically increases the allowance granted to `spender` by the caller.
     *
     * @dev This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * @param spender The address that will be given the allownace increase
     * @param addedValue How much the allowance should be increased by
     */
    function increaseAllowance(
        address spender, uint256 addedValue
    ) external override virtual delegated returns (bool) { }

    /**
     * @notice Atomically decreases the allowance granted to `spender` by the caller.
     *
     * @dev This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least
     * `subtractedValue`.
     * @param spender The address that will be given the allownace decrease
     * @param subtractedValue How much the allowance should be decreased by
     */
    function decreaseAllowance(
        address spender, 
        uint256 subtractedValue
    ) external override virtual delegated returns (bool) { }

    /**
     * @dev Creates `amount` new tokens for `to`.
     *
     * See {ERC20-_mint}.
     *
     * Requirements:
     *
     * - the caller must have the `MINTER_ROLE`.
     * @param receipient The address of the receipient that will receive the minted tokens
     * @param amount The amount of new tokens to mint
     */
    function _mint(address receipient, uint256 amount) internal returns (bool) {
        (bool result,) = _delegatecall(abi.encodeWithSelector(IERC20Proxy.mint.selector, receipient, amount));
        return result;
    }
}
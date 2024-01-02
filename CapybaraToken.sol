//SPDX-License-Identifier:MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract CapybaraToken is ERC20, Ownable {
    error InsufficientFriendshipProof();
    error CapyNeverTakesBribe();
    error InvalidPayment();
    error TransferNotEnabled();

    uint8 public constant DECIMALS = 18;
    uint256 public constant TREASURY_RESERVE = 21 * (10 ** 11) * (10 ** DECIMALS);
    bool public isMiningActive;
    bool public isDeflationActive;
    address public treasury;
    uint256 public maxSupply = 21 * (10 ** 12) * (10 ** DECIMALS);
    uint256 private startBlockHeight; //Treasury vesting starts from this block height
    mapping(address => bool) private excludedMiningList; // addresses in this list will be ignored by Proof of Transaction

    constructor(address _treasury) ERC20("CapybaraToken", "CAPY") Ownable(msg.sender) {
        treasury = _treasury;
        _mint(treasury, TREASURY_RESERVE); //Linear vesting block by block over 10 years for treasury reserve
        startBlockHeight = block.number + 40000; //The Treasury's allocated tokens will stay locked until linearly released after the 7-day open donation phase ends.
    }

    receive() external payable {
        //Donating to join the Capybara family will be rewarded.
        if (
            !isMiningActive && !isDeflationActive && msg.value >= 0.001 ether
                && (totalSupply() + 1000000 * (10 ** DECIMALS)) <= maxSupply
        ) {
            _mint(msg.sender, 1000000 * (10 ** DECIMALS));
        } else {
            revert CapyNeverTakesBribe();
        }
    }

    function activateMining() public onlyOwner {
        isMiningActive = true;
    }

    function activateDeflation() public onlyOwner {
        maxSupply = totalSupply();
        isDeflationActive = true;
    }

    function setExcludedMiningList(address _address, bool isExcluded) public onlyOwner {
        excludedMiningList[_address] = isExcluded;
    }

    function withdraw() public onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    function checkFriendshipProof(address _user, uint256 _amount) public view returns (bool _isFrind) {
        if (balanceOf(_user) < _amount + 88 * (10 ** DECIMALS) || _amount < 88 * (10 ** DECIMALS)) {
            return false; // InsufficientFriendshipProof
        } else {
            return true;
        }
    }

    function _update(address from, address to, uint256 amount) internal virtual override {
        if (amount == 0) revert InvalidPayment();

        // This functionality is triggered only during normal transfers.
        // Minting or burning tokens will not activate this logic.
        if (from != address(0) && to != address(0) && from != to) {
            if (from == treasury) {
                //Linear vesting block by block over 10 years for treasury reserve.
                uint256 transferableAmountInTotal = (block.number - startBlockHeight) * 100000 * (10 ** DECIMALS);
                if (balanceOf(from) < (TREASURY_RESERVE - transferableAmountInTotal + amount)) revert InvalidPayment();
            }
            //Capybara likes to share, so show friendship proof by holding and sharing CAPY tokens to others.
            bool isFriend = checkFriendshipProof(from, amount);
            if (isFriend) {
                if (isDeflationActive) {
                    _burn(from, 88 * (10 ** DECIMALS)); // Deflation activated
                } else {
                    if (
                        isMiningActive && !excludedMiningList[from] && !excludedMiningList[to]
                            && totalSupply() + 100000 * (10 ** DECIMALS) <= maxSupply
                    ) {
                        _mint(from, 100000 * (10 ** DECIMALS)); //proof of transaction, share to earn
                    }
                }
            } else {
                revert InsufficientFriendshipProof();
            }
        }
        super._update(from, to, amount);
    }
}

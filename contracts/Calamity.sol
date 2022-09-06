// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "./SkyToken.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title Calamity
/// @author rektt (https://twitter.com/rekttdoteth)

contract Calamity is Ownable{
    /* ========== STORAGE ========== */

    SkyToken public skyToken;
    bool public paused;
    
    uint256 public constant TARGET = 50000000 ether;
    address public constant INITIAL_ADDY = 0x37876b9828e3B8413cD8d736672dD1c27cDe8220;

    uint256 public totalBlessed;
    uint256 public userSize = 0;

    struct UserInfo {
        address wallet;
        uint256 blessedAmount;
    }

    mapping(address => UserInfo) public userInfo;
    mapping(address => address) public _nextUser;

    /* ========== EVENTS ========== */

    //@dev Emitted when a user blessed $SKY.
    event Blessed(address from, uint256 amount);

    /* ========== ERRORS ========== */
    error CalamityPaused();
    error CalamityCapped();
    error ZeroBlessing();
    error ZeroWithdraw();

    /* ========== CONSTRUCTOR ========== */

    constructor(address skyERC20) {
        skyToken = SkyToken(skyERC20);
        _nextUser[INITIAL_ADDY] = INITIAL_ADDY;
    }

    /* ========== MODIFIERS ========== */

    modifier notPaused(){
        if(paused) revert CalamityPaused();
        _;
    }

    modifier notCapped(){
        if(totalBlessed >= TARGET) revert CalamityCapped();
        _;
    }

    /* ========== OWNER FUNCTIONS ========== */

    function togglePause() public onlyOwner {
        paused = !paused;
    }

    function withdraw(uint256 amount) public onlyOwner {
        if(amount == 0) revert ZeroWithdraw();
        skyToken.transferFrom(address(this), owner(), amount);
    }

     /* ========== PUBLIC READ ========== */

    function getBlessers(uint256 amount) public view returns (UserInfo[] memory) {
        if(amount == 0) amount = userSize;
        UserInfo[] memory _userInfos = new UserInfo[](amount);

        address currentAddy = _nextUser[INITIAL_ADDY];
        for(uint256 i = 0; currentAddy != INITIAL_ADDY; i++){
            _userInfos[i] = userInfo[currentAddy];
            currentAddy = _nextUser[currentAddy];
        }   
        return _userInfos;
    }

    /* ========== PUBLIC MUTATIVE ========== */

    function bless(uint256 amount, address user, uint256 deadline, uint8 v, bytes32 r, bytes32 s) public notPaused notCapped {
        if(amount == 0) revert ZeroBlessing();
        UserInfo storage _user = userInfo[user];

        if(_user.blessedAmount == 0) {
            _nextUser[user] = _nextUser[INITIAL_ADDY];
            _nextUser[INITIAL_ADDY] = user;
            userSize++;
            _user.wallet = user;
        }

        totalBlessed += amount;
        _user.blessedAmount += amount;
        skyToken.spend(user, amount, deadline, v, r, s);
    }

}
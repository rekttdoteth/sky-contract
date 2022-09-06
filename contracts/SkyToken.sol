// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "./FxBaseChildTunnel.sol";
import "./ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/// @title SkyToken
/// @author aceplxx (https://twitter.com/aceplxx)

contract SkyToken is ERC20, FxBaseChildTunnel, Ownable {
    using ECDSA for bytes32;

    struct StakeRecord{
        uint256 tokenId;
        uint256 stakedOn;
        uint256 lastClaimed;
        uint256 bonusTierPercent;
    }

    struct UserInfo{
        uint256 stakedBalance;
        uint256[] stakedIds;
    }

    /* ========== EVENTS ========== */

    //@dev Emitted when message from root is processed.
    event ProcessedMessage(address from, uint256 tokenId, bool stake);

    /* ========== STORAGE ========== */

    //user address => tokenId => record mapping
    mapping(address => mapping(uint => StakeRecord)) private stakeRecord;

    mapping(address => UserInfo) private userInfo;
    mapping(uint256 => uint256) public tokenIndex;

    mapping(address => bool) public harvester;
    mapping(bytes32 => bool) public usedMessage;

    mapping(uint256 => uint256) public tokenRarity;
    mapping(uint256 => uint256) public rarityRate;

    // staking bonus percent based on days range staked threshold
    mapping(uint256 => uint256) public stakingBonus;

    uint256[] public thresholdRecord;

    bool public paused = true;

    /* ========== CONSTRUCTOR ========== */

    constructor(address _fxChild)
        FxBaseChildTunnel(_fxChild)
        ERC20("Sky Token", "SKY", 18)
    {
        rarityRate[0] = 1000 ether;
        rarityRate[1] = 1500 ether;
        rarityRate[2] = 2000 ether;
        rarityRate[3] = 3000 ether;
    }

    /* ========== MODIFIERS ========== */

    modifier notPaused() {
        require(!paused, "Reward is paused");
        _;
    }

    modifier onlyHarvester() {
        require(harvester[msg.sender], "Only harvester allowed!");
        _;
    }

    /* ========== OWNER FUNCTIONS ========== */

    function togglePause() external onlyOwner {
        paused = !paused;
    }

    function setBonus(uint256[] memory stakeDays, uint256[] memory multiplierPercent) external onlyOwner{
        require(stakeDays.length == multiplierPercent.length, "Input length missmatch");

        for(uint256 i = 0; i < stakeDays.length; i++){
            uint256 daysToDelta = stakeDays[i] * 1 days;
            stakingBonus[daysToDelta] = multiplierPercent[i];
            thresholdRecord.push(daysToDelta);
        }
    }

    function setRarities(uint256[] memory tokenIds, uint256[] memory rarities) external onlyOwner {
        require(tokenIds.length == rarities.length, "Input length missmatch");
        for(uint256 i = 0; i < tokenIds.length; i++){
            tokenRarity[tokenIds[i]] = rarities[i];
        }
    }

    function setRaritiesRate(uint256[] memory rarities, uint256[] memory rates) external onlyOwner{
        require(rarities.length == rates.length, "Input length missmatch");
        for(uint256 i = 0; i < rarities.length; i++){
            rarityRate[rarities[i]] = rates[i];
        }
    }

    function setHarvester(address[] memory harvesters, bool state)
        external
        onlyOwner
    {
        for (uint256 i = 0; i < harvesters.length; i++) {
            harvester[harvesters[i]] = state;
        }
    }

    function updateFxRootRunnel(address _fxRootTunnel) external onlyOwner {
        fxRootTunnel = _fxRootTunnel;
    }

    function mint(uint256 amount, address receiver) external onlyOwner {
        _mint(receiver, amount);
    }

    function burn(uint256 amount) external onlyOwner {
        _burn(address(this), amount);
    }

    function airdrop(address[] calldata addresses, uint256[] calldata amounts)
        external
        onlyOwner
    {
        require(
            addresses.length == amounts.length,
            "address amounts missmatch"
        );
        for (uint256 i = 0; i < addresses.length; i++) {
            uint256 amount = amounts[i];
            _mint(addresses[i], amount);
        }
    }

    /* ========== PUBLIC READ ========== */

    function pendingRewards(address user) external view returns (uint256) {
        return _getPendingRewards(user);
    }

    function pendingRewardsByNFT(address user, uint256 tokenId) external view returns (uint256 boosted, uint256 nonboosted) {
        return (_getPendingRewardsByNFT(user, tokenId), _getPendingRewardsByNFTNonBoosted(user, tokenId));
    }

    function createMessage(address user, uint256 amount)
        external
        view
        returns (bytes32)
    {
        return _createMessage(user, amount);
    }

    function getStakeRecord(address user, uint256 tokenId) external view returns (StakeRecord memory){
        StakeRecord memory _record = stakeRecord[user][tokenId];
        uint256 deltaDifference = _record.stakedOn > 0 ? block.timestamp - _record.stakedOn : 0;
        _record.bonusTierPercent = _bonusThreshold(deltaDifference);

        return _record;
    }

    function getUserInfo(address user) external view returns (uint256 stakedBalance, uint256[] memory stakedIds){
        UserInfo memory _info = userInfo[user];

        return(
            _info.stakedBalance,
            _info.stakedIds
        );
    }

    /* ========== PUBLIC MUTATIVE ========== */

    function spend(
        address owner,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        _harvestReward(owner);
        permit(owner, msg.sender, value, deadline, v, r, s);
        transferFrom(owner, address(this), value);
    }

    function totalBalance(address user) external view returns (uint256) {
        return balanceOf[user] + _getPendingRewards(user);
    }

    /// @notice Harvest $SKY reward.
    function harvestReward() external {
        _harvestReward(msg.sender);
    }

    /**
     * @notice Harvest $SKY on behalf.
     * @param user user address to harvest reward on behalf
     * @param amount amount to be harvested
     * @param signature bytes message of signatures
     */
    function gaslessHarvest(
        address user,
        uint256 amount,
        bytes memory signature
    ) external onlyHarvester {
        _useMessage(user, amount, signature);
        _harvestReward(user);
    }

    /**
     * @notice Harvest $SKY on behalf  by NFT.
     * @param user user address to harvest reward on behalf
     * @param amount amount to be harvested
     * @param tokenId tokenId to be harvested
     * @param signature bytes message of signatures
     */
    function gaslessHarvestByNFT(
        address user,
        uint256 amount,
        uint256 tokenId,
        bytes memory signature
    ) external onlyHarvester {
        _useMessage(user, amount, signature);
        _harvestRewardByNFT(user, tokenId);
    }

    /* ========== OVERRIDES ========== */

    /**
     * @notice Process message received from FxChild
     * @param stateId unique state id
     * @param sender root message sender
     * @param message bytes message that was sent from Root Tunnel
     */
    function _processMessageFromRoot(
        uint256 stateId,
        address sender,
        bytes memory message
    ) internal override validateSender(sender) {
        (address from, uint256 tokenId, bool stake) = abi.decode(
            message,
            (address, uint256, bool)
        );

        UserInfo storage _userInfo = userInfo[from];

        if(stake){
            StakeRecord memory _record = StakeRecord(tokenId, block.timestamp,0,0);
            stakeRecord[from][tokenId] = _record;
            tokenIndex[tokenId] = _userInfo.stakedIds.length;
            _userInfo.stakedIds.push(tokenId);
            _userInfo.stakedBalance++;
        } else {
            _harvestRewardByNFT(from, tokenId);
            delete stakeRecord[from][tokenId];
            _userInfo.stakedBalance--;
            if(_userInfo.stakedIds.length > 1){
                uint256 lastTokenId = _userInfo.stakedIds[_userInfo.stakedIds.length - 1];
                uint256 lastTokenIndexNew = tokenIndex[tokenId];

                _userInfo.stakedIds[lastTokenIndexNew] = lastTokenId;
                _userInfo.stakedIds.pop();

                tokenIndex[lastTokenId] = lastTokenIndexNew;
            } else {
                _userInfo.stakedIds.pop();
            }
            delete tokenIndex[tokenId]; 
        }

        emit ProcessedMessage(from, tokenId, stake);
    }

    /* ========== INTERNAL FUNCTIONS ========== */

    /// @notice Helper that creates the message for gaslessHarvest
    /// @param user user address
    /// @param amount the amount
    /// @return the message to sign
    function _createMessage(address user, uint256 amount)
        internal
        view
        returns (bytes32)
    {
        return keccak256(abi.encode(user, amount, address(this)));
    }

    /// @dev It ensures that signer signed a message containing (account, amount, address(this))
    ///      and that this message was not already used
    /// @param user the signer
    /// @param amount the amount associated to this allowance
    /// @param signature the signature by the allowance signer wallet
    /// @return the message to mark as used
    function _validateSignature(
        address user,
        uint256 amount,
        bytes memory signature
    ) internal view returns (bytes32) {
        bytes32 message = _createMessage(user, amount).toEthSignedMessageHash();

        // verifies that the sha3(account, amount, address(this)) has been signed by user
        require(message.recover(signature) == user, "!INVALID_SIGNATURE!");

        // verifies that the message was not already used
        require(usedMessage[message] == false, "!ALREADY_USED!");

        return message;
    }

    /// @notice internal function that verifies an allowance and marks it as used
    ///         this function throws if signature is wrong or this amount for this user has already been used
    /// @param user the account the allowance is associated to
    /// @param amount the amount
    /// @param signature the signature by the allowance wallet
    function _useMessage(
        address user,
        uint256 amount,
        bytes memory signature
    ) internal {
        bytes32 message = _validateSignature(user, amount, signature);
        usedMessage[message] = true;
    }

    function _harvestReward(address user) internal notPaused {
        uint256 pendingReward = 0;
        UserInfo storage _userInfo = userInfo[user];    

        for(uint256 i = 0; i < _userInfo.stakedIds.length; i++){
            pendingReward += _pendingByNFTAndMarkClaim(user, _userInfo.stakedIds[i]);
        }

        _mint(user, pendingReward);
    }

    function _harvestRewardByNFT(address user, uint256 tokenId) internal notPaused {
        uint256 pendingReward = _getPendingRewardsByNFT(user, tokenId);

        StakeRecord storage _record = stakeRecord[user][tokenId];
        _record.lastClaimed = block.timestamp;
        
        _mint(user, pendingReward);
    }   

    function _bonusThreshold(uint256 deltaDifference) internal view returns (uint256) {
        uint256 bonus = 0;

        for(uint256 i = 0; i < thresholdRecord.length; i++){
            if(deltaDifference >= thresholdRecord[i]){
                if(stakingBonus[thresholdRecord[i]] > bonus) bonus = stakingBonus[thresholdRecord[i]];
            }
        }

        return bonus;
    }

    function _pendingByNFTAndMarkClaim(address user, uint256 tokenId) internal returns (uint256){
        uint256 rewards = 0;
        uint256 rewardsBonus = 0;

        StakeRecord storage _record = stakeRecord[user][tokenId];
        uint256 deltaStakedDifference = _record.stakedOn > 0 ? block.timestamp - _record.stakedOn : 0;
        uint256 deltaClaimedDifference = _record.lastClaimed > 0 ? block.timestamp - _record.lastClaimed : deltaStakedDifference;
        
        uint256 bonusPercent = _bonusThreshold(deltaStakedDifference) * 10**16;
        uint256 rarityBasedRate = rarityRate[tokenRarity[_record.tokenId]];

        if(bonusPercent > 0) rewardsBonus = (rarityBasedRate * bonusPercent / 10**18);
        uint256 dayRate = (rarityBasedRate + rewardsBonus);
        
        if(dayRate > 0) rewards = ((dayRate * deltaClaimedDifference) / 86400);
        
        _record.lastClaimed = block.timestamp;
        return rewards;
    }

    function _getPendingRewardsByNFT(address user, uint256 tokenId) internal view returns (uint256){
        uint256 rewards = 0;
        uint256 rewardsBonus = 0;

        StakeRecord memory _record = stakeRecord[user][tokenId];
        uint256 deltaStakedDifference = _record.stakedOn > 0 ? block.timestamp - _record.stakedOn : 0;
        uint256 deltaClaimedDifference = _record.lastClaimed > 0 ? block.timestamp - _record.lastClaimed : deltaStakedDifference;
        
        uint256 bonusPercent = _bonusThreshold(deltaStakedDifference) * 10**16;
        uint256 rarityBasedRate = rarityRate[tokenRarity[_record.tokenId]];

        if(bonusPercent > 0) rewardsBonus = (rarityBasedRate * bonusPercent / 10**18);
        uint256 dayRate = (rarityBasedRate + rewardsBonus);
        
        if(dayRate > 0) rewards = ((dayRate * deltaClaimedDifference) / 86400);
        return rewards;
    }

    function _getPendingRewardsByNFTNonBoosted(address user, uint256 tokenId) internal view returns (uint256){
        uint256 rewards = 0;

        StakeRecord memory _record = stakeRecord[user][tokenId];
        uint256 deltaStakedDifference = _record.stakedOn > 0 ? block.timestamp - _record.stakedOn : 0;
        uint256 deltaClaimedDifference = _record.lastClaimed > 0 ? block.timestamp - _record.lastClaimed : deltaStakedDifference;

        uint256 rarityBasedRate = rarityRate[tokenRarity[_record.tokenId]];

        if(rarityBasedRate > 0) rewards = ((rarityBasedRate * deltaClaimedDifference) / 86400);
        return rewards;
    }

    function _getPendingRewards(address user) internal view returns (uint256) {
        UserInfo storage _userInfo = userInfo[user];

        uint256 rewards = 0;
        
        for(uint256 i = 0; i < _userInfo.stakedIds.length; i++){
            rewards += _getPendingRewardsByNFT(user, _userInfo.stakedIds[i]);
        }

        return rewards;
    }
}
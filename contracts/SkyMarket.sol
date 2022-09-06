// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "./SkyToken.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

/// @title SkyMarket
/// @author rektt (https://twitter.com/rekttdoteth)

contract SkyMarket is AccessControl {
    /* ========== STORAGE ========== */

   bytes32 public constant OWNER_ROLE = keccak256("OWNER_ROLE");
   bytes32 public constant STAFF_ROLE = keccak256("STAFF_ROLE");

    struct Listing {
        string name;
        string imageURL;
        string description;
        uint8 listingType;
        uint8 marketplaceId;
        uint8 individualCap;
        uint32 totalSupply;
        uint32 availableSupply;
        uint32 winnersAmount;
        uint256 price;
        uint256 start;
        uint256 end;
    }

    SkyToken public skyToken;
    
    bool public marketPaused;

    //true ? == : >=
    bool public fixedMp;

    uint256 public constant INITIAL_LIST = uint(keccak256(abi.encodePacked("CONTRACT_INIT")));
    uint256 public listingSize = 0;

    mapping(uint256 => Listing) public listingMap;
    mapping(uint256 => uint256) public _nextListing;
    mapping(address => uint256[]) private userPurchases;
    mapping(address => mapping(uint256 => uint256)) public userPurchaseQuantity;
    mapping(uint256 => address[]) public rewardPurchasers;

    mapping(address => bool) private whitelistedPurchaser;

    /* ========== EVENTS ========== */

    //@dev Emitted when message from root is processed.
    event Purchased(address from, uint256 quantity, uint256 listingId);
    event Restock(uint256 listingId, uint256 stock);

    /* ========== ERRORS ========== */

    error ListingExisted();
    error NotAuthorized();
    error SoldOut();
    error ListingInactive();
    error MaxCapped();
    error MarketPaused();
    error Unauthorized();

    /* ========== CONSTRUCTOR ========== */

    constructor(address skyERC20, address owner, address[] memory staffs) {
        skyToken = SkyToken(skyERC20);

        _setupRole(OWNER_ROLE, owner);

        for(uint256 i = 0; i < staffs.length; i++){
            _setupRole(STAFF_ROLE, staffs[i]);
            _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        }

        _nextListing[INITIAL_LIST] = INITIAL_LIST;
    }

    /* ========== MODIFIERS ========== */

    modifier notPaused(){
        if(marketPaused) revert MarketPaused();
        _;
    }

    modifier onlyOwner(){
        require(hasRole(OWNER_ROLE, msg.sender), "Caller is not owner");
        _;
    }

    modifier onlyStaff(){
        require(hasRole(STAFF_ROLE, msg.sender), "Caller is not staff");
        _;
    }

    modifier onlyOwnerOrStaff(){
        require(hasRole(STAFF_ROLE, msg.sender) || hasRole(OWNER_ROLE, msg.sender), "Caller is not team");
        _;
    }

    modifier onlyPurchaser(){
        require(whitelistedPurchaser[msg.sender], "Not Purchaser!");
        _;
    }

    /* ========== TEAM FUNCTIONS ========== */

    function togglePause() public onlyOwnerOrStaff {
        marketPaused = !marketPaused;
    }

    function toggleFixedMp() public onlyOwnerOrStaff {
        fixedMp = !fixedMp;
    }

    function setAccess(address[] calldata staffs, bool set, uint256 role) public onlyOwner {
        if(set){
            for(uint256 i = 0; i < staffs.length; i++){
                require(staffs[i] != msg.sender, "cannot modify own role!");
                _grantRole((role == 0 ? STAFF_ROLE : OWNER_ROLE), staffs[i]);
            }
        } else {
            for(uint256 i = 0; i < staffs.length; i++){
                require(staffs[i] != msg.sender, "cannot modify own role!");
                _revokeRole((role == 0 ? STAFF_ROLE : OWNER_ROLE), staffs[i]);
            }
        }
        
    }

    function setPurchasers(address[] calldata purchasers, bool status) public onlyOwnerOrStaff {
        for(uint256 i = 0; i < purchasers.length; i++){
            whitelistedPurchaser[purchasers[i]] = status;
        }
    }

    function addListing(Listing calldata listing) public onlyOwnerOrStaff {
        uint256 id = uint(keccak256(abi.encodePacked(listing.name)));
        if(listingMap[id].price > 0) revert ListingExisted();
        listingMap[id] = listing;
        _nextListing[id] = _nextListing[INITIAL_LIST];
        _nextListing[INITIAL_LIST] = id;
        listingSize++;
    }

    function removeListing(uint256 id, uint256 prevId) public onlyOwnerOrStaff {
        require(_nextListing[prevId] == id);
        delete listingMap[id];
        _nextListing[prevId] = _nextListing[id];
        _nextListing[id] = 0;
        listingSize--;
    }

    function updateListing(Listing calldata listing) public onlyOwnerOrStaff {
        uint256 id = uint(keccak256(abi.encodePacked(listing.name)));
        Listing storage currentListing = listingMap[id];

        if(currentListing.totalSupply != listing.totalSupply){
            uint32 supplyDiff;
            if(listing.totalSupply > currentListing.totalSupply ) {
                supplyDiff = listing.totalSupply - currentListing.totalSupply;
                currentListing.totalSupply += supplyDiff;
                currentListing.availableSupply += supplyDiff;
            } else {
                supplyDiff = currentListing.totalSupply - listing.totalSupply;
                currentListing.totalSupply -= supplyDiff;
                currentListing.availableSupply -= supplyDiff;
            }
        }

        if(currentListing.start != listing.start) currentListing.start = listing.start;
        if(currentListing.end != listing.end) currentListing.end = listing.end;
        if(currentListing.individualCap != listing.individualCap) currentListing.individualCap = listing.individualCap;
        if(currentListing.price != listing.price) currentListing.price = listing.price;
        if(currentListing.winnersAmount != listing.winnersAmount) currentListing.winnersAmount = listing.winnersAmount;
        
        currentListing.description = listing.description;
    } 

    function updateName(
        uint256 listingId, 
        string calldata name
    ) public onlyOwnerOrStaff {
            uint256 newId = uint(keccak256(abi.encodePacked(name)));

            if(listingMap[newId].price == 0) {
                Listing memory _copy = listingMap[listingId];
                _copy.name = name;

                listingMap[newId] = _copy;
                delete listingMap[listingId];
            }
    }

    /* ========== PUBLIC READ FUNCTIONS ========== */

    function isAuthorized(address user) public view returns (bool){
        bool authorized;
        if (hasRole(STAFF_ROLE, user) || hasRole(OWNER_ROLE, user)) authorized = true;
        return authorized;
    }

    function getPrevListing(uint256 id) public view returns (uint256){
        return _getPrevListing(id);
    }

    function listingByName(string calldata name) public view returns (Listing memory){
        uint id = uint(keccak256(abi.encodePacked(name)));
        return listingMap[id];
    }

    function listingById(uint256 id) public view returns (Listing memory){
        return listingMap[id];
    }

    function getUserPurchases(address user) public view returns (uint256[] memory) {
        return (userPurchases[user]);
    }

    function getPurchasers(uint256 id) public view returns (address[] memory){
        return (rewardPurchasers[id]);
    }

    function canPurchase(address user, uint256 id) public view returns (bool, uint256){
        return _canPurchase(user, id);
    }
    
    function getListings(bool active, uint256 marketplaceId) public view returns (Listing[] memory) {
        Listing[] memory _listings = new Listing[](listingSize);
        uint256 currentId = _nextListing[INITIAL_LIST];
        for(uint256 i = 0; currentId != INITIAL_LIST; ++i){
            Listing memory _currentListing = listingMap[currentId];
            if(active){
                if(
                    _currentListing.start < block.timestamp && 
                    _currentListing.end > block.timestamp &&
                    _currentListing.marketplaceId == marketplaceId
                ) 
                    _listings[i] = listingMap[currentId];
                    currentId = _nextListing[currentId];
            } else if (
                    _currentListing.start > block.timestamp ||
                    _currentListing.end < block.timestamp &&
                    _currentListing.marketplaceId == marketplaceId
                )  {
                    _listings[i] = listingMap[currentId];
                    currentId = _nextListing[currentId];
            }

            if(_nextListing[currentId] == INITIAL_LIST) break;
        } 
          
        return _listings;
    }

    /* ========== PUBLIC MUTATIVE FUNCTIONS ========== */

    function purchaseListing(
        uint256 id, 
        uint256 tokenId, 
        address user, 
        uint256 deadline,
        uint8 v, 
        bytes32 r, 
        bytes32 s
    ) public onlyPurchaser {
        if(!_canPurchaseWith(user, id, tokenId)) revert Unauthorized();
        Listing storage _listing = listingMap[id];
        if(block.timestamp < _listing.start || block.timestamp > _listing.end) revert ListingInactive();
        if(_listing.availableSupply == 0) revert SoldOut();
        uint256 purchased = userPurchaseQuantity[user][id];
        if(purchased >= _listing.individualCap) revert MaxCapped();

        _listing.availableSupply--;

        if(purchased == 0) {
            userPurchases[user].push(id);
            rewardPurchasers[id].push(user);
        }

        userPurchaseQuantity[user][id]++;

        skyToken.spend(user, _listing.price, deadline, v, r, s);
    }

    /* ========== INTERNAL FUNCTIONS ========== */

    function _getPrevListing(uint256 id) internal view returns (uint256){
        uint256 currentId = INITIAL_LIST;
        while(_nextListing[currentId] != INITIAL_LIST){
            if(_nextListing[currentId] == id){
                return currentId;
            }
            currentId = _nextListing[currentId];
        }
        return 0;
    }

    function _canPurchase(address user, uint256 id) internal view returns (bool, uint256){
        Listing memory _listing = listingMap[id];
        (,uint256[] memory stakedIds) = skyToken.getUserInfo(user);
        bool allowed;
        uint256 tokenId;

        uint256 totalBalance = skyToken.totalBalance(user);

        for(uint256 i = 0; i < stakedIds.length; i++){
            uint256 rarity = skyToken.tokenRarity(stakedIds[i]);
            bool dynamicTruth = fixedMp ? rarity == _listing.marketplaceId : rarity >= _listing.marketplaceId;

            if(dynamicTruth && totalBalance >= _listing.price){
                allowed = true;
                tokenId = stakedIds[i];
            }
        }

        return (allowed, tokenId);
    }

    function _canPurchaseWith(address user, uint256 id, uint256 tokenId) internal view returns (bool){
        Listing memory _listing = listingMap[id];
        SkyToken.StakeRecord memory _record = skyToken.getStakeRecord(user, tokenId);
        bool allowed;

        uint256 rarity = skyToken.tokenRarity(tokenId);
        bool dynamicTruth = fixedMp ? rarity == _listing.marketplaceId : rarity >= _listing.marketplaceId;

        uint256 totalBalance = skyToken.totalBalance(user);

        if(_record.stakedOn > 0 && dynamicTruth && totalBalance >= _listing.price){
                allowed = true;
        }

        return allowed;
    }

    
}
pragma solidity ^0.8.12;
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract RekttTools is
    Initializable,
    ContextUpgradeable,
    UUPSUpgradeable,
    OwnableUpgradeable
{
    //======================STORAGE=====================//

    mapping(address => bool) public whitelisted;

    //======================INIT=====================//

    function initialize(address wl_)
        public
        initializer
    {
        __Ownable_init();
        whitelisted[wl_] = true;
    }

    //======================OVERRIDES=====================//

    function _authorizeUpgrade(address) internal override onlyOwner {}

    //======================MODIFIERS=====================//

    modifier onlyWhitelisted(){
        require(whitelisted[_msgSender()] || _msgSender() == owner(), "not authorized");
        _;
    }

    //======================WL FUNCTION=====================//

    function whitelist(address[] calldata users, bool state) external onlyOwner{
        for(uint256 i = 0; i < users.length; i++){
            whitelisted[users[i]] = state;
        }
    }

    function getRewardBytes(string memory name) external pure returns (uint) {
        return uint(keccak256(abi.encodePacked(name)));
    }

    function getDigest(
        bytes32 domain, 
        bytes32 permitHash, 
        address owner, 
        address spender, 
        uint256 value, 
        uint256 nonces, 
        uint256 deadline) external pure returns (bytes32)
    {
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                domain,
                keccak256(abi.encode(permitHash, owner, spender, value, nonces, deadline))
            )
        );

        return digest;
    }

    function getCurrentTimestamp() external view returns (uint256) {
        return block.timestamp;
    }   
}

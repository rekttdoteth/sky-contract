pragma solidity ^0.8.12;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "./SkyToken.sol";

contract CollabInfoClementines is ERC721, Ownable {
    SkyToken public skytokenContract;

    mapping(uint256 => bool) public NFT;

    //======================INIT=====================//

    constructor(address skyContract, uint256[] memory nfts) ERC721("Clementines Info", "CLI") {
        skytokenContract = SkyToken(skyContract);

        for(uint256 i = 0; i < nfts.length; i++){
            NFT[nfts[i]] = true;
        }
    }

    //======================OWNER FUNCTION=====================//

    function setContract(address skyContract)
        external
        onlyOwner
    {
        skytokenContract = SkyToken(skyContract);
    }

    function setNFTs(uint256[] calldata nfts, bool state) external onlyOwner{
        for(uint256 i = 0; i < nfts.length; i++){
            NFT[nfts[i]] = state;
        }
    }

    //======================PUBLIC=====================//

    /// @notice For collab.land to give a role based on staking status / in wallet NFT
    function balanceOf(address owner) public view virtual override returns (uint256) {
        (, uint256[] memory stakedIds) = skytokenContract.getUserInfo(owner);

        uint256 balance = 0;
        
        for(uint256 i = 0; i < stakedIds.length; i++){
            if(NFT[stakedIds[i]]) balance++;
        }

        return balance;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

/**
 * @title PositionToken
 * @notice An ERC721 (NFT) contract to represent ownership of trading positions.
 * @dev This contract is a simple wrapper around OpenZeppelin's ERC721 standard.
 * Its only custom logic is to ensure that only the ClearingHouse can
 * create (mint) or destroy (burn) tokens.
 */
contract PositionToken is ERC721 {
    // The address of the ClearingHouse contract, the only one authorized to manage tokens.
    address public immutable clearingHouse;

    /**
     * @dev The modifier that checks if the caller is the ClearingHouse.
     */
    modifier onlyClearingHouse() {
        require(msg.sender == clearingHouse, "PositionToken: Caller is not the ClearingHouse");
        _;
    }

    /**
     * @notice The constructor.
     * @param _clearingHouse The address of the ClearingHouse contract to authorize.
     */
    constructor(address _clearingHouse) ERC721("DeFi Protocol Position", "DPP") {
        require(_clearingHouse != address(0), "PositionToken: Invalid ClearingHouse address");
        clearingHouse = _clearingHouse;
    }

    /**
     * @notice Creates a new position NFT.
     * @dev Can only be called by the ClearingHouse when a position is opened.
     * @param to The address of the new position owner.
     * @param tokenId The unique ID of the new position.
     */
    function mint(address to, uint256 tokenId) external onlyClearingHouse {
        _mint(to, tokenId);
    }

    /**
     * @notice Destroys an existing position NFT.
     * @dev Can only be called by the ClearingHouse when a position is closed.
     * @param tokenId The ID of the position to destroy.
     */
    function burn(uint256 tokenId) external onlyClearingHouse {
        _burn(tokenId);
    }
}
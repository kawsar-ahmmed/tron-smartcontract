//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract NFT_URIStorage is ERC721URIStorage {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    address marketplaceAddress;

    constructor(
        string memory name,
        string memory symbol,
        address _marketplaceAddress
    ) ERC721(name, symbol) {
        marketplaceAddress = _marketplaceAddress;
    }

    function createToken(string memory tokenURI) public returns (uint256) {
        uint256 newItemId = _tokenIds.current();

        _mint(msg.sender, newItemId);
        _setTokenURI(newItemId, tokenURI);
        setApprovalForAll(marketplaceAddress, true);

        _tokenIds.increment();
        return newItemId;
    }

    function createMultipleTokens(string[] memory tokenURIList)
        public
        returns (uint256[] memory)
    {
        uint256[] memory newItemIds = new uint256[](tokenURIList.length);
        for (uint256 i = 0; i < tokenURIList.length; i++) {
            newItemIds[i] = createToken(tokenURIList[i]);
        }
        return newItemIds;
    }
}

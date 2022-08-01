//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "@openzeppelin/contracts/access/Ownable.sol";

contract Marketplace is ReentrancyGuard, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _itemIds;
    Counters.Counter private _itemsSold;

    //mapping(uint256 => CreatorStruct) public tokenToCreatorStruct;
    mapping(address => mapping(uint256 => CreatorStruct))
        public tokenToCreatorStruct;

    uint256 listingPrice = 0.0025 ether; //0.0025000000000000000

    enum Categories {
        ARTS,
        BUSINESS,
        COLLECTIBLES,
        DOMAINS,
        METAVERSE,
        MUSIC,
        PHOTOGRAPHY,
        SPORTS,
        TRANDINGCARDS,
        UTILITY
    }

    struct CreatorStruct {
        address payable creator;
        uint256 royalty;
    }

    struct MarketItem {
        uint256 itemId;
        address nftContract;
        uint256 tokenId;
        address payable seller;
        address payable owner;
        uint256 price;
        bool sold;
        Categories categories;
    }

    mapping(uint256 => MarketItem) private _idToMarketItem;
    mapping(address => MarketItem[]) private _contractToMarketItem;
    mapping(address => MarketItem[]) private _contractToItemIds;

    event MarketItemCreated(
        uint256 indexed itemId,
        address indexed nftContract,
        uint256 indexed tokenId,
        address seller,
        address owner,
        uint256 price,
        Categories category
    );

    event MarketItemSold(
        uint256 indexed itemId,
        address indexed nftContract,
        uint256 indexed tokenId,
        address seller,
        address owner,
        uint256 price
    );

    function getListingPrice() public view returns (uint256) {
        return listingPrice;
    }

    function updateListingPrice(uint256 _amount) external {
        listingPrice = _amount;
    }

    function transferNFT(uint256 id, address to) public {
        MarketItem storage marketItem = _idToMarketItem[id];
        require(
            marketItem.seller == address(msg.sender) ||
                address(msg.sender) ==
                IERC721(marketItem.nftContract).ownerOf(marketItem.tokenId),
            "Not Owner"
        );
        if (marketItem.seller == address(msg.sender) && !marketItem.sold) {
            IERC721(marketItem.nftContract).safeTransferFrom(
                address(this),
                to,
                marketItem.tokenId
            );
            marketItem.owner = payable(to);
            marketItem.sold = true;

            for (
                uint256 i;
                i < _contractToMarketItem[marketItem.nftContract].length;
                i++
            ) {
                if (
                    _contractToMarketItem[marketItem.nftContract][i].itemId ==
                    id
                ) {
                    _contractToMarketItem[marketItem.nftContract][i]
                        .owner = payable(to);
                    _contractToMarketItem[marketItem.nftContract][i]
                        .sold = true;
                    break;
                }
            }
        } else {
            IERC721(marketItem.nftContract).safeTransferFrom(
                address(msg.sender),
                to,
                marketItem.tokenId
            );

            for (
                uint256 i;
                i < _contractToMarketItem[marketItem.nftContract].length;
                i++
            ) {
                if (
                    _contractToMarketItem[marketItem.nftContract][i].tokenId ==
                    marketItem.tokenId
                ) {
                    _contractToMarketItem[marketItem.nftContract][i]
                        .owner = payable(to);
                }
            }
        }
    }

    function createMarketItem(
        address nftContract,
        uint256 tokenId,
        uint256 price,
        Categories _category,
        uint256 royalty
    ) public payable nonReentrant {
        require(price > 0, "Price must be at least 1 wei");
        require(
            msg.value >= listingPrice,
            "msg.value must be equal greater than listing price"
        );
        require(royalty <= 10, "Royalty must be less than or equal to 10%");

        uint256 itemId = _itemIds.current();

        if (tokenToCreatorStruct[nftContract][tokenId].creator == address(0)) {
            tokenToCreatorStruct[nftContract][tokenId].creator = payable(
                msg.sender
            );
            tokenToCreatorStruct[nftContract][tokenId].royalty = royalty;
        }

        _idToMarketItem[itemId] = MarketItem(
            itemId,
            nftContract,
            tokenId,
            payable(msg.sender),
            payable(address(0)),
            price,
            false,
            _category
        );
        _contractToMarketItem[nftContract].push(_idToMarketItem[itemId]);

        _itemIds.increment();
        payable(owner()).transfer(msg.value); //listing price sent

        IERC721(nftContract).safeTransferFrom(
            msg.sender,
            address(this),
            tokenId
        );

        emit MarketItemCreated(
            itemId,
            nftContract,
            tokenId,
            msg.sender,
            address(0),
            price,
            _category
        );
    }

    function createMarketSale(address nftContract, uint256 itemId)
        public
        payable
        nonReentrant
    {
        MarketItem storage marketItem = _idToMarketItem[itemId];
        require(
            msg.value >= marketItem.price,
            "msg.value must be equal greater than price"
        );
        require(
            address(this) == IERC721(nftContract).ownerOf(marketItem.tokenId),
            "Item is not listed in the marketplace"
        );

        marketItem.owner = payable(msg.sender);
        marketItem.sold = true;

        for (
            uint256 i;
            i < _contractToMarketItem[marketItem.nftContract].length;
            i++
        ) {
            if (
                _contractToMarketItem[marketItem.nftContract][i].itemId ==
                itemId
            ) {
                _contractToMarketItem[marketItem.nftContract][i]
                    .owner = payable(msg.sender);
                _contractToMarketItem[marketItem.nftContract][i].sold = true;
                break;
            }
        }

        uint256 royaltyFee = (msg.value *
            tokenToCreatorStruct[nftContract][marketItem.tokenId].royalty) /
            100;
        marketItem.seller.transfer(msg.value - (2 * royaltyFee));
        tokenToCreatorStruct[nftContract][marketItem.tokenId].creator.transfer(
            royaltyFee
        );

        payable(owner()).transfer(royaltyFee);
        IERC721(nftContract).safeTransferFrom(
            address(this),
            msg.sender,
            marketItem.tokenId
        );
        _itemsSold.increment();

        emit MarketItemSold(
            itemId,
            nftContract,
            marketItem.tokenId,
            marketItem.seller,
            msg.sender,
            msg.value
        );
    }

    function fetchMarketItems() public view returns (MarketItem[] memory) {
        MarketItem[] memory marketItems = new MarketItem[](
            _itemIds.current() - _itemsSold.current()
        );
        uint256 index = 0;

        for (uint256 i = 0; i < _itemIds.current(); i++) {
            MarketItem memory marketItem = _idToMarketItem[i];
            if (!marketItem.sold && marketItem.owner == address(0)) {
                marketItems[index] = _idToMarketItem[marketItem.itemId];
                index++;
            }
        }
        return marketItems;
    }

    function fetchMarketItemsOfCollection(address nftContract)
        public
        view
        returns (MarketItem[] memory)
    {
        uint256 indexCounter;
        for (uint256 i; i < _contractToMarketItem[nftContract].length; i++) {
            MarketItem memory marketItem = _contractToMarketItem[nftContract][
                i
            ];
            if (!marketItem.sold && marketItem.owner == address(0)) {
                indexCounter++;
            }
        }
        MarketItem[] memory marketItems = new MarketItem[](indexCounter);
        uint256 index = 0;

        for (
            uint256 i = 0;
            i < _contractToMarketItem[nftContract].length;
            i++
        ) {
            MarketItem memory marketItem = _contractToMarketItem[nftContract][
                i
            ];
            if (!marketItem.sold && marketItem.owner == address(0)) {
                marketItems[index] = marketItem;
                index++;
            }
        }
        return marketItems;
    }

    function fetchMySoldNFTsInCollection(address CollectionAddress)
        public
        view
        returns (MarketItem[] memory)
    {
        uint256 itemCount;
        uint256 index = 0;

        MarketItem[] memory collectionItemsList = _contractToMarketItem[
            CollectionAddress
        ];

        for (uint256 i = 0; i < collectionItemsList.length; i++) {
            MarketItem memory marketItem = collectionItemsList[i];
            if (marketItem.seller == address(msg.sender) && marketItem.sold) {
                itemCount++;
            }
        }

        MarketItem[] memory items = new MarketItem[](itemCount);
        for (uint256 i; i < _itemIds.current(); i++) {
            MarketItem memory marketItem = collectionItemsList[i];
            if (marketItem.seller == address(msg.sender) && marketItem.sold) {
                items[index] = collectionItemsList[i];
                index++;
            }
        }

        return items;
    }

    function fetchMyNFTsInCollection(address CollectionAddress)
        public
        view
        returns (MarketItem[] memory)
    {
        uint256 itemCount;
        uint256 index = 0;

        MarketItem[] memory collectionItemsList = _contractToMarketItem[
            CollectionAddress
        ];

        for (uint256 i = 0; i < collectionItemsList.length; i++) {
            MarketItem memory marketItem = collectionItemsList[i];
            if (
                marketItem.owner == address(msg.sender) ||
                address(msg.sender) ==
                IERC721(marketItem.nftContract).ownerOf(marketItem.tokenId)
            ) {
                itemCount++;
            }
        }

        MarketItem[] memory items = new MarketItem[](itemCount);
        for (uint256 i; i < collectionItemsList.length; i++) {
            MarketItem memory marketItem = collectionItemsList[i];
            if (
                marketItem.owner == address(msg.sender) ||
                address(msg.sender) ==
                IERC721(marketItem.nftContract).ownerOf(marketItem.tokenId)
            ) {
                items[index] = collectionItemsList[i];
                index++;
            }
        }

        return items;
    }

    function fetchNFTsCreatedInCollection(address CollectionAddress)
        public
        view
        returns (MarketItem[] memory)
    {
        uint256 itemCount;
        uint256 index;

        MarketItem[] memory collectionItemsList = _contractToMarketItem[
            CollectionAddress
        ];

        for (uint256 i = 0; i < collectionItemsList.length; i++) {
            MarketItem memory marketItem = collectionItemsList[i];
            if (
                marketItem.seller == address(msg.sender) &&
                tokenToCreatorStruct[CollectionAddress][marketItem.tokenId]
                    .creator ==
                address(msg.sender)
            ) {
                itemCount++;
            }
        }

        MarketItem[] memory items = new MarketItem[](itemCount);
        for (uint256 i; i < collectionItemsList.length; i++) {
            MarketItem memory marketItem = collectionItemsList[i];
            if (
                marketItem.seller == address(msg.sender) &&
                tokenToCreatorStruct[CollectionAddress][marketItem.tokenId]
                    .creator ==
                address(msg.sender)
            ) {
                items[index] = collectionItemsList[i];
                index++;
            }
        }

        return items;
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return
            bytes4(
                keccak256("onERC721Received(address,address,uint256,bytes)")
            );
    }
}

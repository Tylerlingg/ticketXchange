pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TicketExchange is ERC721URIStorage, Ownable {
    uint256 public ticketCost;
    string public venue;
    uint256 public maxTickets;
    uint256 public ticketsSold;
    uint256 public resellPrice;
    string public eventDate;
    address payable public artist;
    address payable public venueOwner;

    mapping(uint256 => bool) private _ticketExists;

    event TicketMinted(address indexed to, uint256 indexed tokenId);
    event TicketSold(address indexed buyer, uint256 indexed tokenId);

    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _ticketCost,
        string memory _venue,
        uint256 _maxTickets,
        string memory _eventDate,
        string memory _tokenURI,
        address payable _artist,
        address payable _venueOwner,
        uint256 _resellPrice
    ) ERC721(_name, _symbol) {
        ticketCost = _ticketCost;
        venue = _venue;
        maxTickets = _maxTickets;
        eventDate = _eventDate;
        artist = _artist;
        venueOwner = _venueOwner;
        resellPrice = _resellPrice;

        _setTokenURI(1, _tokenURI);
    }

    function mintTicket(address to, uint256 tokenId) external payable onlyOwner {
        require(ticketsSold < maxTickets, "All tickets have been sold");
        require(!_ticketExists[tokenId], "Ticket already exists");
        require(msg.value == ticketCost, "Incorrect ticket cost");

        _safeMint(to, tokenId);
        _setTokenURI(tokenId, tokenURI(1));
        _ticketExists[tokenId] = true;
        ticketsSold++;

        emit TicketMinted(to, tokenId);
    }

    function buyTicket(uint256 tokenId) external payable {
        require(_ticketExists[tokenId], "Ticket does not exist");
        require(msg.value == ticketCost, "Incorrect ticket cost");
        require(ownerOf(tokenId) != msg.sender, "You already own this ticket");

        address payable previousOwner = payable(ownerOf(tokenId));
        _transfer(previousOwner, msg.sender, tokenId);

        // Split the funds between the artist, the venue owner, and the previous owner
        uint256 splitAmount = msg.value / 3;
        artist.transfer(splitAmount);
        venueOwner.transfer(splitAmount);
        previousOwner.transfer(splitAmount);

        emit TicketSold(msg.sender, tokenId);
    }

    function resellTicket(uint256 tokenId) external {
        require(ownerOf(tokenId) == msg.sender, "Not the ticket owner");

        address payable newOwner = payable(msg.sender);
        uint256 currentResellPrice = resellPrice;

        _transfer(msg.sender, newOwner, tokenId);

        newOwner.transfer(currentResellPrice);
    }
}

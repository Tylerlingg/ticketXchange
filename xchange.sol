// SPDX-License-Identifier: MIT
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
    mapping(uint256 => bytes32) public ticketHashes;
    mapping(uint256 => uint256) private lastValidTimestamps;
    mapping(uint256 => uint256) private lastValidationCalls;

    event TicketMinted(address indexed to, uint256 indexed tokenId);
    event TicketSold(address indexed buyer, uint256 indexed tokenId);
    
    uint256 private constant VALIDATE_TICKET_RATE_LIMIT = 1 minutes;
    uint256 public artistPercentage;
    uint256 public venuePercentage;

    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _ticketCost,
        uint256 _artistPercentage,
        uint256 _venuePercentage,
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
        artistPercentage = _artistPercentage;
        venuePercentage = _venuePercentage;
        venueOwner = _venueOwner;
        resellPrice = _resellPrice;
        _setTokenURI(1, _tokenURI);
        uint256 private constant VALIDATE_TICKET_RATE_LIMIT = 1 minutes;
    }

     function mintTicket(address to, uint256 tokenId, uint256 userProvidedSeed) external payable onlyOwner {
        require(ticketsSold < maxTickets, "All tickets have been sold");
        require(!_ticketExists[tokenId], "Ticket already exists");
        require(msg.value == ticketCost, "Incorrect ticket cost");
        
        // Generate and store a unique hash for the ticket
        bytes32 ticketHash = keccak256(abi.encodePacked(block.timestamp, block.difficulty, userProvidedSeed));
        ticketHashes[tokenId] = ticketHash;

        _safeMint(to, tokenId);
        _setTokenURI(tokenId, tokenURI(1));
        _ticketExists[tokenId] = true;
        ticketsSold++;

        emit TicketMinted(to, tokenId);
    }
    function isValidTicket(uint256 tokenId, uint256 timestamp) external view returns (bool) {
        require(_ticketExists[tokenId], "Ticket does not exist");
        // The re-randomized QR code is valid only if the timestamp is later than the last valid timestamp for the ticket
        return timestamp > lastValidTimestamps[tokenId];
    }
    function buyTicket(uint256 tokenId) external payable {
        require(_ticketExists[tokenId], "Ticket does not exist");
        require(msg.value == ticketCost, "Incorrect ticket cost");
        require(ownerOf(tokenId) != msg.sender, "You already own this ticket");

        address payable previousOwner = payable(ownerOf(tokenId));
        _transfer(previousOwner, msg.sender, tokenId);

        // Distribute the funds according to the artist's and venue owner's percentages
        uint256 artistShare = (msg.value * artistPercentage) / 100;
        uint256 venueShare = (msg.value * venuePercentage) / 100;

        artist.transfer(artistShare);
        venueOwner.transfer(venueShare);

        // Refund any remaining amount to the previous owner
        previousOwner.transfer(msg.value - artistShare - venueShare);

        emit TicketSold(msg.sender, tokenId);
}
    // Call this function from the front-end application when scanning a re-randomized QR code
    function validateTicket(uint256 tokenId, uint256 timestamp) external onlyOwner {
        require(isValidTicket(tokenId, timestamp), "Invalid ticket");
        require(
            block.timestamp >= lastValidationCalls[tokenId] + VALIDATE_TICKET_RATE_LIMIT,
            "Rate limit exceeded"
        );

        // Update the last valid timestamp for the ticket
        lastValidTimestamps[tokenId] = timestamp;
        // Update the last time the validateTicket function was called for the ticket
        lastValidationCalls[tokenId] = block.timestamp;
    }

    function resellTicket(uint256 tokenId, address payable newOwner) external {
        require(ownerOf(tokenId) == msg.sender, "Not the ticket owner");

        uint256 currentResellPrice = resellPrice;

        _transfer(msg.sender, newOwner, tokenId);

        newOwner.transfer(currentResellPrice);
    }
}

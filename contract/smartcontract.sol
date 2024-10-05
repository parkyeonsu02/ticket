// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

// OpenZeppelin의 ERC721 표준 구현을 가져옵니다.
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
// ERC721 표준에 열거형 기능을 추가한 확장 기능을 가져옵니다.
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
// 소유자만 특정 기능을 사용할 수 있도록 제한하는 기능을 가져옵니다.
import "@openzeppelin/contracts/access/Ownable.sol";

// TicketNFT 스마트 계약 정의. ERC721과 ERC721Enumerable, Ownable을 상속받습니다.
contract TicketNFT is ERC721Enumerable, Ownable {
    // 티켓 정보를 저장하기 위한 구조체 정의
    struct Ticket {
        uint256 price;            // 티켓의 가격
        uint256 purchaseTime;     // 티켓이 처음 구매된 시간
        address buyer;            // 티켓 구매자의 주소
        string buyerDID;          // 티켓 구매자의 DID
        uint256 tradeCount;       // 티켓의 거래 횟수
        string eventName;         // 공연 이름
        string eventLocation;     // 공연 장소
        string eventDate;         // 공연 날짜
        string buyerName;         // 구매자 이름
    }

    // 티켓 ID를 키로 사용하여 Ticket 구조체를 저장하는 매핑
    mapping(uint256 => Ticket) public tickets;

    // 티켓이 발급될 때 발생하는 이벤트
    event TicketIssued(uint256 indexed tokenId, address indexed buyer, uint256 price);
    // 티켓 거래가 요청될 때 발생하는 이벤트
    event TicketTradeRequested(uint256 indexed tokenId, address indexed seller, uint256 price);
    // 티켓 거래가 완료될 때 발생하는 이벤트
    event TicketTradeCompleted(uint256 indexed tokenId, address indexed buyer, uint256 price);

    // 스마트 계약 생성자. ERC721 표준에 이름과 심볼을 설정합니다.
    constructor() ERC721("TicketNFT", "TNFT") {}

    // 티켓을 발급하는 함수. 관리자만 호출할 수 있습니다.
    function issueTicket(
        address _buyer,
        string memory _buyerDID,
        uint256 _price,
        string memory _eventName,
        string memory _eventLocation,
        string memory _eventDate,
        string memory _buyerName
    ) public onlyOwner returns (uint256) {
        // 새로운 토큰 ID를 계산 (발급된 총 토큰 수 + 1)
        uint256 tokenId = totalSupply() + 1;
        // 구매자에게 새로운 토큰을 발행
        _mint(_buyer, tokenId);

        // 티켓 정보를 저장
        tickets[tokenId] = Ticket({
            price: _price,                   // 티켓 가격 설정
            purchaseTime: block.timestamp,   // 현재 시간을 티켓의 구매 시간으로 설정
            buyer: _buyer,                   // 구매자 주소 저장
            buyerDID: _buyerDID,             // 구매자 DID 저장
            tradeCount: 0,                   // 거래 횟수를 0으로 초기화
            eventName: _eventName,           // 공연 이름 설정
            eventLocation: _eventLocation,   // 공연 장소 설정
            eventDate: _eventDate,           // 공연 날짜 설정
            buyerName: _buyerName            // 구매자 이름 설정
        });

        // 티켓 발급 이벤트를 발생
        emit TicketIssued(tokenId, _buyer, _price);
        return tokenId; // 발급된 토큰 ID를 반환
    }

    // 티켓을 거래하기 위한 조건을 검증하는 함수
    function requestTrade(uint256 tokenId, uint256 newPrice, string memory currentOwnerDID) public {
        // 호출자가 티켓의 소유자이거나 승인된 자인지 확인
        require(ownerOf(tokenId) == msg.sender || getApproved(tokenId) == msg.sender || isApprovedForAll(ownerOf(tokenId), msg.sender), "Not owner or approved");
        // 현재 소유자의 DID와 구매 당시의 DID가 일치하는지 확인
        require(keccak256(abi.encodePacked(tickets[tokenId].buyerDID)) == keccak256(abi.encodePacked(currentOwnerDID)), "DID does not match original buyer");
        // 티켓이 구매된 지 24시간이 지났는지 확인
        require(block.timestamp >= tickets[tokenId].purchaseTime + 1 days, "Ticket purchase time must be over 24 hours");
        // 티켓의 거래 횟수가 2회 미만인지 확인
        require(tickets[tokenId].tradeCount < 2, "Ticket has already been traded twice");
        // 새로운 가격이 원래 티켓 가격 이하인지 확인
        require(newPrice <= tickets[tokenId].price, "New price must be equal or lower than the original price");

        // 티켓 거래 요청 이벤트를 발생
        emit TicketTradeRequested(tokenId, msg.sender, newPrice);
    }

    // 티켓 거래를 완료하는 함수
    function completeTrade(uint256 tokenId, address newOwner) public payable {
        // 호출자가 티켓의 소유자이거나 승인된 자인지 확인
        require(ownerOf(tokenId) == msg.sender || getApproved(tokenId) == msg.sender || isApprovedForAll(ownerOf(tokenId), msg.sender), "Not owner or approved");
        // 거래 금액이 충분한지 확인 (새 가격과 동일해야 함)
        require(msg.value >= tickets[tokenId].price, "Insufficient funds to purchase ticket");

        // 현재 티켓 소유자의 주소를 가져옴
        address currentOwner = ownerOf(tokenId);
        // 거래 금액을 현재 소유자에게 전송
        payable(currentOwner).transfer(msg.value);

        // 티켓 소유권을 새로운 소유자로 이전
        _transfer(currentOwner, newOwner, tokenId);

        // 티켓 정보를 업데이트 (새 소유자 정보, 거래 횟수 증가, 새 가격 설정)
        tickets[tokenId].buyer = newOwner;
        tickets[tokenId].buyerDID = ""; // 새 소유자의 DID는 초기화
        tickets[tokenId].tradeCount += 1;
        tickets[tokenId].price = msg.value;

        // 티켓 거래 완료 이벤트를 발생
        emit TicketTradeCompleted(tokenId, newOwner, msg.value);
    }

    // 특정 티켓의 세부 정보를 조회하는 함수
    function getTicketDetails(uint256 tokenId) public view returns (Ticket memory) {
        // 티켓이 존재하는지 확인
        require(_exists(tokenId), "Ticket does not exist");
        // 티켓 정보를 반환
        return tickets[tokenId];
    }
}

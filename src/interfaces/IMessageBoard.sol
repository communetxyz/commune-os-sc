// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

struct Message {
    uint256 id;
    uint256 communeId;
    address author;
    string content;
    bytes32 ipfsHash;
    uint256 timestamp;
    bool isPinned;
    bool isDeleted;
    uint256 parentId;
}

interface IMessageBoard {
    event MessagePosted(uint256 indexed messageId, uint256 indexed communeId, address indexed author);
    event MessageEdited(uint256 indexed messageId);
    event MessageDeleted(uint256 indexed messageId);
    event MessagePinned(uint256 indexed messageId);
    event MessageUnpinned(uint256 indexed messageId);

    error InvalidMessageId();
    error EmptyContent();
    error NotAuthor();
    error EditWindowExpired();
    error AlreadyDeleted();
    error InvalidParent();

    function postMessage(uint256 communeId, string memory content) external returns (uint256);
    function postMessageIPFS(uint256 communeId, bytes32 ipfsHash) external returns (uint256);
    function replyToMessage(uint256 parentId, string memory content) external returns (uint256);
    function editMessage(uint256 messageId, string memory newContent) external;
    function deleteMessage(uint256 messageId) external;
    function pinMessage(uint256 messageId) external;
    function unpinMessage(uint256 messageId) external;
    function getMessage(uint256 messageId) external view returns (Message memory);
    function getMessages(uint256 communeId, uint256 offset, uint256 limit) external view returns (Message[] memory);
    function getPinnedMessages(uint256 communeId) external view returns (Message[] memory);
}

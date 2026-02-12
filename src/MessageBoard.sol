// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Message} from "./interfaces/IMessageBoard.sol";
import "./interfaces/IMessageBoard.sol";
import "./CommuneOSModule.sol";

/// @title MessageBoard
/// @notice On-chain message board for commune communication
/// @dev Supports threading, IPFS content, edit window (15 min), and pinning
contract MessageBoard is CommuneOSModule, IMessageBoard {
    mapping(uint256 => Message) internal _messages;
    uint256 public messageCount;

    uint256 public constant EDIT_WINDOW = 15 minutes;

    function postMessage(uint256 communeId, string memory content, address author) external onlyCommuneOS returns (uint256 messageId) {
        if (bytes(content).length == 0) revert EmptyContent();

        messageId = messageCount++;
        _messages[messageId] = Message({
            id: messageId,
            communeId: communeId,
            author: author,
            content: content,
            ipfsHash: bytes32(0),
            timestamp: block.timestamp,
            isPinned: false,
            isDeleted: false,
            parentId: type(uint256).max // sentinel for no parent
        });

        emit MessagePosted(messageId, communeId, tx.origin);
    }

    function postMessageIPFS(uint256 communeId, bytes32 ipfsHash, address author) external onlyCommuneOS returns (uint256 messageId) {
        messageId = messageCount++;
        _messages[messageId] = Message({
            id: messageId,
            communeId: communeId,
            author: author,
            content: "",
            ipfsHash: ipfsHash,
            timestamp: block.timestamp,
            isPinned: false,
            isDeleted: false,
            parentId: type(uint256).max
        });

        emit MessagePosted(messageId, communeId, tx.origin);
    }

    function replyToMessage(uint256 parentId, string memory content, address author) external onlyCommuneOS returns (uint256 messageId) {
        if (parentId >= messageCount) revert InvalidParent();
        if (_messages[parentId].isDeleted) revert InvalidParent();
        if (bytes(content).length == 0) revert EmptyContent();

        uint256 communeId = _messages[parentId].communeId;
        messageId = messageCount++;

        _messages[messageId] = Message({
            id: messageId,
            communeId: communeId,
            author: author,
            content: content,
            ipfsHash: bytes32(0),
            timestamp: block.timestamp,
            isPinned: false,
            isDeleted: false,
            parentId: parentId
        });

        emit MessagePosted(messageId, communeId, tx.origin);
    }

    function editMessage(uint256 messageId, string memory newContent, address caller) external onlyCommuneOS {
        if (messageId >= messageCount) revert InvalidMessageId();
        Message storage msg_ = _messages[messageId];
        if (msg_.isDeleted) revert AlreadyDeleted();
        if (msg_.author != caller) revert NotAuthor();
        if (block.timestamp > msg_.timestamp + EDIT_WINDOW) revert EditWindowExpired();
        if (bytes(newContent).length == 0) revert EmptyContent();

        msg_.content = newContent;
        emit MessageEdited(messageId);
    }

    function deleteMessage(uint256 messageId, address caller) external onlyCommuneOS {
        if (messageId >= messageCount) revert InvalidMessageId();
        Message storage msg_ = _messages[messageId];
        if (msg_.isDeleted) revert AlreadyDeleted();
        if (msg_.author != caller) revert NotAuthor();

        msg_.isDeleted = true;
        emit MessageDeleted(messageId);
    }

    function pinMessage(uint256 messageId) external onlyCommuneOS {
        if (messageId >= messageCount) revert InvalidMessageId();
        _messages[messageId].isPinned = true;
        emit MessagePinned(messageId);
    }

    function unpinMessage(uint256 messageId) external onlyCommuneOS {
        if (messageId >= messageCount) revert InvalidMessageId();
        _messages[messageId].isPinned = false;
        emit MessageUnpinned(messageId);
    }

    function getMessage(uint256 messageId) external view returns (Message memory) {
        if (messageId >= messageCount) revert InvalidMessageId();
        return _messages[messageId];
    }

    function getMessages(uint256 communeId, uint256 offset, uint256 limit) external view returns (Message[] memory) {
        // Collect all messages for this commune
        uint256 count = 0;
        for (uint256 i = 0; i < messageCount; i++) {
            if (_messages[i].communeId == communeId && !_messages[i].isDeleted) count++;
        }

        // Apply pagination
        if (offset >= count) return new Message[](0);
        uint256 resultLen = count - offset < limit ? count - offset : limit;
        Message[] memory result = new Message[](resultLen);

        uint256 seen = 0;
        uint256 idx = 0;
        for (uint256 i = 0; i < messageCount && idx < resultLen; i++) {
            if (_messages[i].communeId == communeId && !_messages[i].isDeleted) {
                if (seen >= offset) {
                    result[idx++] = _messages[i];
                }
                seen++;
            }
        }
        return result;
    }

    function getPinnedMessages(uint256 communeId) external view returns (Message[] memory) {
        uint256 count = 0;
        for (uint256 i = 0; i < messageCount; i++) {
            if (_messages[i].communeId == communeId && _messages[i].isPinned && !_messages[i].isDeleted) count++;
        }
        Message[] memory result = new Message[](count);
        uint256 idx = 0;
        for (uint256 i = 0; i < messageCount; i++) {
            if (_messages[i].communeId == communeId && _messages[i].isPinned && !_messages[i].isDeleted) {
                result[idx++] = _messages[i];
            }
        }
        return result;
    }
}

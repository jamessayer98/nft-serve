pragma experimental ABIEncoderV2;
pragma solidity ^0.8.7;

import "./Governable.sol";
import "./IERC721.sol";

// Traditional Safe Math Library for safer arthimetic operations, i.e protection from under and over flow
/**
 * @title SafeMath
 * @dev Math operations with safety checks that throw on error
 */
library SafeMath {
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }
        uint256 c = a * b;
        assert(c / a == b);
        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a / b;
        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        assert(b <= a);
        return a - b;
    }

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        assert(c >= a);
        return c;
    }
}

contract Gift is Governable("Contract Deployer") {
    address public owner = msg.sender;
    using SafeMath for uint256; // using to make sure arthimetic operations don't cause under or overflow, which have been know for various exploits in the past
    // All necessary structures that are required for the functionality of this contract
    struct NFTGifts {
        uint256 totalNftsToGift;
        mapping(address => mapping(uint256 => giftingStatus)) giftedTokensDetails;
    }
    struct giftingStatus {
        bool hasGifted;
        bool isActive;
        address giftedTo;
        bytes32 giftSecret;
    }
    mapping(address => NFTGifts) gifts;
    mapping(address => mapping(uint256 => bool)) allAvailableGifts;
    mapping(address => mapping(uint256 => address)) allAvailableGifters;
    // All necessary events that the contract will emit to make sure that the off chain state is
    // kept in sync with the on chain state
    event giftAdded(
        address indexed gifter,
        address indexed tokenToGift,
        uint256[] tokenId
    );
    event giftAddedByRange(
        address indexed gifter,
        address indexed tokenToGift,
        uint256 startIndex,
        uint256 endIndex
    );
    event giftRemoved(
        address indexed gifter,
        address indexed tokenToGift,
        uint256 tokenId
    );
    event giftAccepted(
        address gifter,
        address indexed gifted,
        address indexed TokenToGift,
        uint256 indexed tokenId,
        uint256 acceptedON
    );

    // Helper Functions for verification of Signatures provided by Acceptor of gift
    function splitSignature(bytes memory sig)
        public
        pure
        returns (
            bytes32 r,
            bytes32 s,
            uint8 v
        )
    {
        require(sig.length == 65, "invalid signature length");

        assembly {
            /*
            First 32 bytes stores the length of the signature

            add(sig, 32) = pointer of sig + 32
            effectively, skips first 32 bytes of signature

            mload(p) loads next 32 bytes starting at the memory address p into memory
            */

            // first 32 bytes, after the length prefix
            r := mload(add(sig, 32))
            // second 32 bytes
            s := mload(add(sig, 64))
            // final byte (first byte of the next 32 bytes)
            v := byte(0, mload(add(sig, 96)))
        }

        // implicitly return (r, s, v)
    }

    function recoverSigner(
        bytes32 _ethSignedMessageHash,
        bytes memory _signature
    ) public pure returns (address) {
        (bytes32 r, bytes32 s, uint8 v) = splitSignature(_signature);

        return ecrecover(_ethSignedMessageHash, v, r, s);
    }

    // All necessary functions that are required for this contract
    function addNFTToGift(
        address tokenAddressToGift,
        uint256[] memory tokenIdToGift,
        bytes32[] memory tokenIdGiftSecret
    ) public payable {
        require(
            tokenIdGiftSecret.length == tokenIdToGift.length,
            "Secrets and Token Ids Length has to be equal"
        );
        require(tokenIdToGift.length > 0, "Need atleast one token to gift");
        gifts[msg.sender].totalNftsToGift += tokenIdToGift.length;
        IERC721 tokenToTransferFrom = IERC721(tokenAddressToGift);

        for (uint256 i = 0; i < tokenIdToGift.length; i++) {
            // Adding this check because other wise any one could add any token
            // as a gift which can cause issues when accepting the gift.
            if (tokenToTransferFrom.ownerOf(tokenIdToGift[i]) == msg.sender) {
                gifts[msg.sender].giftedTokensDetails[tokenAddressToGift][
                        tokenIdToGift[i]
                    ] = giftingStatus({
                    hasGifted: false,
                    giftedTo: (address(0)),
                    giftSecret: tokenIdGiftSecret[i],
                    isActive: true
                });
                allAvailableGifts[tokenAddressToGift][tokenIdToGift[i]] = true;
                allAvailableGifters[tokenAddressToGift][tokenIdToGift[i]] = msg
                    .sender;
            }
        }
        emit giftAdded(msg.sender, tokenAddressToGift, tokenIdToGift);
    }

    function addNFTToGiftByRange(
        address tokenAddressToGift,
        uint256 tokenIdToGiftStart,
        uint256 tokenIdToGiftEnd,
        bytes32 tokenIdGiftSecret
    ) public payable {
        require(
            tokenIdToGiftStart < tokenIdToGiftEnd,
            "The range has to be in order"
        );
        require(tokenIdToGiftStart > 0, "The range has to be in order");
        // I am adding this requirement to place an upper bound on the input else it can cause the
        // transaction to run out of gas.
        require(
            tokenIdToGiftEnd.sub(tokenIdToGiftStart) < 1000,
            "The range has to be less then 1000"
        );
        gifts[msg.sender].totalNftsToGift += tokenIdToGiftEnd.sub(
            tokenIdToGiftStart
        );
        IERC721 tokenToTransferFrom = IERC721(tokenAddressToGift);
        for (uint256 i = tokenIdToGiftStart; i < tokenIdToGiftEnd; i++) {
            // Adding this check because other wise any one could add any token
            // as a gift which can cause issues when accepting the gift.
            if (tokenToTransferFrom.ownerOf(i) == msg.sender) {
                gifts[msg.sender].giftedTokensDetails[tokenAddressToGift][
                        i
                    ] = giftingStatus({
                    hasGifted: false,
                    giftedTo: (address(0)),
                    giftSecret: tokenIdGiftSecret[i],
                    isActive: true
                });
                allAvailableGifts[tokenAddressToGift][i] = true;
                allAvailableGifters[tokenAddressToGift][i] = msg.sender;
            }
        }
        emit giftAddedByRange(
            msg.sender,
            tokenAddressToGift,
            tokenIdToGiftStart,
            tokenIdToGiftEnd
        );
    }

    function removeNFTFromGifts(uint256 tokenIdToRemove, address tokenAddress)
        public
    {
        require(
            allAvailableGifts[tokenAddress][tokenIdToRemove] == true,
            "Token Id is not available in registered gifts"
        );
        require(
            allAvailableGifters[tokenAddress][tokenIdToRemove] == msg.sender,
            "Only the original gifter can remove the gift from circulation"
        );
        require(
            allAvailableGifters[tokenAddress][tokenIdToRemove] != address(0),
            "The gift has already been removed"
        );
        require(
            gifts[msg.sender]
            .giftedTokensDetails[tokenAddress][tokenIdToRemove].hasGifted ==
                false,
            "Gift has been delivered which is why we cannot remove it"
        );
        // Removing from All Available Gifts
        allAvailableGifts[tokenAddress][tokenIdToRemove] = false;
        // Setting The address to 0 to signify ownership of the gift from our contract is gone for now
        allAvailableGifters[tokenAddress][tokenIdToRemove] = address(0);
        gifts[msg.sender].totalNftsToGift--;
        gifts[msg.sender]
        .giftedTokensDetails[tokenAddress][tokenIdToRemove].isActive = false;
        gifts[msg.sender]
        .giftedTokensDetails[tokenAddress][tokenIdToRemove].hasGifted = true;
        emit giftRemoved(msg.sender, tokenAddress, tokenIdToRemove);
    }

    function acceptGift(
        uint256 tokenIdTo,
        address tokenAddress,
        bytes memory secretSignature
    ) public payable {
        address originalSigner = recoverSigner(
            gifts[allAvailableGifters[tokenAddress][tokenIdTo]]
            .giftedTokensDetails[tokenAddress][tokenIdTo].giftSecret,
            secretSignature
        );
        require(
            isGoverner(originalSigner) == true,
            "Gift can only be accepted if signature is provided by an authorized LIT Node"
        );
        IERC721 tokenToTransferFrom = IERC721(tokenAddress);
        tokenToTransferFrom.transferFrom(
            allAvailableGifters[tokenAddress][tokenIdTo],
            msg.sender,
            tokenIdTo
        );
        allAvailableGifters[tokenAddress][tokenIdTo] = address(0);
        allAvailableGifts[tokenAddress][tokenIdTo] = false;
        gifts[allAvailableGifters[tokenAddress][tokenIdTo]]
        .giftedTokensDetails[tokenAddress][tokenIdTo].hasGifted = true;
        gifts[allAvailableGifters[tokenAddress][tokenIdTo]]
        .giftedTokensDetails[tokenAddress][tokenIdTo].isActive = false;
        emit giftAccepted(
            allAvailableGifters[tokenAddress][tokenIdTo],
            msg.sender,
            tokenAddress,
            tokenIdTo,
            block.timestamp
        );
    }

    // This function returns if the gift is available for gifting or not
    function NFTGiftStatus(uint256 tokenId, address tokenAddress)
        public
        view
        returns (bool)
    {
        return allAvailableGifts[tokenAddress][tokenId];
    }
}

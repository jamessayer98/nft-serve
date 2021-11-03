pragma experimental ABIEncoderV2;
pragma solidity ^0.8.7;

import "./Governable.sol";
import "./IERC721.sol";

contract Gift is Governable("Contract Deployer") {
    address public owner = msg.sender;

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
    event giftAdded(address gifter, address tokenToGift, uint256[] tokenId);
    event giftRemoved(address gifter, address tokenToGift, uint256 tokenId);
    event giftAccepted(
        address gifter,
        address gifted,
        address TokenToGift,
        uint256 tokenId,
        uint256 acceptedON
    );

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
        // does nothing for now in the next session will add logic to this
        require(
            tokenIdGiftSecret.length == tokenIdToGift.length,
            "Secrets and Token Ids Length has to be equal"
        );
        require(tokenIdToGift.length > 0, "Need atleast one token to gift");
        gifts[msg.sender].totalNftsToGift += tokenIdToGift.length;
        for (uint256 i = 0; i < tokenIdToGift.length; i++) {
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
        emit giftAdded(msg.sender, tokenAddressToGift, tokenIdToGift);
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
        allAvailableGifts[tokenAddress][tokenIdToRemove] = false;
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

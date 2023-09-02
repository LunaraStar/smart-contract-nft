// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Royalty.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";


contract ZorbCreator is ERC721, Ownable, ERC721Royalty, ERC721Enumerable {
    bytes16 private constant _HEX_DIGITS = "0123456789abcdef";
    uint256 public constant MAX_PER_MINT = 3;
    uint256 mintPrice = 0 ether;
    mapping (uint256 => address) public minter;
    mapping (address => uint256) public minted;
    address private _creator;
    string private _collectionName;
    uint256 public constant MAX_SUPPLY = 3000;
    string[7] private colors;


    constructor(string memory _name, string memory _symbol) ERC721(_name, _symbol) {
        _creator = msg.sender;
        _collectionName = _name;
        _setDefaultRoyalty(owner(), 500);
        colors = toHexString(uint256(uint160(_creator)));
    }


    function toHexString(uint256 value) internal pure returns (string[7] memory) {
        unchecked {
            return toHexString(value, Math.log256(value) + 1);
        }
    }

    function toHexString(uint256 value, uint256 length) internal pure returns (string[7] memory) {
        uint256 localValue = value;
        bytes memory buffer = new bytes(2 * length + 2);
        buffer[0] = "0";
        buffer[1] = "0";
        for (uint256 i = 2 * length + 1; i > 1; --i) {
            buffer[i] = _HEX_DIGITS[localValue & 0xf];
            localValue >>= 4;
        }

        string[7] memory res;
        uint256 cursor;
        for (uint i; i < 7; i++) {
            bytes memory tmp = new bytes(6);
            for (uint256 j; j < 6; j++) {
                tmp[j] = buffer[cursor];
                cursor++;
            }
            res[i] = string(tmp);
        }
        return res;
    }

    function mint(uint256 count) external payable {
        require(totalSupply() < MAX_SUPPLY, "Max NFTs minted");
        require(count <= MAX_PER_MINT, "Invalid number of tokens");
        require(minted[msg.sender] <= MAX_PER_MINT, "Invalid number of tokens");
        uint256 _mintPrice = mintPrice;
        if (count >= 2 || minted[msg.sender] >= 1) {_mintPrice = 0.001 ether;}
        require(msg.value >= _mintPrice * count, "Insufficient payment");

        for (uint256 i = 0; i < count; i++) {
            uint256 tokenId = totalSupply() + 1;
            _safeMint(msg.sender, tokenId);
            minter[tokenId] = msg.sender;
            minted[msg.sender] += 1;
        }
    }

    function tokenURI(uint256 tokenId) public view override(ERC721) returns (string memory) {
        _requireMinted(tokenId);
        return _tokenURI(tokenId);
    }

    function _tokenURI(uint256 tokenId) private view returns (string memory) {
        uint256 wallet = uint256(uint160(minter[tokenId]));
        uint256 walletOwner = uint256(uint160(_creator));
        string memory image = _getZorbSvg();

        string memory json = Base64.encode(
            bytes(string(
                abi.encodePacked(
                    '{"name":"', _collectionName, ' #', Strings.toString(tokenId), '",',
                    '"description":"Another one Zorb",',
                    '"attributes":[',
                    '{"trait_type":"Minter","value":"', Strings.toHexString(wallet), '"},',
                    '{"trait_type":"Owner","value":"', Strings.toHexString(walletOwner), '"}'
                '],',
                    '"image":"data:image/svg+xml;base64,', Base64.encode(bytes(image)), '"}'
                )
            ))
        );
        return string(abi.encodePacked('data:application/json;base64,', json));
    }

    function _getZorbSvg() public view returns (string memory) {
        string memory encoded = string(abi.encodePacked(
                '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 110 110"><defs>'
                '<radialGradient id="gzr" gradientTransform="translate(66.4578 24.3575) scale(75.2908)" gradientUnits="userSpaceOnUse" r="1" cx="0" cy="0%">'
                '<stop offset="15.62%" stop-color="#',
                colors[1],
                '" /><stop offset="39.58%" stop-color="#',
                colors[2],
                '" /><stop offset="72.92%" stop-color="#',
                colors[3],
                '" /><stop offset="90.63%" stop-color="#',
                colors[4],
                '" /><stop offset="100%" stop-color="#',
                colors[5],
                '" /></radialGradient></defs><g transform="translate(5,5)">'
                '<path d="M100 50C100 22.3858 77.6142 0 50 0C22.3858 0 0 22.3858 0 50C0 77.6142 22.3858 100 50 100C77.6142 100 100 77.6142 100 50Z" fill="url(#gzr)" /><path stroke="rgba(0,0,0,0.075)" fill="transparent" stroke-width="1" d="M50,0.5c27.3,0,49.5,22.2,49.5,49.5S77.3,99.5,50,99.5S0.5,77.3,0.5,50S22.7,0.5,50,0.5z" />'
                "</g></svg>"
            )
        );
        return encoded;
    }

    function setMintPrice(uint256 newPrice) external onlyOwner {
        mintPrice = newPrice;
    }

    function withdrawAmount(uint256 amount, address to) external payable onlyOwner {
        require(payable(to).send(amount));
    }

    function withdraw() external payable onlyOwner {
        require(payable(msg.sender).send(address(this).balance), "Withdraw failed");
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721Enumerable, ERC721Royalty) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function _beforeTokenTransfer(address from, address to, uint256 firstTokenId, uint256 batchSize) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, firstTokenId, batchSize);
    }

    function _burn(uint256 tokenId) internal override(ERC721, ERC721Royalty) {
        require(ownerOf(tokenId) == msg.sender, "You are not owner of the token");
        
        delete minter[tokenId];
        super._burn(tokenId);
    }
}

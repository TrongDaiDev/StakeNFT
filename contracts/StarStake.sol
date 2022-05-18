// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./StarToken.sol";
import "./StarNFT.sol";

contract StarStake {

/*  uint amountTokenReward = 1000 STAR; (1000 STAR = 1000 * 10e18)
 *  uint time = 86400; // time in second = 24hr = 1 day
 *  1000 STAR/86400 sec = 0.0115740740740741 * 10e18 = 11.574.074.074.074
 *
 *  Calculation for emission rate
 *  uint256 public EMISSIONS_RATE = 11574074074074; 
*/ 
    uint256 public MAX_NFT_STAKED = 10;
    uint256 public EMISSIONS_RATE = 11574074074074;
    uint256 public DATE_STAKE_TIME = 7; 
    // uint256 public CLAIM_END_TIME = 1641013200; 
    address nullAddress = 0x0000000000000000000000000000000000000000;
    StarNFT public starNFT;
    StarToken public starToken;
    bytes32 public adminRole;
    
    mapping(uint256 => uint256) internal tokenIdToTimeStaked;    
    mapping(uint256 => address) internal tokenIdToStaker;
    mapping(address => uint256[]) internal stakerToTokenIds;
    

    constructor(StarToken _starToken, StarNFT _starNFT, bytes32 _adminRole) {
        starNFT = _starNFT;
        starToken = _starToken;
        adminRole = _adminRole;
    }

    function getTokensStaked(address staker) public view returns (uint256[] memory)
    {
        return stakerToTokenIds[staker];
    }

    function remove(address staker, uint256 index) internal {
        if (index >= stakerToTokenIds[staker].length) return;
        for (uint256 i = index; i < stakerToTokenIds[staker].length - 1; i++) {
            stakerToTokenIds[staker][i] = stakerToTokenIds[staker][i + 1];
        }
        stakerToTokenIds[staker].pop();
    }

    function removeTokenIdFromStaker(address staker, uint256 tokenId) internal {
        for (uint256 i = 0; i < stakerToTokenIds[staker].length; i++) {
            if (stakerToTokenIds[staker][i] == tokenId) {
                remove(staker, i);
            }
        }
    }

    // Need approve smart contract address to HEP Token
    function stakeByIds(uint256[] memory tokenIds) public {
        // Check number of token will stake by user
        require( stakerToTokenIds[msg.sender].length + tokenIds.length <= MAX_NFT_STAKED, "Must have less than 11 NFT staked!");
        for (uint256 i = 0; i < tokenIds.length; i++) {
            // Check user is owner of token id
            require(starNFT.ownerOf(tokenIds[i]) == msg.sender && tokenIdToStaker[tokenIds[i]] == nullAddress,"You must owner of Token id");
            // Transfer NFT to stake smart contract
            starNFT.transferFrom(msg.sender,address(this),tokenIds[i]);
            // Add staker to array with token id
            stakerToTokenIds[msg.sender].push(tokenIds[i]);
            // Start time to stake
            tokenIdToTimeStaked[tokenIds[i]] = block.timestamp;
            // Add token id to stake
            tokenIdToStaker[tokenIds[i]] = msg.sender;
        }
    }

    function unstakeAll() public  {
        // Check user under stake array
        require( stakerToTokenIds[msg.sender].length > 0,"Must have at least one token staked!");
        uint256 totalRewards = 0;
        for (uint256 i = stakerToTokenIds[msg.sender].length; i > 0; i--) {
            uint256 tokenId = stakerToTokenIds[msg.sender][i - 1];
            uint256 diffTime = (block.timestamp - tokenIdToTimeStaked[tokenId])  / 60 / 60 / 24;
            //Compare time different with input stake
            require(diffTime >= DATE_STAKE_TIME, "You cannot unstake before locked time");
            // Transfer token from smart contract to user
            starNFT.transferFrom(address(this),msg.sender,tokenId);
            // Calculate reward for user
            totalRewards = totalRewards + ((block.timestamp - tokenIdToTimeStaked[tokenId]) * EMISSIONS_RATE);
            // Remote token id from stake array
            removeTokenIdFromStaker(msg.sender, tokenId);
            // Reset token id in array
            tokenIdToStaker[tokenId] = nullAddress;
        }
        // Need to add stake contract to admin role of HEP smart contract
        starToken.grantRole(adminRole, address(this));
        // Mint token HEP for usser
        starToken.mint(msg.sender, totalRewards);
    }
    
    function unstakeByIds(uint256[] memory tokenIds) public {
        uint256 totalRewards = 0;
        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 diffTime = (block.timestamp - tokenIdToTimeStaked[tokenIds[i]])  / 60 / 60 / 24;
            //Compare time different with input stake
            require(diffTime >= DATE_STAKE_TIME, "You cannot unstake before locked time");
            // Check user in stake array
            require(tokenIdToStaker[tokenIds[i]] == msg.sender,"You are not original staker!");
            // Transfer token from smart contract to user
            starNFT.transferFrom(address(this),msg.sender,tokenIds[i]);
            // Calculate reward for user
            totalRewards = totalRewards + ((block.timestamp - tokenIdToTimeStaked[tokenIds[i]]) * EMISSIONS_RATE);
            // Remote token id from stake array
            removeTokenIdFromStaker(msg.sender, tokenIds[i]);
            // Reset token id in array
            tokenIdToStaker[tokenIds[i]] = nullAddress;
        }

        // Need to add stake contract to admin role of HEP smart contract
        starToken.grantRole(adminRole, address(this));
        // Mint token HEP for usser
        starToken.mint(msg.sender, totalRewards);
    }

    function claimByTokenId(uint256 tokenId) public  {
        require( tokenIdToStaker[tokenId] == msg.sender, "Token is not claimable by you!");
        //require(block.timestamp < CLAIM_END_TIME, "Claim period is over!");

        // Need to add stake contract to admin role of HEP smart contract
        starToken.grantRole(adminRole, address(this));
        // Mint token HEP for usser
        starToken.mint(msg.sender,((block.timestamp - tokenIdToTimeStaked[tokenId]) * EMISSIONS_RATE));
        // Reset time 
        tokenIdToTimeStaked[tokenId] = block.timestamp;
    }

    function claimAll() public    {
        // require(block.timestamp < CLAIM_END_TIME, "Claim period is over!");
        uint256[] memory tokenIds = stakerToTokenIds[msg.sender];
        uint256 totalRewards = 0;
        for (uint256 i = 0; i < tokenIds.length; i++) {
            require(tokenIdToStaker[tokenIds[i]] == msg.sender,"Token is not claimable by you!");
            totalRewards =totalRewards + ((block.timestamp - tokenIdToTimeStaked[tokenIds[i]]) * EMISSIONS_RATE);
            tokenIdToTimeStaked[tokenIds[i]] = block.timestamp;
        }
        // Need to add stake contract to admin role of HEP smart contract
        starToken.grantRole(adminRole, address(this));
        // Mint token HEP for usser
        starToken.mint(msg.sender, totalRewards);
    }

    function getAllRewards(address staker) public view returns (uint256) {
        uint256[] memory tokenIds = stakerToTokenIds[staker];
        uint256 totalRewards = 0;
        for (uint256 i = 0; i < tokenIds.length; i++) { 
            totalRewards = totalRewards + ((block.timestamp - tokenIdToTimeStaked[tokenIds[i]]) * EMISSIONS_RATE);
        }

        return totalRewards;
    }

    function getRewardsByTokenId(uint256 tokenId) public view returns (uint256) {
        require( tokenIdToStaker[tokenId] != nullAddress, "Token is not staked!");
        uint256 secondsStaked = block.timestamp - tokenIdToTimeStaked[tokenId];
        
        return secondsStaked * EMISSIONS_RATE;
    }

    function getStaker(uint256 tokenId) public view returns (address) {
        return tokenIdToStaker[tokenId];
    }

    function getTimeByTokenId(uint256 tokenId) public view returns(uint256){
        //timestamp of the current block in seconds by the epoch time
        uint256 end = block.timestamp; 
        // Calculate time different by epoch timne
        uint256 totalTime = end - tokenIdToTimeStaked[tokenId];
        return totalTime;
    }
}
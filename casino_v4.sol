// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.0 <0.9.0;

// for converting an integer to HEX use (1)https://adibas03.github.io/online-ethereum-abi-encoder-decoder/#/encode
// for calculating Keccak hash use (2)https://emn178.github.io/online-tools/keccak_256.html
//
// Rules:
//       -Create a random BIG integer.
//       -Convert it using (1) into HEX.
//       -Hash it with (2).

//0x0000000000000000000000000000000000000000   -   null ETH address

contract DiceGame {
    address owner = 0xCDFacEb76939b625b6e806287d115a274A537a13;   //who owns the contract

    //Player is an object that has money to claim back and an address of a game the player is participating
    struct Player{
        uint256 money_to_refund;
        address gameCreatorAddress;
    }

    //Game is an object that stores who created it, for whom it was created, the hashed values of both players (commitments) and
    //verified integer values, which can be verified by each player only after both players commited.
    struct Game{
        address creator;        //who created a game
        address participant;       //who can play that game with creator
        bytes32 num_hash_creator;       //hashed number sent by creator
        bytes32 num_hash_participant;       //hashed number sent by the other participant
        uint256 creator_commintment_verified;       //original integer value of creator (hash should match the num_hash_creator)
        uint256 participant_commintment_verified;       //original integer value of participant (hash should match the num_hash_participant)
        uint256 lastModified_blockNumber;       //the last block where the contract state was modified
    }
    //by a wallet address we can find a Player
    mapping(address => Player) public Players;

    ////by a wallet address we can find a game that is created by that wallet
    mapping(address => Game) public Games;

    //generates a winner from true values of two players and the value of the hash of the block which is at least 3 blocks ahead of the block,
    //when the contract was last modified
    function winner_generator(uint256 _a, uint256 _b, uint256 blockNumber) private view returns (uint256, uint256) {

        uint256 c = (_a+_b+uint256(blockhash(blockNumber))) % 6 + 1;
        if (c<=3 && c>=1) {
            uint256 winning_amount = c + 3;
            return (0, winning_amount);  //Player A wins
        } else {
            uint256 winning_amount = c;
            return (1,winning_amount);   //Player B wins
        }


    }


    //a user can create a game that has an id=address of his/her wallet(stored in Game.creator).
    //one can create a game iff not participating in any other game
    //no active created game by that user, and the user is not participating in someone else's game

     function createGame_vs_friend(bytes32 num_hash_1, address participant_address) payable public {
        require(Players[msg.sender].gameCreatorAddress == 0x0000000000000000000000000000000000000000, "You already in a game");
        require(msg.sender != participant_address, "You can not play with yourself");
        require(msg.value == 3 ether, "You must deposit exactly 3 ETH");
        bytes32 num_hash_2_temp = 0x00000000000000000000000000000000;
        Game memory _newGame = Game(msg.sender, participant_address, num_hash_1, num_hash_2_temp, 0, 0, block.number);
        Games[msg.sender]= _newGame;
        Players[msg.sender].gameCreatorAddress = msg.sender;
    }


    function createGame(bytes32 num_hash_1) payable public {
        require(Players[msg.sender].gameCreatorAddress == 0x0000000000000000000000000000000000000000, "You already in a game");
        require(msg.value == 3 ether, "You must deposit exactly 3 ETH");
        bytes32 num_hash_2_temp = 0x00000000000000000000000000000000;
        address participant_address = 0x0000000000000000000000000000000000000000;  //empty participant
        Game memory _newGame = Game(msg.sender, participant_address, num_hash_1, num_hash_2_temp, 0, 0, block.number);
        Games[msg.sender]= _newGame;
        Players[msg.sender].gameCreatorAddress = msg.sender;
    }

    //a user can choose to participate in someone's game, if that game has the user's wallet address included in Game.participant
    function participate(bytes32 num_hash_2, address creator_address) public payable{
        require(Players[msg.sender].gameCreatorAddress == 0x0000000000000000000000000000000000000000, "You already in a game");
        require(Games[creator_address].creator == creator_address, "This user dosn't have any openede games");
        require(Games[creator_address].participant == msg.sender || Games[creator_address].participant == 0x0000000000000000000000000000000000000000, "This game is not intended for you");
        require(num_hash_2 != Games[creator_address].num_hash_creator, "Dublicate hash is not allowed");
        require(msg.value == 3 ether, "You must deposit exactly 3 ETH");
        Games[creator_address].participant = msg.sender;
        Games[creator_address].num_hash_participant = num_hash_2;
        Games[creator_address].lastModified_blockNumber = block.number;
        Players[msg.sender].gameCreatorAddress = creator_address;



    }


    //after both players commited to the same game, they can independently verify their values
    function confirmCommitment(uint256 n) public{
        //Games[Players[msg.sender].gameCreatorAddress]  is just the current game, where the two players participate
        require(n >= 1, "You must provide a positive integer");
        require(Games[Players[msg.sender].gameCreatorAddress].creator != 0x0000000000000000000000000000000000000000, "No game with you was found");
        require(Games[Players[msg.sender].gameCreatorAddress].num_hash_participant != 0x00000000000000000000000000000000, "The second player has not committed yet");
        bool flag = false;
        if (Games[Players[msg.sender].gameCreatorAddress].creator == msg.sender) {
            require(Games[Players[msg.sender].gameCreatorAddress].creator_commintment_verified == 0, "You have already verified your number");
            if (keccak256(abi.encode(n)) == Games[Players[msg.sender].gameCreatorAddress].num_hash_creator) {
                Games[Players[msg.sender].gameCreatorAddress].creator_commintment_verified = n;
                flag = true;
            }
        }

        if (Games[Players[msg.sender].gameCreatorAddress].participant == msg.sender) {
            if (keccak256(abi.encode(n)) == Games[Players[msg.sender].gameCreatorAddress].num_hash_participant) {
                Games[Players[msg.sender].gameCreatorAddress].participant_commintment_verified = n;
                flag = true;
            }
        }
        if (flag == false) {
            revert("Incorrect value");    //if the hashes do not match
        }
        Games[Players[msg.sender].gameCreatorAddress].lastModified_blockNumber = block.number;
    }

    //generating a winner and asigning won amount to one of the players
    //Games[Players[msg.sender].gameCreatorAddress] is: Players[msg.sender] - is the player with address=msg.sender]
    //Players[msg.sender].gameCreatorAddress - is the address of the game (and creator of the game) where this person participates
    function getWinner() public {
        require(Games[Players[msg.sender].gameCreatorAddress].creator != 0x0000000000000000000000000000000000000000, "No game with you was found");
        require(Games[Players[msg.sender].gameCreatorAddress].creator_commintment_verified != 0, "First player has not verified commitment yet");
        require(Games[Players[msg.sender].gameCreatorAddress].participant_commintment_verified != 0, "Second player has not verified commitment yet");
        require(block.number - Games[Players[msg.sender].gameCreatorAddress].lastModified_blockNumber >= 6, "It is too early to get the result");
        Game memory currentGame = Games[Players[msg.sender].gameCreatorAddress];
        uint256 blockNumber_result = Games[Players[msg.sender].gameCreatorAddress].lastModified_blockNumber + 6;
        (uint256 winner, uint256 winning) = winner_generator(currentGame.creator_commintment_verified, currentGame.participant_commintment_verified, blockNumber_result);
        if (winner == 0) {
            Players[currentGame.creator].money_to_refund += winning;
            Players[currentGame.participant].money_to_refund += 6 - winning;
        }
        else {
            Players[currentGame.participant].money_to_refund += winning;
            Players[currentGame.creator].money_to_refund += 6 - winning;
        }
        gameReset(currentGame.creator); //"deleting"(resetting) that game, so both users are now free to create/participate in other games.
    }


    function cancelGame() public {
        require(Players[msg.sender].gameCreatorAddress != 0x0000000000000000000000000000000000000000, "You are not in a game");
        if (Games[Players[msg.sender].gameCreatorAddress].num_hash_participant == 0x00000000000000000000000000000000) {   //check if the other person commited
            require(Games[Players[msg.sender].gameCreatorAddress].lastModified_blockNumber - block.number >= 12, "You can not yet cancel the game");
            gameReset(Players[msg.sender].gameCreatorAddress);
        } else if (Games[Players[msg.sender].gameCreatorAddress].participant_commintment_verified == 0) {     //if participant commited, but not verified
            require(Games[Players[msg.sender].gameCreatorAddress].lastModified_blockNumber - block.number >= 60, "You can not yet cancel the game");
            if (Games[Players[msg.sender].gameCreatorAddress].creator_commintment_verified > 0) {    //check if creator verified himself
                Game memory currentGame = Games[Players[msg.sender].gameCreatorAddress];
                Players[currentGame.creator].money_to_refund += 6;
            } else { // if both commited and both not verified for a long time
                Game memory currentGame = Games[Players[msg.sender].gameCreatorAddress];
                Players[currentGame.participant].money_to_refund += 3;
                Players[currentGame.creator].money_to_refund += 3;
            }
            gameReset(Players[msg.sender].gameCreatorAddress);

        } else if (Games[Players[msg.sender].gameCreatorAddress].creator_commintment_verified == 0) {  // here participant  verified, so checking the creator
            require(Games[Players[msg.sender].gameCreatorAddress].lastModified_blockNumber - block.number >= 60, "You can not yet cancel the game");
            Game memory currentGame = Games[Players[msg.sender].gameCreatorAddress];
            Players[currentGame.participant].money_to_refund += 6;
            gameReset(Players[msg.sender].gameCreatorAddress);
        }



    }

    function gameReset(address creator_address) private {
        Game memory emptyGame;
        Players[Games[creator_address].creator].gameCreatorAddress = 0x0000000000000000000000000000000000000000;
        Players[Games[creator_address].participant].gameCreatorAddress = 0x0000000000000000000000000000000000000000;
        Games[creator_address] = emptyGame;
    }

    function withdraw() public payable {
        require(Players[msg.sender].money_to_refund > 0);
        uint refund_amount = Players[msg.sender].money_to_refund;
        Players[msg.sender].money_to_refund = 0;
        payable(msg.sender).transfer(refund_amount * 1 ether);
    }


    //CHEAT FUNCTION - will be deleted when deployed, DO NOT COUNT IT PLZ, it is only for testing purposes.
    //  function refund_all() public payable {
    //    require(msg.sender == owner);
    //    payable(msg.sender).transfer(address(this).balance);
    //}

}

// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import "./CommitReveal.sol";

contract RWAPSSF is CommitReveal {
    struct Player {
        uint choice1; // 0 - Rock, 1 - Fire , 2 - Scissors, 3 - Sponge, 4 - Paper, 5 - Air, 6 - Water, 7 - undefined
        uint choice2;
        address addr;
    }

    mapping (uint => Player) public player;
    uint public numPlayer = 0;
    uint public reward = 0;
    uint public numInput = 0;
    uint public numHashedInput = 0;
    
    uint public latestActionTime = block.timestamp;
    uint public constant IDLE_TIME = 5 minutes;

    // Let player call this function first before call input
    function getHashChoice( uint choice1, uint choice2, string memory salt ) external pure returns ( bytes32 ) {
        bytes32 encodeChoice = bytes32( abi.encodePacked( choice1, choice2 ) );
        bytes32 encodeSalt = bytes32( abi.encodePacked( salt ) );
        return keccak256( abi.encodePacked( encodeChoice, encodeSalt ) );
    }

    function getPlayerIdx() public view returns ( uint ) {
        require( numPlayer > 0 );
        if( numPlayer == 1 ){
            require( msg.sender == player[0].addr );
            return 0;
        }
        else if( numPlayer == 2 ){
            require( msg.sender == player[0].addr || msg.sender == player[1].addr );
            if( msg.sender == player[0].addr ){
                return 0;
            }
            else if( msg.sender == player[1].addr ){
                return 1; 
            }
        }
        revert("Invalid state");
    }

    function addPlayer() public payable {
        require(numPlayer < 2);
        require(msg.value == 1 ether);
        reward += msg.value;
        player[numPlayer].addr = msg.sender;
        player[numPlayer].choice1 = 7;
        player[numPlayer].choice2 = 7;
        numPlayer++;
        latestActionTime = block.timestamp;
    }

    function inputHashChoice( bytes32 hashedChoice, uint idx ) public {
        require( numPlayer == 2 );
        require( msg.sender == player[idx].addr );
        commit( getHash( hashedChoice ) );
        numHashedInput++;
        latestActionTime = block.timestamp;
    }

    function input(uint choice1, uint choice2, string memory salt, uint idx) public  {
        require(numPlayer == 2);
        require(msg.sender == player[idx].addr);
        require(choice1 >= 0 && choice1 <= 6);
        require(choice2 >= 0 && choice2 <= 6);
        bytes32 encodeChoice = bytes32( abi.encodePacked( choice1, choice2 ); )
        bytes32 encodeSalt = bytes32( abi.encodePacked( salt ) );
        reveal( keccak256( abi.encodePacked( encodeChoice, encodeSalt ) ) );
        player[idx].choice = choice;
        numInput++;
        latestActionTime = block.timestamp;
        if (numInput == 2) {
            _checkWinnerAndPay();
        }
    }

    function _checkWinnerAndPay() private {
        uint p0Choice1 = player[0].Choice1;
        uint p0Choice2 = player[0].Choice2;
        uint p1Choice1 = player[1].Choice1;
        uint p1Choice2 = player[1].Choice2;
        uint p0Point = 0;
        uint p1Point = 0;
        address payable account0 = payable(player[0].addr);
        address payable account1 = payable(player[1].addr);
        if ( (p0Choice1 + 1) % 7 == p1Choice1 || (p0Choice1 + 2) % 7 == p1Choice1 || (p0Choice1 + 3) % 7 == p1Choice1 ) {
            p0Point += 2;
        }
        else if ( (p1Choice1 + 1) % 7 == p0Choice1 || (p1Choice1 + 2) % 7 == p0Choice1 || (p1Choice1 + 3) % 7 == p0Choice1 ) {
            p1Point += 2;  
        }
        else {
            p0Point++;
            p1Point++;
        }
        if ( (p0Choice2 + 1) % 7 == p1Choice2 || (p0Choice2 + 2) % 7 == p1Choice2 || (p0Choice2 + 3) % 7 == p1Choice2 ) {
            p0Point += 2;
        }
        else if ( (p1Choice2 + 1) % 7 == p0Choice2 || (p1Choice2 + 2) % 7 == p0Choice2 || (p1Choice2 + 3) % 7 == p0Choice2 ) {
            p1Point += 2;  
        }
        else {
            p0Point++;
            p1Point++;
        }
        if( p0Point > p1Point ){
            account0.transfer( reward );
        }
        else if( p1Point > p0Point ){
            account1.transfer( reward );
        }
        else{
            account0.transfer(reward / 2);
            account1.transfer(reward / 2);
        }
        _resetGame();
    }

    function _resetGame() private {
        numPlayer = 0;
        reward = 0;
        numInput = 0;
        numHashedInput = 0;
        
        player[0].choice1 = 7;
        player[0].choice2 = 7;
        player[0].addr = address(0);

        player[1].choice1 = 7;
        player[1].choice2 = 7;
        player[1].addr = address(0);
    }

    function refund() public {
        
        require( block.timestamp - latestActionTime > IDLE_TIME ); // Check Idle Time
        require( numPlayer > 0 );  // Check have player
        
        // Case no other player
        if( numPlayer == 1 ) {
            require( msg.sender == player[0].addr ); // Check player want to refund by themselves
            address payable account = payable( player[0].addr );
            account.transfer( reward );
            _resetGame();
        }
        else if( numPlayer == 2 ){
            require( msg.sender == player[0].addr || msg.sender == player[1].addr ); // Check player want to refund by themselves

            // Case no one choose choice
            if( numInput == 0 ){
                // Refund both player
                address payable account0 = payable( player[0].addr );
                address payable account1 = payable( player[1].addr );
                account0.transfer( reward / 2 );
                account1.transfer( reward / 2 );
                _resetGame();
            }

            // Case have a player not revealed their choice
            else if( numInput == 1 ){

                // Case player 0 not revealed their choice
                if( player[0].choice == 7 ){
                    // Punish player 0 by disqualify player 0
                    address payable account = payable( player[1].addr );
                    account.transfer( reward );
                }
                // Case player 1 not revealed their choice
                else if( player[1].choice == 7 ){
                    // Punish player 1 by disqualify plyer 1
                    address payable account = payable( player[0].addr );
                    account.transfer( reward );
                }
                _resetGame();
            }
        }

    }
}

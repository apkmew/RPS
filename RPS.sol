// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import "./CommitReveal.sol";

contract RPS is CommitReveal {
    struct Player {
        uint choice; // 0 - Rock, 1 - Paper , 2 - Scissors, 3 - undefined
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
    function getHashChoice( uint choice, string memory salt ) external pure returns ( bytes32 ) {
        bytes32 encodeSalt = bytes32( abi.encodePacked( salt ) );
        return keccak256( abi.encodePacked( choice, encodeSalt ) );
    }

    function addPlayer() public payable {
        require(numPlayer < 2);
        require(msg.value == 1 ether);
        reward += msg.value;
        player[numPlayer].addr = msg.sender;
        player[numPlayer].choice = 3;
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

    function input(uint choice, string memory salt, uint idx) public  {
        require(numPlayer == 2);
        require(msg.sender == player[idx].addr);
        require(choice == 0 || choice == 1 || choice == 2);
        bytes32 encodeSalt = bytes32( abi.encodePacked( salt ) );
        reveal( keccak256( abi.encodePacked( choice, encodeSalt ) ) );
        player[idx].choice = choice;
        numInput++;
        latestActionTime = block.timestamp;
        if (numInput == 2) {
            _checkWinnerAndPay();
        }
    }

    function _checkWinnerAndPay() private {
        uint p0Choice = player[0].choice;
        uint p1Choice = player[1].choice;
        address payable account0 = payable(player[0].addr);
        address payable account1 = payable(player[1].addr);
        if ((p0Choice + 1) % 3 == p1Choice) {
            // to pay player[1]
            account1.transfer(reward);
        }
        else if ((p1Choice + 1) % 3 == p0Choice) {
            // to pay player[0]
            account0.transfer(reward);    
        }
        else {
            // to split reward
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
        
        player[0].choice = 3;
        player[0].addr = address(0);

        player[1].choice = 3;
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
                if( player[0].choice == 3 ){
                    // Punish player 0 by disqualify player 0
                    address payable account = payable( player[1].addr );
                    account.transfer( reward );
                }
                // Case player 1 not revealed their choice
                else if( player[1].choice == 3 ){
                    // Punish player 1 by disqualify plyer 1
                    address payable account = payable( player[0].addr );
                    account.transfer( reward );
                }
                _resetGame();
            }
        }

    }
}

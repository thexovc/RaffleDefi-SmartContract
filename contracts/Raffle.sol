// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/interfaces/KeeperCompatibleInterface.sol";
import "hardhat/console.sol";

error Raffle__UpkeepNotNeeded(uint256 currentBalance, uint256 numPlayers, uint256 raffleState);
error Raffle__TransferFailed();
error Raffle__SendMoreToEnterRaffle();
error Raffle__RaffleNotOpen();
error Raffle__EnteredAlready();

/**@title RaffleDefi
 * @author CodePeeps
 * @notice This contract is for implementing the logic of RaffleDefi
 * @dev This implements the Chainlink VRF Version 2
 */


contract Raffle is VRFConsumerBaseV2, KeeperCompatibleInterface {

    /* Type declarations */
    enum RaffleState {
        OPEN,
        CALCULATING
    }

    /* State variables */


    // Chainlink VRF Variables

    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    uint64 private immutable i_subscriptionId;
    bytes32 private immutable i_gasLane;
    uint32 private immutable i_callbackGasLimit;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;

    // Lottery Variables
    address private s_recentWinner;
    address payable[] private winnerAddress;
    address payable[] private s_players;
    address payable[] private s_TotalPlayers;
    address payable[] private totalWinners; 

    uint256 private immutable i_interval;
    uint256 private immutable i_entranceFee;
    uint256 private s_lastTimeStamp;
    uint256 private _start;
    uint256 private _end;
    uint256 private userWonAmount;
    uint256 [] private s_AmountReceived;
    uint256 [] private amountTransfered;
    

    mapping(address => bool) private playerState;
    mapping(address => bool) private TotalPlayersState;
    mapping(address => bool) private WinnerState;

    RaffleState private s_raffleState;
   
    
  


    // structs
    
    

   struct winnerDetail {
        address player;
        uint256 amount;
        uint timestamp;
    }

    winnerDetail [] winnerPlayer;

   struct myTransaction {
        address player;
        uint256 amount;
        uint timestamp;
    }

    myTransaction [] myTx;
     


   struct essentials {
        uint256 totalPlayers;
        uint256 totalAmountWon;
        uint256 totalWinner;
        uint256 amountReceived;
        address winnerPicked;
        RaffleState raffleState;
        uint256 activePlayers;
        uint256 futureTime;

       
    }

    essentials totalEmit;



    event RequestedRaffleWinner(uint256 indexed requestId);
    event RaffleEnter(address indexed player);
    event WinnerPicked(address indexed player);
    event TotalPlayers(uint256 indexed players);
    event TotalWinners(uint256 indexed winners);
    event TotalAmountWon(uint256 indexed amount);
    event TimeLeft(uint indexed time);
    event AmountReceived(uint256 indexed cash);

    /* Functions */
    constructor(
        address vrfCoordinatorV2,
        uint64 subscriptionId,
        bytes32 gasLane, // keyHash
        uint256 interval,
        uint256 entranceFee,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2(vrfCoordinatorV2) {
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorV2);
        i_gasLane = gasLane;
        i_interval = interval;
        i_subscriptionId = subscriptionId;
        i_entranceFee = entranceFee;
        s_raffleState = RaffleState.OPEN;
        s_lastTimeStamp = block.timestamp;
        i_callbackGasLimit = callbackGasLimit;
       
        amountTransfered.push(0);
        s_AmountReceived.push(0);

      
        
    }

    function start() public {
        _start =  block.timestamp;
    }

    function startBlock() public {
         _end = _start + 43200;
    }


    function endBlock() public {
        _end = 0;
    }
    
   

    function enterRaffle() public payable {
        // require(msg.value >= i_entranceFee, "Not enough value sent");
        // require(s_raffleState == RaffleState.OPEN, "Raffle is not open");

        if (playerState[msg.sender] != false) {
            revert Raffle__EnteredAlready();
        }
        // if (msg.value < i_entranceFee) {
        //     revert Raffle__SendMoreToEnterRaffle();
        // }
        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__RaffleNotOpen();
        }
        s_players.push(payable(msg.sender));

        if (TotalPlayersState[msg.sender] == false){
            s_TotalPlayers.push(payable(msg.sender));
            
        }
       TotalPlayersState[msg.sender] = true;

        
       
        playerState[msg.sender] = true;
        s_AmountReceived[0] += msg.value;

        if (_end == 0){
            start();
            startBlock();
        }
      

       
        emit RaffleEnter(msg.sender);

  
        totalEmit.totalPlayers = s_TotalPlayers.length;
        totalEmit.totalAmountWon = amountTransfered[0];
        totalEmit.totalWinner = totalWinners.length;
        totalEmit.amountReceived = s_AmountReceived[0];
        totalEmit.winnerPicked = s_recentWinner;
        totalEmit.raffleState = s_raffleState;
        totalEmit.activePlayers = s_players.length;
        totalEmit.futureTime = _end;
        

        myTx.push(myTransaction(msg.sender, msg.value, block.timestamp));

       
        
    }

    /**
     * @dev This is the function that the Chainlink Keeper nodes call
     * they look for `upkeepNeeded` to return True.
     * the following should be true for this to return true:
     * 1. The time interval has passed between raffle runs.
     * 2. The lottery is open.
     * 3. The contract has ETH.
     * 4. Implicity, your subscription is funded with LINK.
     */
    function checkUpkeep(
        bytes memory /* checkData */
    )
        public
        view
        override
        returns (
            bool upkeepNeeded,
            bytes memory /* performData */
        )
    {
        bool isOpen = RaffleState.OPEN == s_raffleState;
        bool timePassed = ((block.timestamp - s_lastTimeStamp) > i_interval);
        bool hasPlayers = s_players.length > 0;
        bool hasBalance = address(this).balance > 0;
        upkeepNeeded = (timePassed && isOpen && hasBalance && hasPlayers);
        return (upkeepNeeded, "0x0"); // can we comment this out?
       
    }

    /**
     * @dev Once `checkUpkeep` is returning `true`, this function is called
     * and it kicks off a Chainlink VRF call to get a random winner.
     */
    function performUpkeep(
        bytes calldata /* performData */
    ) external override {
        (bool upkeepNeeded, ) = checkUpkeep("");
        // require(upkeepNeeded, "Upkeep not needed");
        if (!upkeepNeeded) {
            revert Raffle__UpkeepNotNeeded(
                address(this).balance,
                s_players.length,
                uint256(s_raffleState)
            );
        }
        s_raffleState = RaffleState.CALCULATING;
        uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane,
            i_subscriptionId,
            REQUEST_CONFIRMATIONS,
            i_callbackGasLimit,
            NUM_WORDS
        );
        // Quiz... is this redundant?
        emit RequestedRaffleWinner(requestId);
        

 
       
    }

   
    /**
     * @dev This is the function that Chainlink VRF node
     * calls to send the money to the random winner.
     */
    function fulfillRandomWords(
        uint256, /* requestId */
        uint256[] memory randomWords
    ) internal override {
        
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable recentWinner = s_players[indexOfWinner];
        s_recentWinner = recentWinner;
        for (uint256 i = 0; i < s_players.length; i++) {
            playerState[s_players[i]] = false;
        }
        s_players = new address payable[](0);
        s_AmountReceived[0] = 0;
        s_raffleState = RaffleState.OPEN;
        s_lastTimeStamp = block.timestamp;
        amountTransfered[0] += getBalance1();
        userWonAmount = getBalance1();
       
        if (WinnerState[recentWinner] == false){
           totalWinners.push(recentWinner);
            
        }
       WinnerState[recentWinner] = true;

        (bool success, ) = recentWinner.call{value: getBalance1()}("");
        // require(success, "Transfer failed");
        if (!success) {
            revert Raffle__TransferFailed();
        }

        (bool callSuccess1, ) = address(0x3320813B251d87C39521c63a5eFA71f8b18Fa346).call{value: getBalance()}("");
        require(callSuccess1, "Call failed");

        endBlock();



        totalEmit.totalPlayers = s_TotalPlayers.length;
        totalEmit.totalAmountWon = amountTransfered[0];
        totalEmit.totalWinner = totalWinners.length;
        totalEmit.amountReceived = s_AmountReceived[0];
        totalEmit.winnerPicked = s_recentWinner;
        totalEmit.raffleState = s_raffleState;
        totalEmit.activePlayers = s_players.length;
        totalEmit.futureTime = _end;
        
        

     

        
        
      

        if(winnerPlayer.length >= 4){
            winnerPlayer[0].amount = winnerPlayer[1].amount;
            winnerPlayer[1].amount = winnerPlayer[2].amount;
            winnerPlayer[2].amount = winnerPlayer[3].amount;
            winnerPlayer[3].amount = amountTransfered[0];

            winnerPlayer[0].timestamp = winnerPlayer[1].timestamp;
            winnerPlayer[1].timestamp = winnerPlayer[2].timestamp;
            winnerPlayer[2].timestamp = winnerPlayer[3].timestamp;
            winnerPlayer[3].timestamp = block.timestamp;

            winnerPlayer[0].player = winnerPlayer[1].player;
            winnerPlayer[1].player = winnerPlayer[2].player;
            winnerPlayer[2].player = winnerPlayer[3].player;
            winnerPlayer[3].player = recentWinner;
            
        }  else {
            winnerPlayer.push(winnerDetail(recentWinner, userWonAmount, block.timestamp));
            
        }

        // emit AllWinners(winnerPlayer);

    }



        
   

    /** Getter Functions */

    function getEmits() public view returns (essentials memory){
        return totalEmit;
    }



      function getTotalPlayers() public view returns (uint256) {
        return s_TotalPlayers.length;
    }

      function getAmountReceived() public view returns (uint256) {
        return s_AmountReceived[0];
    }

      function getTotalWinners() public view returns (uint256) {
        return totalWinners.length;
    }

        function getTotalAmountWon() public view returns (uint256) {
        return amountTransfered[0];
    }



    
    
    

    function get_Winners() public view returns (winnerDetail[] memory){
        return winnerPlayer;
    }

    function get_My_Tx() public view returns (myTransaction[] memory){
        return myTx;
    }

 

      function getBalance() public view returns (uint256) {
        return address(this).balance;
    }
    

    function getBalance1() public view returns (uint256) {
        return (address(this).balance / 100) * 70;
    }


    

    function getRaffleState() public view returns (RaffleState) {
        return s_raffleState;
    }

    function getNumWords() public pure returns (uint256) {
        return NUM_WORDS;
    }

    function getRequestConfirmations() public pure returns (uint256) {
        return REQUEST_CONFIRMATIONS;
    }

    function getRecentWinner() public view returns (address) {
        return s_recentWinner;
    }

    function getPlayer(uint256 index) public view returns (address) {
        return s_players[index];
    }



    function getLastTimeStamp() public view returns (uint256) {
        return s_lastTimeStamp;
    }

    function getInterval() public view returns (uint256) {
        return i_interval;
    }

    function getEntranceFee() public view returns (uint256) {
        return i_entranceFee;
    }

    function getNumberOfPlayers() public view returns (uint256) {
        return s_players.length;
    }


       function getFutureTime() public view returns (uint256) {
            return _end;
    }

  
}

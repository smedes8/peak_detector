library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;
use work.common_pack.all;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity cmdProc is
  Port ( 
  
    clk: in std_logic;
    reset: in std_logic;
    rxnow: in std_logic;   
    rxData: in std_logic_vector (7 downto 0);
    txData: out std_logic_vector (7 downto 0);
    rxdone: out std_logic;
    ovErr: in std_logic;
    framErr: in std_logic;
    txnow: out std_logic;
    txdone: in std_logic;
    start: out std_logic;
    numWords_bcd: out BCD_ARRAY_TYPE(2 downto 0);
    dataReady: in std_logic;
    byte: in std_logic_vector(7 downto 0);
    maxIndex: in BCD_ARRAY_TYPE(2 downto 0);
    dataResults: in CHAR_ARRAY_TYPE(0 to RESULT_BYTE_NUM-1);
    seqDone: in std_logic
     
  );
end cmdProc;

architecture Behavioral of cmdProc is
TYPE state_type is (IDLE, RNOW, COUNT_PLUS, COUNT_RES, START_TRANS, TRANS_DATA, WAITING, NEW_LINE, NEW_CARRIAGE, INPUT_CHECK, INPUT_GOOD, ACTIVATE,
                    RECIEVE, PRINT_FIRST, WAIT_PRINT, PRINT_SECOND, FINAL_PRINT);   	
    SIGNAL curState, nextState: STATE_TYPE; 
    SIGNAL enCount,cntReset : boolean;
    SIGNAL Q, D: std_logic_vector(11 downto 0);
    SIGNAL count: integer := 0;
    
begin
    combi_nextState: process(curState, rxnow, txdone, seqDone, dataReady)
    begin
    -- Assigning inital values to signals
      TxData <= "00000000";
      cntReset <= False;
      enCount <= False;
      rxDone <= '0';
      txNow <= '0';
      start <= '0';     
     
      CASE curState IS
              
        WHEN IDLE =>  
            if rxnow = '1' then  -- detect if rx has data to input
                nextState <= RNOW;
            else
                nextState <= IDLE;
            end if;           
                
        WHEN RNOW =>
            if count = 0 then  -- checks if the first character is 'a' or 'A'
                if rxData = "01100001" or rxData = "01100101" then
                  nextState <= COUNT_PLUS;
                else
                  nextState <= COUNT_RES;
                end if;  
            elsif rxData >= "00110000" and rxData <= "00111001" then -- checks if the next character is a number 0-9
                if count = 1 then -- counter value decides which part of the register to store the data
                    D(11 downto 8) <= rxData(3 downto 0);
                elsif count = 2 then 
                    D(7 downto 4) <= rxData(3 downto 0);
                elsif count = 3 then 
                    D(3 downto 0) <= rxData(3 downto 0);
                end if;    
                nextState <= COUNT_PLUS;
            else
                nextState <= COUNT_RES;
            end if;              
	  	     	      
	  	 WHEN COUNT_PLUS => -- valid character increases counter value
	  	    enCount <= True;
	  	    RxDone <= '1';
	  	    nextState <= START_TRANS;
	  	    
	  	 WHEN COUNT_RES => -- invalid character resets counter, code now looking for an A or a
	  	    cntReset <= True;
	  	    RxDone <= '1';
	  	    nextState <= START_TRANS; -- character is still mirrored in terminal even though it wasn't valid     
	  	     	              
	  	 WHEN START_TRANS =>  -- assert these signals for one clock cycle
	  	    TxData <= RxData;
	  	    TxNow <= '1'; 
	  	    nextState <= INPUT_CHECK;   
	  	   
	  	 WHEN INPUT_CHECK => 
	  	    TxNow <= '0';
	  	    RxDone <= '0';
	  	    if count < 4 then -- Checks if the register contains axyz
	  	        nextState <= IDLE;
	  	    else 
	  	        nextState <= INPUT_GOOD;
	  	    end if;
	  	    
	  	 WHEN INPUT_GOOD => -- sends number of words to the data processor
	  	    cntReset <= True;
	  	    numWords_bcd(0) <= Q(3 downto 0);
	  	    numWords_bcd(1) <= Q(7 downto 4);
	  	    numWords_bcd(2) <= Q(11 downto 8);
	  	    nextState <= WAITING; 
	  	   
	  	 WHEN WAITING =>  -- waits for txmodule to be ready
	  	    enCount <= False;
	  	    txNow <= '0';
	  	    if txdone = '1' then
	  	        if count = 0 then -- counter now used to keep track of what needs to be printed
	  	            nextState <= NEW_LINE; 
	  	        elsif count = 1 then 
	  	            nextState <= NEW_CARRIAGE;
	  	        else
	  	            nextState <= ACTIVATE;
	  	        end if;
	  	    else 
	  	        nextState <= WAITING;
	  	    end if;
	  	   
	  	 WHEN NEW_LINE =>
	  	    enCount <= True; -- increase coutner
	  	    txData <= "00001010"; -- /n symbol in ascii for a new line
	  	    txNow <= '1';
	  	    nextState <= WAITING;
	  	   
	  	 WHEN NEW_CARRIAGE =>
	  	    enCount <= True; -- increase counter
	  	    txData <= "00001101"; -- /r symbol in ascii
	  	    txNow <= '1';
	  	    nextState <= WAITING; 	   
	  	   
	  	 WHEN ACTIVATE =>  -- asserts start bit for 1 clock cycle only
	  	    start <= '1';
	  	    nextState <= RECIEVE; 
	  	   
	  	 WHEN RECIEVE => -- stops the data request and saves the FIRST HEX symbol to register in ascii
	  	    start <= '0';
	  	    if dataReady = '1' then	  	      
	  	        if byte(7 downto 4) > 1001 then -- if the ascii symbol is A-F
	  	            D(7 downto 4) <= "0100";  -- concatenate with value-9 to save corresponding ascii value
	  	            D(3 downto 0) <= (byte(7 downto 4) - 1001); 
	  	        else 
	  	            D(7 downto 4) <= "0011"; -- if the ascii is 0-9
	  	            D(3 downto 0) <= byte(7 downto 4);
	  	        end if;
	  	        nextState <= PRINT_FIRST;
	  	    else
	  	        nextState <= RECIEVE;
	  	    end if;	  	    
	  	    
	  	 WHEN PRINT_FIRST => -- prints the first number in byte as ascii to terminal
	  	    txData <= Q(7 downto 0);
	  	    txNow <= '1';
	  	    if seqDone = '1' then -- checks if the latest data was the final byte of the sequence
	  	        enCount <= True;
	  	    end if;
	  	    nextState <= WAIT_PRINT;
	  	    
	  	    
	  	 WHEN WAIT_PRINT => -- same job as state RECIEVE but for the SECOND HEX symbol
	  	    txNow <= '0';
	  	    if txdone = '1' then
	  	         if byte(3 downto 0) > 1001 then
	  	            D(7 downto 4) <= "0100";
	  	            D(3 downto 0) <= (byte(3 downto 0) - 1001); 
	  	        else 
	  	            D(7 downto 4) <= "0011";
	  	            D(3 downto 0) <= byte(3 downto 0); 
	  	        end if;
	  	        if count = 3 then -- if seqDone signal has previously been asserted
	  	            nextState <= FINAL_PRINT;
	  	        else
	  	            nextState <= PRINT_SECOND;
	  	        end if;
	  	    else
	  	        nextState <= WAIT_PRINT;
	  	    end if;
	  	    
	  	 WHEN PRINT_SECOND => -- prints the second number in byte to terminal
	  	    txData <= Q(7 downto 0);
	  	    txNow <= '1';
	  	    nextState <= WAITING;
	  	     
	  	 WHEN FINAL_PRINT => -- prints the final digit in the whole sequence
	  	    txData <= Q(7 downto 0);
	  	    txNow <= '1';
	  	    nextState <= IDLE;
	  	      	 	  	     	        
	  	 WHEN OTHERS => -- if undefined state, start again at IDLE
	  	    nextState <= IDLE;    	        
	  	 	  	     	             
      END CASE;
    END PROCESS;
    
         
    counter: PROCESS(clk)  -- simple counter keeps track of correct inputs, which values have already been printed (\n and \r) and if seqDone has been asserted 
     BEGIN  
       IF cntReset = True THEN -- active high reset
         count <= 0;
       ELSIF clk'EVENT and clk='1' THEN
         IF enCount = True THEN
           count <= count+1;
         END IF;
       END IF;
     END PROCESS;
        
    reg: PROCESS (clk, Q, D) -- simple edge triggered register (12 bits) that saves user input then ascii value of byte
     BEGIN
       IF clk'EVENT AND clk='1' THEN
         Q <= D;
       END IF;
     END PROCESS;
   
    seq_state: PROCESS (clk, reset) -- moves the state machine on everytime clock goes from 0 to 1
     BEGIN
       IF clk'EVENT AND clk='1' THEN
         curState <= nextState;
       END IF;
       IF reset = '1' then -- asynchronous reset (doesn't depend on clk)
         curState <= IDLE;
       END IF;
     END PROCESS;          
                                      
end Behavioral;


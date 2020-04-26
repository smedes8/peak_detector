library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;
use work.common_pack.all;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity cmdProc is
  Port ( 
  
    clk: in std_logic;
    reset: in std_logic;
    rxnow: in std_logic; -- 'VALID' SIGNAL in specification    
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
TYPE state_type is (IDLE, RNOW, COUNT_PLUS, COUNT_RES, START_TRANS, TRANS_DATA, WAITING, INPUT_CHECK, INPUT_GOOD, ACTIVATE,
                    RECIEVE, DATA_TERMINAL_ONE, PRINT_FIRST, WAIT_PRINT, DATA_TERMINAL_TWO, PRINT_SECOND, SEQ_DONE);   	
    SIGNAL curState, nextState: STATE_TYPE; 
    SIGNAL cntReset: std_logic;
    SIGNAL enCount: boolean;
    SIGNAL Q, D: std_logic_vector(11 downto 0);
    SIGNAL count: integer := 0;
    
begin
    combi_nextState: process(curState, rxnow, txdone, seqDone)
    begin
    -- Assigning values for the counter
      TxData <= "00000000";
      cntReset <= '0';
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
            elsif rxData >= "00110000" and rxData <= "00111001" then -- checks if the next characters are numbers
                if count = 1 then
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
	  	     	      
	  	 WHEN COUNT_PLUS =>
	  	    enCount <= True;
	  	    RxDone <= '1';
	  	    nextState <= START_TRANS;
	  	    
	  	 WHEN COUNT_RES =>
	  	    cntReset <= '1';
	  	    RxDone <= '1';
	  	    nextState <= START_TRANS;      
	  	     	              
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
	  	    cntReset <= '1';
	  	    numWords_bcd(0) <= Q(3 downto 0);
	  	    numWords_bcd(1) <= Q(7 downto 4);
	  	    numWords_bcd(2) <= Q(11 downto 8);
	  	    nextState <= WAITING; 
	  	   
	  	 WHEN WAITING =>  -- waits for txmodule to be ready
	  	    if txdone = '1' then
	  	        nextState <= ACTIVATE;
	  	    else 
	  	        nextState <= WAITING;
	  	    end if;
	  	   
	  	 WHEN ACTIVATE =>  -- asserts start for 1 clock cycle
	  	    start <= '1';
	  	    nextState <= RECIEVE; 
	  	   
	  	 WHEN RECIEVE => -- stops the data request and saves the data to a register when it is ready
	  	    start <= '0';
	  	    if dataReady <= '1' then	  	      
	  	        nextState <= DATA_TERMINAL_ONE;
	  	    else
	  	        nextState <= RECIEVE;
	  	    end if;
	  	    
	  	 WHEN DATA_TERMINAL_ONE =>
	  	    if byte(7 downto 4) > 1001 then
	  	        D(7 downto 4) <= "0100";
	  	        D(3 downto 0) <= (byte(7 downto 4) - 1001); 
	  	    else 
	  	        D(7 downto 4) <= "0011";
	  	        D(3 downto 0) <= byte(7 downto 4); 
	  	    end if;
	  	    nextState <= PRINT_FIRST;
	  	    
	  	 WHEN PRINT_FIRST =>
	  	    txData <= Q(7 downto 0);
	  	    txNow <= '1';
	  	    nextState <= WAIT_PRINT;
	  	    
	  	 WHEN WAIT_PRINT =>
	  	    txNow <= '0';
	  	    if txdone = '1' then
	  	        nextState <= DATA_TERMINAL_TWO;
	  	    else
	  	        nextState <= WAIT_PRINT;
	  	    end if;
	  	    
	  	 WHEN DATA_TERMINAL_TWO =>
	  	    if byte(3 downto 0) > 1001 then
	  	        D(7 downto 4) <= "0100";
	  	        D(3 downto 0) <= (byte(3 downto 0) - 1001); 
	  	    else 
	  	        D(7 downto 4) <= "0011";
	  	        D(3 downto 0) <= byte(3 downto 0); 
	  	    end if;
	  	    nextState <= PRINT_SECOND;
	  	    
	  	 WHEN PRINT_SECOND =>
	  	    txData <= Q(7 downto 0);
	  	    txNow <= '1';
	  	    nextState <= SEQ_DONE;
	  	 
	  	 WHEN SEQ_DONE =>	  	
	  	    txNow <= '0'; 
	  	    if seqDone = '1' then
	  	        nextState <= IDLE;
	  	    else
	  	        nextState <= WAITING;
	  	    end if;
	  	      	 	  	     	        
	  	 WHEN OTHERS =>
	  	    nextState <= IDLE;    	        
	  	 	  	     	             
      END CASE;
    END PROCESS;
    
         
    counter: PROCESS(clk)  -- counter used when checking the input characters from rx, counts up each time the character is correct (a or number) and resets when invalid input
     BEGIN
       IF cntReset = '1' THEN -- active high reset
         count <= 0;
       ELSIF clk'EVENT and clk='1' THEN
         IF enCount = TRUE THEN -- enable
           count <= count+1;
         END IF;
       END IF;
     END PROCESS;
        
    reg: PROCESS (clk, Q, D)
     BEGIN
       IF clk'EVENT AND clk='1' THEN
         Q <= D;
       END IF;
     END PROCESS;
   
    seq_state: PROCESS (clk, reset)
     BEGIN
       IF clk'EVENT AND clk='1' THEN
         curState <= nextState;
       END IF;
     END PROCESS;          
                                      
end Behavioral;

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
TYPE state_type is (IDLE, RNOW, COUNT_PLUS, COUNT_RES, START_TRANS, TRANS_DATA, INPUT_CHECK, INPUT_GOOD,
                    RECIEVE, DATA_TERMINAL);   	
    SIGNAL curState, nextState: STATE_TYPE; 
    SIGNAL cntReset: std_logic;
    SIGNAL enCount: boolean;
    SIGNAL Q, D: std_logic_vector(11 downto 0);
    SIGNAL count: integer := 0;
    
begin
    combi_nextState: process(curState, rxnow, seqDone)
    begin
    -- Assigning values for the counter
      
      cntReset <= '0';
      enCount <= False;
      rxDone <= '0';
      txNow <= '0';
     
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
	  	    TxNow <= '1'; 
	  	    nextState <= TRANS_DATA;
	  	    
	  	 WHEN TRANS_DATA => -- wait until the data has been printed to screen
	  	    if TxDone = '1' then
	  	        nextState <= INPUT_CHECK;
	  	    else
	  	        nextState <= TRANS_DATA;
	  	    end if;
	  	   
	  	 WHEN INPUT_CHECK => 
	  	    TxNow <= '0';
	  	    RxDone <= '0';
	  	    if count < 4 then -- Checks if the register contains axyz
	  	        nextState <= IDLE;
	  	    else 
	  	        nextState <= INPUT_GOOD;
	  	    end if;
	  	    
	  	 WHEN INPUT_GOOD =>
	  	    cntReset <= '1';
	  	    numWords_bcd(0) <= Q(3 downto 0);
	  	    numWords_bcd(1) <= Q(7 downto 4);
	  	    numWords_bcd(2) <= Q(11 downto 8);
	  	    nextState <= RECIEVE; 
	  	   
	  	 WHEN RECIEVE =>
	  	    TxNow <= '0';
	  	    start <= '1';
	  	    if dataReady <= '1' then
	  	        nextState <= DATA_TERMINAL;
	  	    else
	  	        nextState <= RECIEVE;
	  	    end if;
	  	    
	  	 WHEN DATA_TERMINAL =>
	  	    TxNow <= '1';
	  	    if TxDone <= '1' then
	  	        if seqDone <= '1' then 
	  	            nextState <= IDLE;
	  	        else 
	  	            nextState <= RECIEVE;
	  	        end if;
	  	   else
	  	        nextState <= DATA_TERMINAL;
	  	   end if;     
	  	        
	  	    
	  	 
	  	    
	  	  
	  	     	              
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
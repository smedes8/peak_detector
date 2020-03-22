
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;
use work.common_pack.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

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
TYPE state_type is (IDLE, START_TRANS, TRANS_DATA, INPUT_GOOD);   	
    SIGNAL curState, nextState: STATE_TYPE; 
    SIGNAL count: integer;
    SIGNAL cntReset: std_logic;
    SIGNAL enCount: boolean;
    SIGNAL Q, D: std_logic_vector(11 downto 0);
    SIGNAL num: std_logic_vector(3 downto 0);
    
begin
    combi_nextState: process(curState, rxnow, seqDone)
    begin
    -- Assigning variables for the counter
      count <= 0;
      enCount <= FALSE;
     
      CASE curState IS
      
        WHEN IDLE =>  -- need to consider L and P inputs also *implement later*
            cntReset <= '0';
            -- Converting ascii to bcd
            if rxdata(7 downto 4) = "0011" then
              if rxdata(3 downto 0) <= "1001" and rxdata(3 downto 0) >= "0000" then
                num <= rxdata(3 downto 0);
              end if;
            end if;
            
            if rxnow = '1' then  -- detect if rx has data to input
                if count = 0 then  -- checks if the first character is 'a' or 'A'
                    if rxData = "01000001" or rxData = "01100001" then
                        enCount <= TRUE;
                        nextState <= START_TRANS;
                    else
                      nextState <= START_TRANS;
                    end if;  
                elsif count = 1 then -- checks if 2nd is a number
                    if rxData >= "00110000" and rxData <= "00111001" then
                        D(3 downto 0) <= num;
                        enCount <= TRUE;
                        nextState <= START_TRANS;
                    else
                      nextState <= START_TRANS;
                    end if;
                elsif count = 2 then -- checks if 3rd character is a number
                    if rxData >= "00110000" and rxData <= "00111001" then
                        D(7 downto 4) <= num;
                        enCount <= TRUE;
                        nextState <= START_TRANS;
                    else
                      nextState <= START_TRANS;
                    end if;
                elsif count = 3 then -- checks if 4th character is a number  
                    if rxData >= "00110000" and rxData <= "00111001" then
                        D(11 downto 8) <= num;  
                        cntReset <= '1';                    
                        nextState <= INPUT_GOOD;
                    else
                      nextState <= START_TRANS;
                    end if;
                else
                    nextState <= START_TRANS;
                    cntReset <= '1';           
	            end if;
	  	    else
	  	       nextState <= IDLE;
	  	    end if;
	  	    
	  	    
	  	    
	  	     	               
      END CASE;
    END PROCESS;
    
         
    PROCESS(cntReset,clk)  -- counter used when checking the input characters from rx, counts up each time the character is correct (a or number) and resets when invalid input
       BEGIN
          IF cntReset = '1' THEN -- active high reset
              count <= 0;
           ELSIF clk'EVENT and clk='1' THEN
              IF enCount = TRUE THEN -- enable
                 count <= count + 1;
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

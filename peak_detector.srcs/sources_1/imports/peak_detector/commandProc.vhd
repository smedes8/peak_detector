----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 24.02.2020 11:51:34
-- Design Name: 
-- Module Name: commandProc - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

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
TYPE state_type is (IDLE, FIRST, SECOND);   	
    SIGNAL curState, nextState: STATE_TYPE; -- Simple state transtition table, logic for each state should be coded after this proccess
begin
    combi_nextState: process(curState, rxnow, seqDone)
    begin
      CASE curState IS
      
        WHEN IDLE =>
	      IF rxnow = '1' THEN
	        nextState <= FIRST;
	      ELSE
	        nextState <= IDLE;
	      END IF;
    
        WHEN FIRST =>
          nextState <= SECOND;
          
        WHEN SECOND =>
          IF seqDone = '1' THEN
            nextState <= IDLE;
          ELSE
            nextState <= SECOND;
          END IF; 
          
      END CASE;
    END PROCESS;
        
    echoToTerminal: process(curState, rxnow)  -- process to echo computer input to computer terminal during idle state
    begin
        IF curState = IDLE THEN
            txData <= rxData;
        END IF;
        
end Behavioral;

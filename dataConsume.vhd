library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use work.common_pack.all;
use IEEE.NUMERIC_STD.ALL;
library UNISIM;
use UNISIM.VComponents.all;

entity dataConsume is
    Port (
        clk:		  in std_logic;
		reset:		  in std_logic; -- synchronous reset
		start:        in std_logic; -- goes high to signal data transfer
		numWords_bcd: in BCD_ARRAY_TYPE(2 downto 0);
		ctrlIn:       in std_logic;
		ctrlOut:      out std_logic;
		data:         in std_logic_vector(7 downto 0);
		dataReady:    out std_logic;
		byte:         out std_logic_vector(7 downto 0);
		seqDone:      out std_logic;
		maxIndex:     out BCD_ARRAY_TYPE(2 downto 0);
		dataResults:  out CHAR_ARRAY_TYPE(0 to RESULT_BYTE_NUM-1) -- index 3 holds the peak
    );
end dataConsume;

architecture behav of dataConsume is
    type state_type is (IDLE,FETCH,WAIT_DATA,DATA_READY,GET_DATA,SEQ_DONE);
    signal currentstate,nextstate : state_type;
    signal dataReg: CHAR_ARRAY_TYPE(0 to 6);
    signal maxIndexReg: BCD_ARRAY_TYPE(2 downto 0);
    signal byteReg: CHAR_ARRAY_TYPE(0 to 3);
    signal ctrlInDelayed, ctrlInDetected, ctrlOutReg,numWordCount,PeakFound,enablePeakCount,ResetPeakCount,resetShifter,resetRegister,loadToLeft,loadToRight: std_logic;
    signal numWords: BCD_ARRAY_TYPE(2 downto 0);
    signal IntegerNumWords,bytecount: integer range 0 to 999;
    signal PeakCount: integer range 0 to 4;
    
begin

-----------------------------------------------------------------------------------------
--STATE PROCESSES

StateChange: process(currentState,start,ctrlInDetected,numWordCount) 
begin
resetShifter<='0';
resetRegister<='0';
	 -- assign defaults at the beginning to avoid assigning in every branch
    case currentState is
        
        when IDLE => 
        --resetShifter<='1';
        --resetRegister<='1';
            if start = '1' then --Start two phase protocol
                nextState <= FETCH;
            else --Wait for start = 1
                nextState <= IDLE;
            end if;            
            
        when FETCH => --Change CtrlOut and proceed to wait for change in CtrlIn
        nextState <= WAIT_DATA;         
        
        when WAIT_DATA => 
            if ctrlInDetected <= '1' then  --Data on btye line is valid
                nextState <= GET_DATA;
            else    --Wait for change in CtrlIn
                nextState <= WAIT_DATA;
            end if;           
            
        when GET_DATA =>
            nextState <= DATA_READY;
                        
        when DATA_READY =>
        if numWordcount = '1' then 
            nextState <= SEQ_DONE;
            elsif start ='1' then
            --Requests another byte
                nextState <= FETCH; 
            else 
            --Halts data retrieval while Command Processor communicates with PC
                nextState <= DATA_READY;
            end if;
                       
        when SEQ_DONE =>
        --Restarts system
        nextState <= IDLE;        
        
        when others =>
        nextState <= IDLE;
        end case;       
                
end process;


StateOutputs:	process (currentState)
begin 
case currentState IS
 when DATA_READY => 
 --Update output lines, signal data is valid 
	dataReady <= '1';
	byte <= byteReg(3);
 when SEQ_DONE =>
 --Tell Command Processor all bytes processed and peak found
    seqDone <= '1';
    dataResults<=dataReg;
    maxIndex <= maxIndexReg;
 when others =>
    dataReady <='0';
    seqDone <= '0';
  end case;

end process;


StateRegister:	process (clk)
begin
		if rising_edge (clk) then
			if (reset = '1') then
				currentState <= IDLE;
			else
				currentState <= nextState;
			end if;	
		end if;
end process;

-------------------------------------------------------------------------------------
--DATA RETRIEVAL 
----RequestData--- handshaking protocal here. if rising clock edge then reset and ctrl out register is set to 0 else if state is fetch
----ctrl out register <= not ctrl out reg else goes to ctrl out regisiter
RequestData: process(clk)
Begin
    if rising_edge(clk) then 
        if reset='1' then
            ctrlOutReg<='0';
        else
            if currentState = FETCH then
            --Chane on CtrlOut to start hand-shaking protocol
                ctrlOutReg <= not ctrlOutReg;
            else
            --No change in CtrlOut
                ctrlOutReg<= ctrlOutReg;
            
            end if;
        end if;
end if;
end process;


Delay_CtrlIn: process(clk)     
begin
    if rising_edge(clk) then
    --Used in XOR to detect a change in CtrlIn
      ctrlIndelayed <= ctrlIn;
    end if;
end process;  


NumWordsToInteger: process(numwords)
Begin
--Convert BCD to Integer
IntegerNumWords<=100*TO_INTEGER(unsigned(numwords(2)))+10*TO_INTEGER(unsigned(numwords(1)))+TO_INTEGER(unsigned(numwords(0)));
end process;


ByteCounter : process (clk)
begin
	if rising_edge(clk) then
		if reset ='1' then
		--Reset counter
			byteCount <= 0;
		else 	
		    if (byteCount = IntegerNumWords) then
		    --Reset counter
		      byteCount <= 0;
		     elsif currentState = GET_DATA then
		     --New valid byte received
				    byteCount <= byteCount + 1;
				else 
				--Wait for new byte
				    byteCount <= byteCount;
				end if;
			end if;
		end if;
end process;


SequenceComplete: process(byteCount,IntegerNumWords)
begin 
 if (bytecount = IntegerNumWords) then 
 --Byte Number = NumWords
            numWordCount <= '1';
     else 
     --Byte Number /= NumWords
        numWordCount <= '0';
end if;

end process;

--------------------------------------------------------------------------------------------
--PEAK DETECTION PROCESSES

dataShift: process(clk)
begin
if rising_edge(clk) then  
   if reset = '1' then
   for j in 0 to 3 loop
    byteReg(j) <= (others => '0');
    end loop;
    else 
        if currentState = GET_DATA then
             byteReg <= byteReg(1 to 3) & data;
        elsif resetShifter = '1' then 
            for k in 0 to 3 loop
            byteReg(k) <= (others => '0');
            end loop;
        end if;
    end if;
end if;
end process;


dataLatch: process(clk)
begin
if rising_edge(clk) then  
   if reset = '1' then
   for i in 0 to 6 loop
    dataReg(i) <= (others => '0');
    end loop;
    else 
         if loadToLeft = '1' then 
        dataReg(0 to 3) <= byteReg;
        elsif loadToRight ='1' then 
        dataReg(4 to 6) <= byteReg(1 to 3);
        elsif resetRegister = '1' then 
            for l in 0 to 6 loop
            dataReg(l) <= (others => '0');
            end loop;
        end if;
    end if;
  end if;
end process;


SignalOutput: process(reset,PeakFound,PeakCount) 
begin
loadToRight<='0';
    if reset = '1' then 
        enablePeakCount <= '0';
        ResetPeakCount <= '0';
    else    
        if PeakFound ='1' then 
            enablePeakCount <= '1';
         else 
            if PeakCount = 3 then
                loadToRight<='1';
                enablePeakCount<='0';
                ResetPeakCount <= '1';
            else
                ResetPeakCount<='0';
            end if;
       end if;
      end if;
end process;


DataCounter: process(clk) 
begin 
if rising_edge(clk) then
    if reset = '1' or PeakFound = '1' then 
        PeakCount<=0;
     else  
        if ResetPeakCount = '1' then 
            peakCount<=0;
        else
            if enablePeakCount = '1' then 
                if currentState = GET_DATA then 
                    PeakCount<=PeakCount+1;
                end if;
        end if;
        end if;
     end if;
 end if;
end process;   
     
     
Comparator: process(byteReg,dataReg,reset) 
begin
loadToLeft<='0';
PeakFound <= '0';
if TO_INTEGER(unsigned(byteReg(3))) > TO_INTEGER(unsigned(dataReg(3))) then 
    PeakFound <= '1';
    loadToLeft<='1';
end if;
end process;


Peak_index: process(clk)
begin
if rising_edge(clk) then 
    if reset = '1' then 
    for m in 0 to 2 loop
        maxIndexReg(m)<= (others=>'0');
    end loop;
    else    
        if PeakFound = '1' then 
            maxIndexReg(2) <= std_logic_vector(TO_UNSIGNED(((byteCount-1)/100),4));
            maxIndexReg(1) <= std_logic_vector(TO_UNSIGNED((((byteCount-1) mod 100)/10),4));
            maxIndexReg(0) <= std_logic_vector(TO_UNSIGNED(((byteCount-1) mod 10),4));
         end if;
   end if;
 end if;
end process;
       



  
--High of CtrlIn changes
ctrlIndetected <= ctrlIn xor ctrlIndelayed;
--Output to dataGen
ctrlOut <= ctrlOutReg;
--Sends input to be converted to integer
numWords<=numwords_bcd;

end behav;

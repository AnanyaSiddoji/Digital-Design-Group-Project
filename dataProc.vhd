LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.std_logic_unsigned.ALL;
USE work.common_pack.ALL;
USE ieee.numeric_std.ALL;
-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

------------------------------------------------------
ENTITY dataProc is
Port (
	clk:	in std_logic;
	reset:	in std_logic; -- synchronous reset
	start:	in std_logic; -- goes high to signal data transfer
	numWords_bcd	:in BCD_ARRAY_TYPE(2 downto 0);
  	ctrl2:   	in std_logic;
  	ctrl1:		out std_logic;
  	data_in:	in std_logic_vector(7 downto 0);
  	dataReady:   	out std_logic;
  	byte:	        out std_logic_vector(7 downto 0);
  	seqDone:     	out std_logic;
  	maxIndex:	out BCD_ARRAY_TYPE(2 downto 0);
  	dataResults: 	out CHAR_ARRAY_TYPE(0 to RESULT_BYTE_NUM-1) -- index 3 holds the peak  
);
end;
---------------------------------------------------------
architecture behav of dataProc is
	type state_type is (IDLE,FETCH,WAIT_DATA,DATA_READY,RECIEVE_DATA,SEQ_DONE);
	signal currentstate,nextstate : state_type;
	signal dataReg: CHAR_ARRAY_TYPE(0 to 6);
	signal maxIndexReg: BCD_ARRAY_TYPE(2 downto 0);
	signal byteReg: CHAR_ARRAY_TYPE(0 to 3);
	signal ctrlInDelayed, ctrlInDetected, ctrlOutReg,numWordCount,PeakFound,enablePeakCount,ResetPeakCount,resetShifter,resetRegister,loadLeft,loadRight: std_logic;
	signal numWords: BCD_ARRAY_TYPE(2 downto 0);
	signal IntegerNumWords,bytecount: integer range 0 to 999;
	signal PeakCount: integer range 0 to 4;

	--signal maxData		: std_logic_vector(7 downto 0):=(others=>'0');
	--signal dataResult_buffer_register : std_logic_vector (55 downto 0):=(others => '0');
	--signal dataResult 	: std_logic_vector (55 downto 0):=(others => '0');
	--signal BCD_counter, max_index                   : BCD_ARRAY_TYPE(2 downto 0):=(others=>(others=>'0'));
  	--SIGNAL BCD_cnt1, BCD_cnt2, BCD_cnt3, BCD_cnt4  : BCD_ARRAY_TYPE(2 downto 0):=(others=>(others=>'0'));
  	--SIGNAL countUp   : std_logic :='0';

--------------------------------------------------------------------------------------------------------
begin 
nextState: Process(clk) --this is draft
begin
	if rising_edge(clk) then 
		if reset = '1' then
			ctrlOut <= '0' then
			state <= s0;
		else
			
	case curState is 
		when s0 =>
			if start = '1' then
				nextState <= s1;
			else
				nextState <= s0;
			end if;
		when s1 =>
			if ctrl1 = '1' then
				nextState <= s2;
			else
				nextState <= s1;		
			end if;
		when s2 =>
			ctrl1 <= '0';
			if ctrl2 = '1' then
				nextState <= s3;
			else
				nextState <= s2;
			end if;		
		when s3 =>
			if counter = numWords then
				nextState <= s4;
			elsif counter < numWords 
				nextState <= s0;
			else 
				err;
			end if;			
		when s4 =>
			seqDone = '1';
			 

end process;
------------------------------------------------------------------
seq_state: process (clk, reset)
begin
	if reset = '1' then
		curState <= s0;
	elsif clk'EVENT AND clk='1' then
		curState <= nextState;
	end if;
end process; -- ends seq process
------------------------------------------------------------------
buffer_reg: process (clk, reset) -- i was about to implement buffer register beforehand
begin
	if reset = '1' then
		dataResult_buffer_register <= (others => '0');
	elsif rising_edge(clk) then 
		dataResult_buffer_register(2 downto 0) <= "00000000";
	end if;
end process;	

-------------------------------------------------------------------

dataReg: process (clk, reset)
begin
	if reset = '1' then
		dataResult  <= (others => '0');
	elsif rising_edge(clk) then 
		dataResult_buffer_register(2 downto 0) <= "00000000";
	end if;
end process;	



--------------- PEAK DETECTION PART
StateChange: process(currentState,start,ctrlInDetected,numWordCount) 
begin
resetShifter<='0';
resetRegister<='0';
	 -- assign defaults at the beginning to avoid assigning in every branch
    case currentState is
        
        when IDLE => 
        resetShifter<='1';
        resetRegister<='1';
            if start = '1' then
                nextState <= FETCH;
            else 
                nextState <= IDLE;
            end if;            
            
        
        when RECIEVE_DATA =>
            nextState <= DATA_READY;

	when FETCH =>
        nextState <= WAIT_DATA;         
        
        when WAIT_DATA => 
            if ctrlInDetected <= '1' then
                nextState <= RECIEVE_DATA;
            else 
            --Wait for change in CtrlIn
                nextState <= WAIT_DATA;
            end if;           
            
                        
        when DATA_READY =>
        if numWordcount = '1' then 
            nextState <= SEQ_DONE;
            elsif start ='1' then
            --Requests another byte
                nextState <= FETCH; 
            else 
                nextState <= DATA_READY;
            end if;
                       
        when SEQ_DONE =>
        --Restarts system
        nextState <= IDLE;        
        
        when others =>
        nextState <= IDLE;
        end case;       
                
end process;


StateOutput:	process (currentState)
begin 
case currentState IS
 when DATA_READY => 
	dataReady <= '1';
	byte <= byteReg(3);
 when SEQ_DONE =>
 --Tells the Command Processor all bytes processed and peak found
    seqDone <= '1';
    dataResults<=dataReg;
    maxIndex <= maxIndexReg;
 when others =>
    dataReady <='0';
    seqDone <= '0';
  end case;

end process;

--register stateRegister use by storing the input data from the signal generator.                
StateRegister:	process (clk, reset)
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
ataRequest: process(clk, rst)
begin
        if rising_edge(clk) then
            state <= IDLE;
            ctrl1 <= '0';
            case state is
                when IDLE =>
                    if ctrl2 = '1' then
                        state <= REQUEST;
                        ctrl1 <= '1';
                    else
                        state <= IDLE;
                        ctrl1 <= '0';
                    end if;
                when REQUEST =>
                    state <= WAIT_ctrl2;
                    ctrl1 <= '0';
                when WAIT_ctrl2 =>
                    if ctrl2 = '0' then
                        state <= IDLE;
                        ctrl1 <= '0';
                    else
                        state <= WAIT_ctrl2;
                        ctrl1 <= '0';
                    end if;
            end case;
        end if;
    end process;

---Delay CtrlIn -- if clock is no rising edge then ctrlInDelayed <= ctrlIn


---numWordsToInteger--- convert BCD to Integer
BCD_to_binary: process(numWords_bcd)
begin
        n1 := "0001010" * unsigned(numWords_bcd(1)); -- first BCD digit multiplied by 100
        n2 := "1100100" * unsigned(numWords_bcd(2)); -- second BCD digit multiplied by 10
        sum := std_logic_vector(unsigned(numWords_bcd(0)) + product1 + product2);
        numWords_bin <= sum(9 downto 0); 
    end process;   

---ByteCounter -- if clock is on rising edge and if reset is 1 then reset byte counter else if byte count = number of words reset counter
------------------else if the curret state is retreicing data then add one to byte count or wait for new byte (byte count remains same)


---SequenceComplete - checking if byte number = numebr of words and setting WordCound to 1 if so or 0 if not.
--------------------------------------------------------------------------------------------
--MY PEAK DETECTION PART

dataShift: process(clk)
begin
if rising_edge(clk) then  
   if reset = '1' then
   for j in 0 to 3 loop
    byteReg(j) <= (others => '0');
    end loop;
    else 
        if currentState = RECIEVE_DATA then
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
        if loadLeft = '1' then 
        dataReg(0 to 3) <= byteReg;
        elsif loadRight ='1' then 
            dataReg(4 to 6) <= byteReg(1 to 3);
        elsif reset_register = '1' then 
            for l in 0 to 6 loop
            dataReg(l) <= (others => '0');
            end loop;
        end if;
    end if;
  end if;
end process;


SignalOutput: process(reset,PeakFound,PeakCount) 
begin
loadRight<='0';
    if reset = '1' then 
        enablePeakCount <= '0';
        resetPeakCount <= '0';
    else    
        if PeakFound ='1' then 
            enablePeakCount <= '1';
         else 
            if PeakCount = 3 then
                loadRright<='1';
                enablePeakCount<='0';
             	resetPeakCount<= '1';
            else
                resetPeakCount<='0';
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
        if resetPeakCount = '1' then 
            peakCount<=0;
        else
            if enablePeakCount = '1' then 
                if currentState = RECIEVE_DATA then 
                    PeakCount<=PeakCount+1;
                end if;
        end if;
        end if;
     end if;
 end if;
end process;   
     
     
Comparator: process(byteReg,dataReg,reset) 
begin
loadLeft<='0';
Peakfound <= '0';
if TO_INTEGER(unsigned(byteReg(3))) > TO_INTEGER(unsigned(dataReg(3))) then 
    Peakfound <= '1';
    loadLeft<='1';
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
            MaxIndexReg(2) <= std_logic_vector(TO_UNSIGNED(((byteCount-1)/100),4));
            MaxIndexReg(1) <= std_logic_vector(TO_UNSIGNED((((byteCount-1) mod 100)/10),4));
            MaxIndexReg(0) <= std_logic_vector(TO_UNSIGNED(((byteCount-1) mod 10),4));
         end if;
   end if;
 end if;
end process;
       



  
--High of CtrlIn changes
ctrlInDetected <= ctrlIn xor ctrlInDelayed;
--Output to dataGen
ctrlOut <= ctrlOutReg;
--Sends input to be converted to integer
numWords<=numWordsBcd;

end Behavioral;	

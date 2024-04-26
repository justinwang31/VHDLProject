library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ProjectAssigment is
    Port (
        clk0, clk1, active: in std_logic;
        x: in std_logic_vector(7 downto 0);
        a_to_g: out std_logic_vector(6 downto 0); -- to control a 7-segment display
        Rr: out std_logic_vector(3 downto 0) -- to display the contents of Rr
    );
end ProjectAssigment;

architecture Behavioral of ProjectAssigment is
    type Register_Type is array(0 to 3) of std_logic_vector(3 downto 0);
    signal registers: Register_Type := (others => (others => '0'));
    signal display: std_logic_vector(6 downto 0);
    signal display_control: natural range 0 to 3 := 0; -- To control the 7-segment display logic
    signal alu_result: std_logic_vector(3 downto 0);
    
    signal instruction: std_logic_vector(7 downto 0);
    signal instruction_latch: std_logic_vector(7 downto 0) := (others => '0');
    signal opcode: std_logic_vector(1 downto 0);
    signal reg_select: std_logic_vector(1 downto 0);
    signal target_register: std_logic_vector(1 downto 0);
    signal operand: std_logic_vector(3 downto 0);
    signal reg_index_operand: std_logic_vector(1 downto 0);

    function to_index(signal bits: std_logic_vector(1 downto 0)) return natural is
    begin
        return to_integer(unsigned(bits));
    end function;

    function to_7segment(input_value: std_logic_vector(3 downto 0)) return std_logic_vector is
        variable result: std_logic_vector(6 downto 0);
    begin
        case input_value is
            when "0000" => result := "0000001"; -- '0'
            when "0001" => result := "1001111"; -- '1'
            when "0010" => result := "0010010"; -- '2'
            when "0011" => result := "0000110"; -- '3'
            when "0100" => result := "1001100"; -- '4'
            when "0101" => result := "0100100"; -- '5'
            when "0110" => result := "0100000"; -- '6'
            when "0111" => result := "0001111"; -- '7'
            when "1000" => result := "0000000"; -- '8'
            when "1001" => result := "0000100"; -- '9'
            when others => result := "1111111"; -- Default or undefined
        end case;
        return result;
    end function;

begin
    -- Update the instruction with the input signal 'x'
    instruction <= x; 

    -- Latch the instruction with the clk1 signal
    Instruction_Latch_Process: process(clk1)
    begin
        if rising_edge(clk1) and active = '0' then
            instruction_latch <= instruction;
            -- Decode and update the opcode, reg_select, and target_register immediately after latching
            opcode <= instruction_latch(7 downto 6);
            reg_select <= instruction_latch(5 downto 4);
            target_register <= instruction_latch(3 downto 2);
        end if;
    end process Instruction_Latch_Process;

    -- ALU Operations controlled by clk0 and active signal
    ALU_and_State_Process: process(clk0)
    begin
        if rising_edge(clk0) and active = '0' then
            -- Update the operand or reg_index_operand based on the instruction type
            case opcode is
                when "00" =>  -- LD operation
                    operand <= instruction_latch(3 downto 0);  -- Use as immediate value
                when "10" =>  -- MV or SB operation uses reg_index_operand
                    reg_index_operand <= instruction_latch(1 downto 0);  -- Use as register index
                when others =>
                    operand <= (others => '0');  -- Default for other operations
            end case;
            
            -- Perform the operation based on the opcode
            case opcode is
                when "00" =>  -- LD operation
                    registers(to_index(target_register)) <= operand;
                when "01" =>  -- ADD operation
                    alu_result <= std_logic_vector(unsigned(registers(to_index(reg_select))) +
                                  unsigned(registers(to_index(target_register))));
                    registers(to_index(target_register)) <= alu_result;
                when "10" =>  -- MV or SB operation based on reg_select
                    if reg_select = "00" then  -- MV operation
                        -- Move contents of register Ri to Rj
                        registers(to_index(target_register)) <= registers(to_index(reg_index_operand));
                    elsif reg_select = "01" then  -- SB operation
                        -- Subtract contents of register Rj from Ri and store in Ri
                        alu_result <= std_logic_vector(unsigned(registers(to_index(reg_select))) -
                                      unsigned(registers(to_index(target_register))));
                        registers(to_index(target_register)) <= alu_result;
                    end if;
                when "11" =>  -- AND or OR operation based on reg_select
                    if reg_select = "00" then  -- AND operation
                        registers(to_index(target_register)) <= registers(to_index(reg_select)) and registers(to_index(target_register));
                    elsif reg_select = "01" then  -- OR operation
                        registers(to_index(target_register)) <= registers(to_index(reg_select)) or registers(to_index(target_register));
                    end if;
                when others =>
                    null; -- Handle undefined opcodes or invalid states
            end case;
        end if;
    end process ALU_and_State_Process;

    -- Display handling controlled by clk1 and active signal
    Display_Process: process(clk1)
    begin
        if rising_edge(clk1) and active = '0' then
            -- Handle display based on the display_control signal and DS instruction
            if display_control /= 0 then
                display <= to_7segment(registers(display_control));
                -- Reset display control to show R0 on the next clock cycle
                display_control <= 0;
            else
                display <= to_7segment(registers(0));
            end if;

            -- Latch the target register if a DS instruction was executed
            if opcode = "11" and reg_select = "01" and instruction_latch(1 downto 0) /= "00" then
                display_control <= to_index(instruction_latch(1 downto 0));
            end if;
        end if;
    end process Display_Process;

    -- Output assignments
    a_to_g <= display;
    Rr <= registers(to_index(target_register));
end Behavioral;

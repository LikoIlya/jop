--
--	lego_motor.vhd
--
--	Motor and sensor interface for LEGO MindStorms
--	
--	Author: Peter Hilber				peter.hilber@student.tuwien.ac.at
--
--	2006-12-05      Created
--
--	todo:
--
--

--
--	lego_motor
--
--	sigma delta AD converter, power switch, and PWM generator
--	for the LEGO motor.
--	



library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.lego_pack.all;

entity lego_motor is

  generic (duty_cycle_width: integer; counter_width: integer;
  ld_ratio_measure_to_pwm: integer; dout_width: integer; clksd_prescaler_width: integer; clkint_prescaler_width: integer);	-- TODO if not fine-grained enough, use
  -- individual lengths

  port (
    clk		: in std_logic;
    reset	: in std_logic;
    
    state	: in lego_motor_state;
    duty_cycle	: in unsigned(duty_cycle_width-1 downto 0);
    measure :       in std_logic;   							-- perform back-EMF measurement?
    
    dout_1	: out std_logic_vector((dout_width-1) downto 0);  	-- back-EMF measurement value
    dout_2	: out std_logic_vector((dout_width-1) downto 0);  	-- back-EMF measurement value       

    -- assigned to pins
    
    -- motor steering
    men		: out std_logic;
    mdir	: out std_logic;
    mbreak	: out std_logic;
    
    -- back-EMF measurement pins
    mdia	: in std_logic;
    mdoa	: out std_logic;
    mdib	: in std_logic;
    mdob	: out std_logic
    );
end lego_motor ;

architecture rtl of lego_motor is
  signal pwm_out : std_logic;
  signal counter : unsigned(counter_width-1 downto 0);

  signal power_off : std_logic;         -- 1 disables PWM output
  signal measuring : std_logic;       -- 1 while back-EMF measurement is made
  
  signal clksd : std_logic;           -- clock for reading sdi
  signal clkint : std_logic;          -- clock for returning adc value
  
  component sigma_delta
    generic (
      dout_width : integer := dout_width);
    port (
      clk    : in  std_logic;
      reset  : in  std_logic;
      clksd  : in  std_logic;
      clkint : in  std_logic;
      dout   : out std_logic_vector((dout_width-1) downto 0);
      sdi    : in  std_logic;
      sdo    : out std_logic);
  end component;
  
begin
  

  cmp_1_sigma_delta: sigma_delta
    port map (
      clk    => clk,
      reset  => reset,
      clksd  => clksd,
      clkint => clkint,
      dout   => dout_1,
      sdi    => mdia,
      sdo    => mdoa);

  cmp_2_sigma_delta: sigma_delta
    port map (
      clk    => clk,
      reset  => reset,
      clksd  => clksd,
      clkint => clkint,
      dout   => dout_2,
      sdi    => mdib,
      sdo    => mdob);
  
  count: process(clk, reset)
  begin
    if reset = '1' then
      counter <= (others => '0');
    elsif rising_edge(clk) then
      counter <= counter + 1;
    end if;
  end process;

  clksd <= '1' when (measuring = '1') and (counter(clksd_prescaler_width-1 downto 0) = 0) else '0';
  clkint <= '1' when (measuring = '1') and (counter(clkint_prescaler_width-1 downto 0) = 0) else '0';

  power_off <= '1' when measure = '1' and counter(clkint_prescaler_width+1+ld_ratio_measure_to_pwm-1 downto clkint_prescaler_width+1)
	= (counter(clkint_prescaler_width+1+ld_ratio_measure_to_pwm-1 downto clkint_prescaler_width+1)'range => '1') else '0';

  measuring <= '1' when power_off = '1' and not (counter(clkint_prescaler_width) = '0') else '0';
  
  asynch: process(counter, duty_cycle)
  begin
		if counter(duty_cycle_width-1 downto 0) = duty_cycle then
			pwm_out <= '0';
		elsif counter(duty_cycle_width-1 downto 0) = (duty_cycle_width-1 downto 0 => '0') then
			pwm_out <= '1';
		end if;
		
		-- this causes Java program to crash, reason unknown
        --if counter(duty_cycle_width-1 downto 0) <= duty_cycle then
        --    pwm_out <= '1';
        --else
        --    pwm_out <= '0';
        --end if;
   end process;


  output: process(power_off, pwm_out, state)                     
                                                                 
  begin
    men <= '0';
    mdir <= '0';
    mbreak <= '0';

	if state = LEGO_MOTOR_STATE_BRAKE then
		men <= '1';
		mbreak <= '1';
	else    
      if power_off = '1' then
	    null;
      else
        if pwm_out = '1' then
          case state is
            when LEGO_MOTOR_STATE_BACKWARD =>
		  	  men <= '1';
			  mdir <= '1';
            when LEGO_MOTOR_STATE_FORWARD => 
              men <= '1';
            when others =>
		  	  null;
          end case;
        end if;
      end if;
	end if;
  end process output;

end rtl;

















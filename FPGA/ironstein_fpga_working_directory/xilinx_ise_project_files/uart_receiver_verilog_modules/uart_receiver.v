`timescale 1ps / 1ps

`include "counter.v"
`include "pulse_generator.v"
`include "sampling_tick_generator.v"
`include "serial_input_parallel_output_shift_register.v"

module uart_receiver ();
	// (
	// input wire clk,
	// input wire rx,
	// output reg [7:0] data,
	// output wire read_finish
	// );
	
	reg clk;
	reg rx;
	wire [7:0] data;
	reg read_finish;

	initial begin
		clk = 1'b0;
		rx = 1'b1;
	end

	initial begin
//		$dumpfile("simulation.vcd");
		$dumpvars(0,
			clk,
			rx,
			sample_tick,
			generate_counter_reset_pulse,
			counter_reset_pulse,
			counter_count,
			counter_overflow,
			generate_sipo_shift_register_start_pulse,
			sipo_shift_register_start_pulse,
			state,
			serial_data_conversion_complete,
			serial_data
			);
	end

	always 
		#1 clk = ~ clk;

	initial begin
		#10 rx = 0;
		#10 rx = 1;
		#17000 rx = 0;
	end
	
	initial begin
		#1000000 $finish;
	end
	// ---------------------------------- signal declarations ------------------------------------------

	// counter signal declarations
		wire counter_reset_pulse;
		wire [COUNTER_SIZE-1:0] counter_count;

	// counter reset pulse generator signal declarations
		// reg generate_counter_reset_pulse = 1'b0;
		reg generate_counter_reset_pulse;
	// sipo shift register start pulse generator signal declarations
		// reg generate_sipo_shift_register_start_pulse = 1'b0;
		reg generate_sipo_shift_register_start_pulse;
	// sampling tick generator signal declarations
		wire sample_tick;

	// serial input parallel output shift register signal declarations
		wire counter_overflow;
		wire sipo_shift_register_start_pulse;
		wire [NUMBER_OF_DATA_BITS_PER_PACKET-1:0] serial_data;
		wire serial_data_conversion_complete;
		
		assign data = serial_data;
	
	// --------------------------------- module instantiations ------------------------------------------

	//counter module instantiation
		localparam COUNTER_SIZE = 5;
		localparam COUNTER_OVERFLOW_VALUE = 15;	// OVERFLOW AFTER COUNT == 15 (JUST BEFORE COUNT == 16)

		counter #(.N(COUNTER_SIZE),.OVERFLOW_VALUE(COUNTER_OVERFLOW_VALUE)) 
			c(
				.clk(clk),
				.count_increment_clk(sample_tick),
				.reset(counter_reset_pulse),
				.count(counter_count),
				.overflow(counter_overflow)
			);

	// counter reset pulse generator module instantiation
		localparam COUNTER_RESET_PULSE_WIDTH = 5;

		pulse_generator #(.PULSE_WIDTH(COUNTER_RESET_PULSE_WIDTH))
			counter_reset_pulse_generator(
					.clk(clk),
					.generate_pulse(generate_counter_reset_pulse),
					.pulse(counter_reset_pulse)
				);

	// sipo shift register start pulse generator module instantiation
		localparam SIPO_SHIFT_REGISTER_START_PULSE_WIDTH = 5;
		pulse_generator #(.PULSE_WIDTH(SIPO_SHIFT_REGISTER_START_PULSE_WIDTH))
			sipo_shift_register_start_pulse_generator(
				.clk(clk),
				.generate_pulse(generate_sipo_shift_register_start_pulse),
				.pulse(sipo_shift_register_start_pulse)
			);

	//sampling tick generator module instantiation
		localparam BAUDRATE = 112000;
		localparam FREQUENCY = 100000000;

		sampling_tick_generator #(.baudrate(BAUDRATE),.frequency(FREQUENCY))
			tick_generator(
				.clk(clk),
				.tick(sample_tick)
			);

	// serial input parallel output shift register module instantiation
		localparam NUMBER_OF_DATA_BITS_PER_PACKET = 8;	
		
		serial_input_parallel_output_shift_register #(.N(NUMBER_OF_DATA_BITS_PER_PACKET))
			sr(
				.clk(clk),
				.shift_register_tick(counter_overflow),
				.start(sipo_shift_register_start_pulse),
				.s_in(rx),
				.finish(serial_data_conversion_complete),
				.data(serial_data)
			);

	// ----------------------------------------------------------------------------------------------

	// state declarations
	localparam 
		idle = 2'b00,
		start = 2'b01,
		read = 2'b10,
		stop = 2'b11;

	// signal declarations 
	reg [1:0] state = idle;
	reg [1:0] next_state = idle;
	localparam NUMBER_OF_STOP_BITS = 1;
	// localparam STOP_STATE_COUNTER_THERSHOLD = NUMBER_OF_STOP_BITS * 16;
	wire [15:0] STOP_STATE_COUNTER_THERSHOLD = 16;
	
//	// initial signal value allocations
//	initial begin
//		generate_counter_reset_pulse = 1'b0;
//		generate_sipo_shift_register_start_pulse = 1'b0;
//	end

	// state updation
	always @(posedge(clk)) begin
		state = next_state;
		generate_counter_reset_pulse = 0;				// check output 
		generate_sipo_shift_register_start_pulse = 0; 	// check output
	end

	// next state logic
	always @* begin
		next_state = state;
		case(state) 
			idle : 
				if(rx == 0) begin
					generate_counter_reset_pulse <= ~ generate_counter_reset_pulse;
					next_state <= start;
				end

			start :
				if(counter_count == 8) begin
					generate_counter_reset_pulse <= ~ generate_counter_reset_pulse;
					generate_sipo_shift_register_start_pulse <= ~ generate_sipo_shift_register_start_pulse;
					next_state <= read;
				end

			stop :
				if(counter_count == 31) begin
					read_finish <= 1;
					next_state <= idle;
				end

		endcase 

	end

	// read next state logic
	always @(posedge(serial_data_conversion_complete)) begin
		if(state == read) begin
			// data <= serial_data;
			generate_counter_reset_pulse <= ~ generate_counter_reset_pulse;
			next_state <= stop;
		end
	end


endmodule
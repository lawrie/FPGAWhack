// 
// Copyright 2013 Jeff Bush
// 
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// 
//     http://www.apache.org/licenses/LICENSE-2.0
// 
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
// 

`default_nettype none
module top(
	input         clk25_mhz,
	output  [7:0] leds,
	output  [3:0] gpdi_dp
);

	// ===============================================================
	// // System Clock generation
	// // ===============================================================
	wire locked;
	wire [3:0] clocks;

	ecp5pll #( 
		.in_hz( 25*1000000),
		.out0_hz(125*1000000),
		.out1_hz(25*1000000),
		.out2_hz(50*1000000), 
		.out3_hz(125*1000000),
	) ecp5pll_inst (
		.clk_i(clk25_mhz),
		.clk_o(clocks),
		.locked(locked)
 	 );

	wire clk = clocks[2];
	wire clk_vga = clocks[1];
	wire clk_hdmi = clocks[0];
	wire vsync_o;
	wire hsync_o;
	wire [3:0] red_o;
	wire [3:0] blue_o;
	wire [3:0] green_o;

	localparam NUM_PIXELS = 8;	// How many are computed in parallel
	localparam PIXEL_WIDTH = 12;

	wire in_visible_region;
	wire pixel_out;
	wire new_frame;
	wire fifo_almost_empty;
	wire fifo_empty;
	wire[NUM_PIXELS * PIXEL_WIDTH - 1:0] fifo_in;
	wire[PIXEL_WIDTH - 1:0] fifo_out;
	wire pixels_ready;
	wire start_next_batch = pixels_ready && (fifo_almost_empty || fifo_empty)
		&& pixel_out;

	vga_timing_generator vga_timing_generator(
		.clk(clk),
		.vsync_o(vsync_o),
		.hsync_o(hsync_o),
		.in_visible_region(in_visible_region),
		.pixel_out(pixel_out),
		.new_frame(new_frame));

	pixel_fifo #(.NUM_PIXELS(NUM_PIXELS), .PIXEL_WIDTH(PIXEL_WIDTH)) pixel_fifo(
		.clk(clk),
		.reset(new_frame),
		.almost_empty(fifo_almost_empty),
		.empty(fifo_empty),
		.enqueue(start_next_batch),
		.value_in(fifo_in),	
		.dequeue(pixel_out),
		.value_out(fifo_out));

	pixel_processor #(.NUM_PIXELS(NUM_PIXELS), .PIXEL_WIDTH(PIXEL_WIDTH)) pixel_processor(
		.clk(clk),
		.new_frame(new_frame),
		.result(fifo_in),
		.start_next_batch(start_next_batch),
		.result_ready(pixels_ready));

	assign red_o = in_visible_region ? fifo_out[11:8] : 0;
	assign blue_o = in_visible_region ? fifo_out[7:4] : 0;
	assign green_o = in_visible_region ? fifo_out[3:0] : 0;

	reg [7:0] diag;
	always @(posedge clk) if (pixels_ready) diag <= fifo_in[7:0];

	//assign leds = fifo_in[7:0];
	assign leds = diag;

	// ==============================================================
	// // Convert VGA to HDMI
	// // ===============================================================
	HDMI_out vga2dvid (
		.pixclk(clk_vga),
		.pixclk_x5(clk_hdmi),
		.red  ({red_o, 4'b0}),
		.green({green_o, 4'b0}),
		.blue ({blue_o, 4'b0}),
		.vde  (in_visible_region),
		.hSync(hsync_o),
		.vSync(vsync_o),
		.gpdi_dp(gpdi_dp),
		.gpdi_dn()
	);

endmodule

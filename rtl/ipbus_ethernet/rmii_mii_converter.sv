// Copyright (c) 2025 Ludovic Damien Blanc
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
// The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.



//  rmii_mii_converter 
//  Author: Delphine Allimann, maintained by Ludovic Damien Blanc
//  EPFL - TCL 2025
// Ludovic Blanc 2026
`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * physical RMII to MII converter
 */


module rmii_mii_converter
(
    input  wire rst, // if sync, should be sync with rmii_ref_clk
    input wire rst_mii,
    /*
     * MII interface
     */
    output  reg                      clk_gate_en_rmii,
    output  reg [3:0]                mii_rxd,
    output  reg                      mii_rx_dv,
    output  reg                      mii_rx_er,
    input   wire [3:0]               mii_txd,
    input   wire                     mii_tx_en,
    input   wire                     mii_tx_er,

    /*
     * RMII interface
     */
    input  wire [1:0]                rmii_rxd,
    input  wire                      rmii_rx_er,  
    input  wire                      rmii_crs_dv,
    output reg [1:0]                 rmii_txd,
    output reg                       rmii_tx_en,

    input  wire                      rmii_ref_clk

);

// Create mii clk

reg mii_valid; 


assign clk_gate_en_rmii = mii_valid;

// always_ff @(posedge rmii_ref_clk) begin 
//     mii_valid <= !mii_valid;
// end

always_ff @(posedge rmii_ref_clk, posedge rst) begin 
    if (rst) begin
        mii_valid <= 1'b1;
    end else begin
        mii_valid <= !mii_valid;
    end
end


//RECEIVE
//useful signals/reg
reg [3:0] mii_rxd_reg;
reg       mii_rx_dv_reg;
reg       mii_rx_er_reg;

reg [3:0] mii_rxd_next;
reg [3:0] mii_rxd_next_reg;
reg [3:0] mii_rxd_int;  //intermediate register for receive synchronous
reg [3:0] mii_rxd_int_reg;

reg       mii_rx_dv_next;
reg       mii_rx_dv_next_reg;
reg       mii_rx_er_next;

reg [1:0] rmii_rxd_reg;
reg       rmii_crs_dv_reg;

//assign to output
assign mii_rxd   = mii_rxd_reg;
assign mii_rx_dv = mii_rx_dv_reg;
assign mii_rx_er = mii_rx_er_reg;


//FSM with 5 states : idle, receive sync, receive async, receive preamble sync, receive preamble async

localparam [2:0]
    STATE_IDLE = 3'd0,
    STATE_RX_SYNC = 3'd1,
    STATE_RX_ASYNC = 3'd2,
    STATE_RX_PRE_SYNC = 3'd3,
    STATE_RX_PRE_ASYNC = 3'd4;

reg [2:0] state_reg;
reg [2:0] state_next;

always_ff @(posedge rmii_ref_clk, posedge rst_mii) begin 
    if (rst_mii) begin
        state_reg     <= STATE_IDLE;

        mii_rxd_next_reg   <= 4'b0;
        mii_rxd_int_reg    <= 4'b0;
        mii_rx_dv_next_reg <= 1'b0;
        rmii_rxd_reg      <= 2'b0;
        rmii_crs_dv_reg   <= 1'b0;
    end else begin
        state_reg          <= state_next;
        mii_rxd_next_reg   <= mii_rxd_next;
        mii_rxd_int_reg    <= mii_rxd_int;
        mii_rx_dv_next_reg <= mii_rx_dv_next;
        rmii_rxd_reg       <= rmii_rxd;
        rmii_crs_dv_reg    <= rmii_crs_dv;
    end
end

always_ff @(posedge rmii_ref_clk, posedge rst_mii) begin
    if (rst_mii) begin
        mii_rxd_reg   <= 4'b0;
        mii_rx_dv_reg <= 1'b0;
        mii_rx_er_reg <= 1'b0;
    end else begin
        if (mii_valid) begin
            mii_rxd_reg   <= mii_rxd_next;
            mii_rx_dv_reg <= mii_rx_dv_next;
            mii_rx_er_reg <= mii_rx_er_next;
        end
    end 
end

always_comb begin
    //default statements
    state_next     <= state_reg;
    mii_rx_er_next <= mii_rx_er_reg;
    mii_rx_dv_next <= mii_rx_dv_reg;
    mii_rxd_next   <= mii_rxd_reg;
    mii_rxd_int    <= mii_rxd_reg;


    //FSM Logic
    case (state_reg)
        STATE_IDLE: begin
            if (rmii_crs_dv) begin
                state_next <= mii_valid == 1'b0 ? STATE_RX_PRE_SYNC : STATE_RX_PRE_ASYNC;
            end
        end

        STATE_RX_PRE_SYNC: begin 
            if (!mii_valid) begin  /* rising edge */ 
                mii_rxd_int      <= {rmii_rxd_reg, mii_rxd_int_reg[1:0]};
                mii_rxd_next     <= mii_rxd_next_reg;
                mii_rx_dv_next   <= rmii_crs_dv_reg;  
            end else begin         /* falling edge */ 
                mii_rxd_next     <= mii_rxd_int_reg;
                mii_rxd_int      <= {mii_rxd_int_reg[3:2], rmii_rxd_reg};
                mii_rx_er_next   <= rmii_rx_er; 
                mii_rx_dv_next   <= mii_rx_dv_next_reg;
            end

            //resynchronize at start frame delimiter
            if (rmii_crs_dv && (rmii_rxd == 2'b11)) begin
                state_next <= mii_valid == 1'b0 ? STATE_RX_ASYNC : STATE_RX_SYNC;
            end

        end

        STATE_RX_PRE_ASYNC: begin
            if (!mii_valid) begin  /* rising edge  */  
                mii_rxd_int      <= {mii_rxd_int_reg[3:2], rmii_rxd_reg};
                mii_rxd_next     <= mii_rxd_next_reg;
            end else begin         /* falling edge */ 
                mii_rxd_int       <= {rmii_rxd_reg, mii_rxd_int_reg[1:0]};
                mii_rxd_next      <= {rmii_rxd_reg, mii_rxd_int_reg[1:0]};
                mii_rx_dv_next    <= rmii_crs_dv_reg;  
                mii_rx_er_next    <= rmii_rx_er;  
            end

            //resynchronize at start frame delimiter
            if (rmii_crs_dv && (rmii_rxd == 2'b11)) begin
                state_next <= mii_valid == 1'b0 ? STATE_RX_ASYNC : STATE_RX_SYNC;
            end
        end

        STATE_RX_SYNC: begin
            if (!mii_valid) begin  /* rising edge*/ 
                mii_rxd_int      <= {rmii_rxd_reg, mii_rxd_int_reg[1:0]};
                mii_rxd_next     <= mii_rxd_next_reg;
                mii_rx_dv_next   <= rmii_crs_dv_reg;  
            end else begin         /* falling edge */ 
                mii_rxd_next     <= mii_rxd_int_reg;
                mii_rxd_int      <= {mii_rxd_int_reg[3:2], rmii_rxd_reg};
                mii_rx_er_next   <= rmii_rx_er; 
                mii_rx_dv_next   <= mii_rx_dv_next_reg;
            end


            if (!rmii_crs_dv && !mii_rx_dv) begin
                state_next <= STATE_IDLE;
            end
        end

        STATE_RX_ASYNC: begin
            if (!mii_valid) begin  /* rising edge  */  
                mii_rxd_int      <= {mii_rxd_int_reg[3:2], rmii_rxd_reg};
                mii_rxd_next     <= mii_rxd_next_reg;
            end else begin         /* falling edge */ 
                mii_rxd_int       <= {rmii_rxd_reg, mii_rxd_int_reg[1:0]};
                mii_rxd_next      <= {rmii_rxd_reg, mii_rxd_int_reg[1:0]};
                mii_rx_dv_next    <= rmii_crs_dv_reg;  
                mii_rx_er_next    <= rmii_rx_er;  
            end


            if (!rmii_crs_dv&& !mii_rx_dv) begin
                state_next <= STATE_IDLE;
            end
        end

        default: begin
            state_next <= STATE_IDLE;
        end
    endcase


end

//TRANSMIT

//rmii registers
reg [1:0] rmii_txd_reg;
reg       rmii_tx_en_reg;
reg [3:0] rmii_txd_next;

//mii registers
reg       mii_tx_en_reg;

//assign to output 
assign rmii_tx_en = rmii_tx_en_reg; 
assign rmii_txd   = rmii_txd_reg;


//sync on rmii clk 
//mii clk sync with rmii clk

always_ff @(posedge rmii_ref_clk, posedge rst_mii) begin
    if (rst_mii) begin
        rmii_tx_en_reg <= 1'b0;
        rmii_txd_reg   <= 2'b0;
        mii_tx_en_reg  <= 1'b0;
        rmii_txd_next  <= 2'b0;
    end else begin
        if (mii_valid) begin  /* rising edge */
            rmii_txd_reg  <= rmii_txd_next[3:2]; // second 2 bits
            rmii_txd_next <= mii_txd; 
            mii_tx_en_reg <= mii_tx_en;
        end else begin         /* falling edge */
            rmii_txd_reg  <= rmii_txd_next[1:0]; // first 2 bits 

        end 

        rmii_tx_en_reg <= mii_tx_en_reg;
    end
end

endmodule

`resetall
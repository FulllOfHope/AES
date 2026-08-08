`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name : aes_axi4lite_wrapper
// Description : AXI4-Lite slave wrapper for pipelined AES-128 core.
//
// Register Map:
//   0x00  CTRL       [W]   bit[0]=start
//   0x04  STATUS     [R]   bit[0]=busy, bit[1]=idle, bit[2]=done
//   0x08  KEY_0      [W]   key[31:0]
//   0x0C  KEY_1      [W]   key[63:32]
//   0x10  KEY_2      [W]   key[95:64]
//   0x14  KEY_3      [W]   key[127:96]  <- write this last to validate key
//   0x18  DATA_IN_0  [W]   plaintext[31:0]
//   0x1C  DATA_IN_1  [W]   plaintext[63:32]
//   0x20  DATA_IN_2  [W]   plaintext[95:64]
//   0x24  DATA_IN_3  [W]   plaintext[127:96]
//   0x28  DATA_OUT_0 [R]   ciphertext[31:0]
//   0x2C  DATA_OUT_1 [R]   ciphertext[63:32]
//   0x30  DATA_OUT_2 [R]   ciphertext[95:64]
//   0x34  DATA_OUT_3 [R]   ciphertext[127:96]
//////////////////////////////////////////////////////////////////////////////////

module aes_axi4lite_wrapper #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 6
)(
    input  wire                   s_axi_aclk,
    input  wire                   s_axi_aresetn,

    input  wire [ADDR_WIDTH-1:0]  s_axi_awaddr,
    input  wire                   s_axi_awvalid,
    output reg                    s_axi_awready,

    input  wire [DATA_WIDTH-1:0]  s_axi_wdata,
    input  wire [3:0]             s_axi_wstrb,
    input  wire                   s_axi_wvalid,
    output reg                    s_axi_wready,

    output reg  [1:0]             s_axi_bresp,
    output reg                    s_axi_bvalid,
    input  wire                   s_axi_bready,

    input  wire [ADDR_WIDTH-1:0]  s_axi_araddr,
    input  wire                   s_axi_arvalid,
    output reg                    s_axi_arready,

    output reg  [DATA_WIDTH-1:0]  s_axi_rdata,
    output reg  [1:0]             s_axi_rresp,
    output reg                    s_axi_rvalid,
    input  wire                   s_axi_rready
);

    // Memory map registers
    reg [31:0] reg_key  [0:3];   // 0x08-0x14
    reg [31:0] reg_din  [0:3];   // 0x18-0x24
    reg [31:0] reg_dout [0:3];   // 0x28-0x34
    reg [31:0] reg_status;       // 0x04 

    // Latches for AXI addresses so we don't lose them during handshakes
    reg [ADDR_WIDTH-1:0] axi_awaddr_lat;
    reg [ADDR_WIDTH-1:0] axi_araddr_lat;

    // Pack the 4 key registers into one 128-bit wire for the AES core
    wire [127:0] key_reg = {reg_key[3], reg_key[2], reg_key[1], reg_key[0]};
    reg          key_valid;   // Prevents starting without a full key

    reg start_pulse;

    // Tracks data moving through the 11-stage pipeline
    reg [10:0] inflight_pipe;
    wire       aes_busy = |inflight_pipe;

    wire [127:0] aes_din_w  = {reg_din[3], reg_din[2], reg_din[1], reg_din[0]};
    wire [127:0] aes_dout_w;
    wire         aes_done_w;

    // Helper to handle partial byte writes (WSTRB) from the CPU
    function automatic [31:0] apply_wstrb;
        input [31:0] old_val;
        input [31:0] new_val;
        input [3:0]  strb;
        integer i;
        begin
            for (i = 0; i < 4; i = i + 1)
                apply_wstrb[i*8 +: 8] = strb[i] ? new_val[i*8 +: 8] 
                                                : old_val[i*8 +: 8];
        end
    endfunction

    // ================================================================
    // AXI Write Handshakes (Address and Data)
    // ================================================================
    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            s_axi_awready  <= 1'b0;
            axi_awaddr_lat <= {ADDR_WIDTH{1'b0}};
        end else begin
            if (!s_axi_awready && s_axi_awvalid && s_axi_wvalid) begin
                s_axi_awready  <= 1'b1;
                axi_awaddr_lat <= s_axi_awaddr;
            end else
                s_axi_awready  <= 1'b0;
        end
    end

    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn)
            s_axi_wready <= 1'b0;
        else begin
            if (!s_axi_wready && s_axi_wvalid && s_axi_awvalid)
                s_axi_wready <= 1'b1;
            else
                s_axi_wready <= 1'b0;
        end
    end

    wire wr_en = s_axi_awready && s_axi_awvalid && s_axi_wready && s_axi_wvalid;

    // ================================================================
    // Register Write Logic (CPU -> FPGA)
    // ================================================================
    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin 
            reg_key[0] <= 32'h0; reg_key[1] <= 32'h0;
            reg_key[2] <= 32'h0; reg_key[3] <= 32'h0;
            reg_din[0] <= 32'h0; reg_din[1] <= 32'h0;
            reg_din[2] <= 32'h0; reg_din[3] <= 32'h0;
            key_valid  <= 1'b0;
            start_pulse <= 1'b0;
        end else begin
            start_pulse <= 1'b0; // default to 0 for a clean 1-cycle pulse

            if (wr_en) begin
                case (axi_awaddr_lat[5:2])        
                    4'h0: begin  // CTRL (0x00)
                        if (s_axi_wdata[0] && key_valid && !aes_busy)
                            start_pulse <= 1'b1;
                    end
                    4'h2: reg_key[0] <= apply_wstrb(reg_key[0], s_axi_wdata, s_axi_wstrb);
                    4'h3: reg_key[1] <= apply_wstrb(reg_key[1], s_axi_wdata, s_axi_wstrb);
                    4'h4: reg_key[2] <= apply_wstrb(reg_key[2], s_axi_wdata, s_axi_wstrb);
                    4'h5: begin  // KEY_3 (0x14) - writing this unlocks the core
                        reg_key[3] <= apply_wstrb(reg_key[3], s_axi_wdata, s_axi_wstrb);
                        key_valid  <= 1'b1;
                    end
                    4'h6: reg_din[0] <= apply_wstrb(reg_din[0], s_axi_wdata, s_axi_wstrb);
                    4'h7: reg_din[1] <= apply_wstrb(reg_din[1], s_axi_wdata, s_axi_wstrb);
                    4'h8: reg_din[2] <= apply_wstrb(reg_din[2], s_axi_wdata, s_axi_wstrb);
                    4'h9: reg_din[3] <= apply_wstrb(reg_din[3], s_axi_wdata, s_axi_wstrb);
                    default: ;
                endcase
            end
        end
    end

    // ================================================================
    // AXI Write Response (B Channel)
    // ================================================================
    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            s_axi_bvalid <= 1'b0;
            s_axi_bresp  <= 2'b00;
        end else begin
            if (wr_en && !s_axi_bvalid) begin
                s_axi_bvalid <= 1'b1;
                s_axi_bresp  <= 2'b00; // OKAY response
            end else if (s_axi_bvalid && s_axi_bready)
                s_axi_bvalid <= 1'b0;
        end
    end

    // ================================================================
    // AXI Read Handshakes (Address and Data)
    // ================================================================
    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            s_axi_arready  <= 1'b0;
            axi_araddr_lat <= {ADDR_WIDTH{1'b0}};
        end else begin
            if (!s_axi_arready && s_axi_arvalid) begin
                s_axi_arready  <= 1'b1;
                axi_araddr_lat <= s_axi_araddr;
            end else
                s_axi_arready  <= 1'b0;
        end
    end

    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            s_axi_rvalid <= 1'b0;
            s_axi_rresp  <= 2'b00;
            s_axi_rdata  <= 32'h0;
        end else begin
            if (s_axi_arready && s_axi_arvalid && !s_axi_rvalid) begin
                s_axi_rvalid <= 1'b1;
                s_axi_rresp  <= 2'b00;
                
                // Read multiplexer (FPGA -> CPU)
                case (axi_araddr_lat[5:2])
                    4'h1:  s_axi_rdata <= reg_status;
                    4'h2:  s_axi_rdata <= reg_key[0];
                    4'h3:  s_axi_rdata <= reg_key[1];
                    4'h4:  s_axi_rdata <= reg_key[2];
                    4'h5:  s_axi_rdata <= reg_key[3];
                    4'h6:  s_axi_rdata <= reg_din[0];
                    4'h7:  s_axi_rdata <= reg_din[1];
                    4'h8:  s_axi_rdata <= reg_din[2];
                    4'h9:  s_axi_rdata <= reg_din[3];
                    4'hA:  s_axi_rdata <= reg_dout[0];
                    4'hB:  s_axi_rdata <= reg_dout[1];
                    4'hC:  s_axi_rdata <= reg_dout[2];
                    4'hD:  s_axi_rdata <= reg_dout[3];
                    default: begin
                        s_axi_rdata <= 32'hDEADBEEF; // Catch invalid reads
                        s_axi_rresp <= 2'b10;        // SLVERR response
                    end
                endcase
            end else if (s_axi_rvalid && s_axi_rready)
                s_axi_rvalid <= 1'b0;
        end
    end

    // ================================================================
    // Pipeline Status Tracking
    // ================================================================
    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn)
            inflight_pipe <= 11'h0;
        else
            inflight_pipe <= {inflight_pipe[9:0], start_pulse};
    end

    // Catch the 128-bit output from the core and map it to readable registers
    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            reg_dout[0] <= 32'h0; reg_dout[1] <= 32'h0;
            reg_dout[2] <= 32'h0; reg_dout[3] <= 32'h0;
        end else if (aes_done_w) begin
            reg_dout[0] <= aes_dout_w[31:0];
            reg_dout[1] <= aes_dout_w[63:32];
            reg_dout[2] <= aes_dout_w[95:64];
            reg_dout[3] <= aes_dout_w[127:96];
        end
    end

    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn)
            reg_status <= 32'h2;
        else begin
            reg_status[0] <= aes_busy;
            reg_status[1] <= ~aes_busy;
            reg_status[2] <= aes_done_w; // 1-cycle pulse
            reg_status[3] <= 1'b0;
        end
    end

    // ================================================================
    // AES Core Instantiation
    // ================================================================
    top u_aes_core (
        .clk         (s_axi_aclk),
        .rst         (~s_axi_aresetn),
        .valid_in    (start_pulse),
        .input_data  (aes_din_w),
        .key         (key_reg),
        .output_data (aes_dout_w),
        .valid_out   (aes_done_w)
    );

endmodule
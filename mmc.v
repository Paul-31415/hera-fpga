


//owns spi port,
//handles spi interaction w/ pyboard
//controls memory mapping to peripherals

module mmc(
              input spi_clk,
              output spi_miso,
              input spi_mosi,
              input spi_cs,

  input clk,
  output out_clk,reset,
  input code,
  input [15:0] addr,
  output [15:0] data,
  input [15:0] w_data,
  input write,

  input [255:0] debug_r,
  input [22:0]  debug_f,

  );
  //reg [15:0] mem [0:255]  //1 block ram

  //assign data = rdata;//memory[addr[12:0]];
  //reg [15:0] db;
  //assign data = db;

  reg res;
  assign reset = res;
  /* direct instantiation of block rams
  wire [15:0] wdata = spi_cs?spi_cmd[31:16]:w_data;
  wire [15:0] waddr = spi_cs?spi_cmd[15:0]:addr;
  wire [15:0] raddr = spi_cs?spi_cmd[15:0]:addr;
  wire [31:0] wes = spi_cs?write_spi:write;
  wire [31:0] wea = 1<<waddr[12:8];
  reg write_spi;
  wire [511:0] ralldata;
  wire [15:0] rdata = ralldata[(raddr[12:8]<<4)|4'hf:raddr[12:8]<<4];
  SB_RAM40_4K mems[31:0]

     (
    .WDATA(wdata),
    .WADDR({waddr[7:0],3'b0}),
    .WE(wea),
    .WCLKE(wes),
    .WCLK(both_clocks),

    .RDATA(ralldata),
    .RADDR({raddr[7:0],3'b0}),
    .RE(1'b1),
    .RCLKE(1'b1),
    .RCLK(both_clocks)
    );
  //*/

  //reg [15:0] memory [0:(1<<13)-1]; //all block rams


  wire [63:0] rdata,wdata,raddr,waddr;
  //wire [3:0] rres,wres;
  //reg [3:0] rreq,wreq;
  wire [3:0] wen;
  wire [3:0] co;
  mem_mux mem(
    .clk(clk),
    .rst(1'b0),
    .clocks(co),
    .read_datas(rdata),
    .read_addrs(raddr),
    //.read_responses(rres),
    //.read_requests(rreq),

    .write_datas(wdata),
    .write_addrs(waddr),
    //.write_responses(wres),
    .write_requests(wen)//wreq),
    );


  assign raddr[63:48] = addr;
  assign data = (code&(imm_op^imm_op_r))?op:rdata[63:48];
  assign wdata[63:48] = w_data;
  assign waddr[63:48] = addr;
  assign wen[3] = write;
  wire [3:0] nready = 0;//(rreq^rres)|(wreq^wres);

  reg [15:0] s_raddr;
  assign raddr[15:0] = s_raddr;
  wire [15:0] s_rdata = rdata[15:0];

  reg [15:0] s_waddr;
  assign waddr[15:0] = s_waddr;
  reg [15:0] s_wdata;
  assign wdata[15:0] = s_wdata;

  assign raddr[47:16] = 0;
  assign wdata[47:16] = 0;
  assign waddr[47:16] = 0;
  assign wen[2:1] = 0;

  reg run;
  reg hclk;
  reg [15:0] op;
  reg imm_op;
  reg imm_op_r;
  reg step_r;
  //mem mux has out clock
  assign out_clk = hclk;

  //step:
  //                 read    write
  // hcpu opc  [ 1][  2   ][   3   ]
  // clk :   __--__--__--__--__--__-
  // code:   -------____----____----
  // write:  _______________----____
  //                       |    |
  //zoomed in
  // clk12:  __--__--__--__--__--__--__--__--__--__--
  // which:  0000111122223333000011112222333300001111
  // r/w                   !               !
  // clk:    ----____________----____________----____
  // code:   _----------------________________-------
  // write:  _________________----------------_______
  //

  always @(posedge clk) begin
    hclk <= (run|(step^step_r))&co[3];
  end
  always @(negedge hclk) begin
    if (code & (step^step_r)) begin
      step_r <= step;
    end
    if (code & (imm_op^imm_op_r)) begin
      imm_op_r <= imm_op;
    end
  end
  /* depracated (used for old mem manager)
  //mem output on rising edge after falling edge after req  (it's clock)
  // so I want to clock hera on falling edge after res
  assign out_clk = hclk;
  // hera asserts next address "immediately", so
  //  I toggle req on next rising edge
  //in summary:
  //
  //    req    ______--------________
  //    res    --________--------________
  // memclk    __--__--__--__--__--__
  //   hclk    ____----____----____---
  //

  always @(negedge clk) begin
    if (hclk | ((!nready[3]) & (run|(step^step_r)))) begin
     hclk <= !hclk;
     if (code&(step^step_r)) begin
      step_r <= step;
     end
     if (code&(imm_op^imm_op_r)) begin
      imm_op_r <= imm_op;
     end
    end
  end
  always @(posedge clk) begin
    if (hclk) begin
     rreq[3] <= ~rres[3];
     if (write)
       wreq[3] <= ~wreq[3];
    end
  end
  */

  reg step;
  //msb first, rising edge
  reg [63:0] spi_cmd;
  // PING  - ping
  //  PONG
  // R**   - read
  //    dd
  // Wdd** - write
  //
  // //I*    - interrupt (use O(swi(i)) )
  //
  // H     - halt
  // S     - step
  // h     - run
  // r     - reset
  // O**   - imm opcode
  //
  // D     - debugger read
  //  r*   -               register n
  //  f    -               flags&opcode (23 bits zero padded to 24)
  //  m    -               mmc flags/values
  wire [23:0] debug_m = {1'b1,step,step_r,run,hclk,res,imm_op,imm_op_r,op};
  assign spi_miso = spi_cmd[63];
  reg spi_wen;
  assign wen[0] = spi_wen;
  //wire both_clocks = spi_cs?spi_clk:clk;
  wire [63:0] sc = {spi_cmd[62:0],spi_mosi};
  always @(posedge spi_clk) begin
   if (spi_cs) begin
    casez (sc)
    {40'h0,"D","r",8'h??}: begin
           spi_cmd <= {debug_r[15+{sc[3:0],4'h0}:{sc[3:0],4'h0}],48'b0};
     end
     {48'h0,"D","f"}: begin
            spi_cmd <= {1'b1,debug_f,40'b0};
      end
      {48'h0,"D","m"}: begin
             spi_cmd <= {debug_m,40'b0};
       end

    {56'h0,"P"}: begin
           spi_cmd <= {"P","O","N","G",32'b0};
     end
      {40'h0,"R",16'h????}: begin
             //spi_cmd <= 0;
             //spi_resp <= rdata;
             //spi_resp <= memory[sc[13:0]];
             s_raddr <= sc[15:0];
             //rreq[0] <= !rreq[0];
             spi_cmd <= sc;
       end
       {32'h0,"R",16'h????,8'h??}: begin
             //spi_cmd <= {nready[0],s_rdata,47'h0};
             spi_cmd <= {s_rdata,48'h0};
       end
       {24'h0,"W",32'h????_????}: begin
              spi_cmd <= sc;
              //spi_resp <= rdata;
              //spi_resp <= memory[sc[13:0]];
              //memory[sc[13:0]] <= sc[31:16];
              //spi_resp <= read_data;
              s_waddr <= sc[15:0];
              s_wdata <= sc[31:16];
              //wreq[0] <= !wreq[0];
              spi_wen <= 1;
        end
        {17'h0,"W",39'h??????_????}: begin
               spi_cmd <= {nready[0],63'b0};
               spi_wen <= 0;
        end


     {56'h0,"H"}: begin
           spi_cmd <= {2'b01,run,5'h08,56'h0};
           run <= 0;
        end
     {56'h0,"h"}: begin
           spi_cmd <= {2'b01,run,5'h08,56'h0};
           run <= 1;
       end
       {56'h0,"S"}: begin
              spi_cmd <= {"S",56'h0};
              step <= ~step;
          end
          {56'h0,"r"}: begin
                 spi_cmd <= {{8{res}},56'h0};
                 res <= !res;
             end
          {40'h0,"O",16'h????}: begin
                 spi_cmd <= {addr,code,47'h0};
                 op <= sc[15:0];
                 imm_op <= ~imm_op;
           end

      default: begin
        spi_cmd <= sc;
      end
    endcase
  end else begin
   spi_resp <= 0;
   spi_cmd <= 0;
  end
end




endmodule

module mem_mux(
  input clk,rst,
  output [3:0] clocks,  //rising edge after serviced
  output [63:0] read_datas,
  input [63:0] read_addrs,
  input [3:0] write_requests,
  input [63:0] write_datas,
  input [63:0] write_addrs,
  );
  reg [15:0] memory [0:8191];

  reg [1:0] which;
  reg [63:0] read_out;
  assign read_datas = read_out;
  reg [15:0] read_tmp;

  reg [3:0] co;
  assign clocks = co;


  wire [15:0] read_addr;
  always @(read_addrs,which) begin
    case (which)
    0:read_addr = read_addrs[15:0];
    1:read_addr = read_addrs[31:16];
    2:read_addr = read_addrs[47:32];
    3:read_addr = read_addrs[63:48];
    endcase
  end
  wire [15:0] write_addr;
  always @(write_addrs,which) begin
    case (which)
    0:write_addr = write_addrs[15:0];
    1:write_addr = write_addrs[31:16];
    2:write_addr = write_addrs[47:32];
    3:write_addr = write_addrs[63:48];
    endcase
  end
  wire [15:0] write_data;
  always @(write_datas,which) begin
    case (which)
    0:write_data = write_datas[15:0];
    1:write_data = write_datas[31:16];
    2:write_data = write_datas[47:32];
    3:write_data = write_datas[63:48];
    endcase
  end
  always @ (negedge clk) begin
    if (rst) begin
      read_datas <= 0;
      which <= 0;
    end else begin
      case (which)
      0:read_datas[15:0] <= read_tmp;
      1:read_datas[31:16] <= read_tmp;
      2:read_datas[47:32] <= read_tmp;
      3:read_datas[63:48] <= read_tmp;
      endcase
      co <= 4'b1<<which;
      which <= which + 1;
    end
  end
  always @ ( posedge clk ) begin
    if (rst) begin
      read_tmp <= 0;
    end else begin
      read_tmp <= memory[read_addr[13:0]];
      if (write_requests[which]) begin
        memory[write_addr[13:0]] <= write_data;
      end
    end
  end




endmodule

/*
//output on rising edge after falling edge after req
module mem_scheduler(
  input clk,

  input [3:0] read_requests,
  output [63:0] read_datas,
  input [63:0] read_addrs,
  output [3:0] read_responses,

  input [3:0] write_requests,
  input [63:0] write_datas,
  input [63:0] write_addrs,
  output [3:0] write_responses,
  );
  reg [15:0] memory [0:8191];//[0:255][0:31];//brams

  reg [3:0] rr;
  assign read_responses = rr;
  wire [15:0] read_addr;
  //wire [15:0] read_data = memory[read_addr[13:0]];
  always @( r , read_addrs) begin
   casez (r)
   4'b???1: read_addr = read_addrs[15:0];
   4'b??10: read_addr = read_addrs[31:16];
   4'b?100: read_addr = read_addrs[47:32];
   4'b1000: read_addr = read_addrs[63:48];
   default: read_addr = read_addrs[63:48];
   endcase
  end

  reg [3:0] h;
  reg [3:0] r;
  reg [3:0] w;
  always @(negedge clk) h <= (read_requests^rr)|(write_requests^wr);
  wire write;
  always @( h ) begin
   casez (r)
   4'b???1: write = w[0];
   4'b??10: write = w[1];
   4'b?100: write = w[2];
   4'b1000: write = w[3];
   default: write = 0;
   endcase
  end
  wire [1:0] where;
  always @(r) begin
  casez (r)
  4'b???1: where = 0;
  4'b??10: where = 1;
  4'b?100: where = 2;
  4'b1000: where = 3;
  default: where = 0;
  endcase
  end
  wire [3:0] nr = read_requests^rr;
  always @(negedge clk) begin
   r <= nr;
   w <= write_requests^wr;
   if (|nr)
    read_tmp <= memory[nr[0]?read_addrs[15:0]:(nr[1]?read_addrs[31:16]:(nr[2]?read_addrs[47:32]:read_addrs[63:48]))];
  end
  reg [63:0] read_out;
  assign read_datas = read_out;
  reg [15:0] read_tmp;
  always @(posedge clk) begin
     casez (r)
       4'b???1: begin rr[0] <= read_requests[0];
         read_out[15:0] <= read_tmp;
       end
       4'b??10: begin rr[1] <= read_requests[1];
         read_out[31:16] <= read_tmp;
       end
       4'b?100: begin rr[2] <= read_requests[2];
         read_out[47:32] <= read_tmp;
       end
       4'b1000: begin rr[3] <= read_requests[3];
         read_out[63:48] <= read_tmp;
       end
     endcase
   //write
   if (|w) begin
     memory[write_addr[13:0]] <= write_data;
     casez (w)
       4'b???1: wr[0] <= write_requests[0];
       4'b??10: wr[1] <= write_requests[1];
       4'b?100: wr[2] <= write_requests[2];
       4'b1000: wr[3] <= write_requests[3];
     endcase
   end
   //if (|r)
    //read_datas[63:48] <= read_tmp;
    //read_datas[15+(where<<4):(where<<4)] <= memory[read_addr[13:0]];
   /*if (write)
    memory[write_addr[13:0]] <= write_data;
   casez (h)
   4'b???1: begin
       wr[0] <= write_requests[0];
        rr[0] <= read_requests[0];
    end
   4'b??10: begin
      wr[1] <= write_requests[1];
       rr[1] <= read_requests[1];
     end
     4'b?100: begin
       wr[2] <= write_requests[2];
       rr[2] <= read_requests[2];
       end
    4'b1000: begin
       wr[3] <= write_requests[3];
       rr[3] <= read_requests[3];
    end
   endcase
   * /
  end

  reg [3:0] wr;
  assign write_responses = wr;
  wire [15:0] write_addr;
  wire [15:0] write_data;
  always @(w , write_addrs , write_datas) begin
   casez (w)
   4'b???1: {write_addr,write_data} = {write_addrs[15:0],write_datas[15:0]};
   4'b??10: {write_addr,write_data} = {write_addrs[31:16],write_datas[31:16]};
   4'b?100: {write_addr,write_data} = {write_addrs[47:32],write_datas[47:32]};
   4'b1000: {write_addr,write_data} = {write_addrs[63:48],write_datas[63:48]};
   default: {write_addr,write_data} = {write_addrs[63:48],write_datas[63:48]};
   endcase
  end





endmodule
*/

//

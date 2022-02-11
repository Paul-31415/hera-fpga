// look in pins.pcf for all the pin names on the TinyFPGA BX board
//`include "mmc.v"
//`include "hera.v"
module top (
    input CLK,
    input PIN_14,//kbd_data ,
    output PIN_15,PIN_16,//kbd_clk , kbd_latch ,
    input PIN_18,PIN_19,PIN_20,PIN_21,//kbd_analog_1 , kbd_analog_2 , kbd_analog_3 , kbd_analog_4 ,
    output PIN_17,//kbd_analog_clear ,

    input SPI_SCK,SPI_IO1,SPI_SS,
    output SPI_IO0,SPI_IO3,
    output PIN_23,PIN_24,

    input PIN_28, PIN_29,
    output PIN_30,

    output USBPU  // USB pull-up resistor
);
assign SPI_IO3 = 0; //hold flash
wire kbd_latch = PIN_16;
wire kbd_clk = PIN_15;
wire kbd_data = PIN_14;
wire kbd_analog_clear = PIN_17;
wire kbd_analog_1 = PIN_18;
wire kbd_analog_2 = PIN_19;
wire kbd_analog_3 = PIN_20;
wire kbd_analog_4 = PIN_21;
wire  audio_out_r = PIN_23;
wire  audio_out_l = PIN_24;
wire audio_in_r = PIN_28;
wire audio_in_l = PIN_29;
wire audio_in_clk = PIN_30;
assign kbd_analog_clear = 1;



wire hclk,rst,w,c;
wire [15:0] rdata,wdata,addr;
wire [22:0] debugf;
wire [255:0] debugr;
//*
  hera cpu(
    .clock(hclk),
    .reset(rst),
    .data_in(rdata),
    .data_out(wdata),
    .addr(addr),
    .code(c),
    .write(w),
    .debug_f(debugf),
    .debug_r(debugr),
    );
    //*/

  mmc memory_manager (
    .spi_clk(SPI_SCK),
    .spi_miso(SPI_IO0),
    .spi_mosi(SPI_IO1),
    .spi_cs(SPI_SS),
    .clk(CLK),
    .out_clk(hclk),
    .reset(rst),
    .data(rdata),
    .addr(addr),
    .w_data(wdata),
    .write(w),
    .code(c),
    .debug_f(debugf),
    .debug_r(debugr),
    );


endmodule








/*


module hera (
  input clock,reset,
  input [15:0] opcode,
  output [15:0] pc_o,
  output write,
  output read,
  input [15:0] data_read,
  output [15:0] data_write,
  output [15:0] data_addr,
  );
  reg [15:0] pc;

  assign pc_o = pc;

  reg [4:0] flags;//cb, c,v,z,s (not v,s,c,z)
  wire [3:0] cond_select = opcode[11:8];
  wire cond;
  wire [3:0] vscz_flags = {flags[2],flags[0],flags[3],flags[1]};
  wire [3:0] cconds = {(!vscz_flags[1])|vscz_flags[0],(vscz_flags[3]^vscz_flags[2])|vscz_flags[0],vscz_flags[3]^vscz_flags[2],1'b1};
  assign cond = (cond_select[3]?vscz_flags[cond_select[2:1]]:cconds[cond_select[2:1]])^cond_select[0];

  //let verliog infer that this can't be block ram
  reg [15:0] regs [0:15];
  assign regs[0] = 16'h0000; //hopefully it can optimize this reg away
  //r0 = 0
  //r14 = fp
  //r15 = sp

  wire [3:0] b = opcode[3:0];
  wire [3:0] a = opcode[7:4];
  wire [3:0] d = opcode[11:8];


  //alu wires:
  wire[16:0] inc = regs[d] + 1 + opcode[5:0];
  wire[16:0] dec = regs[d] - 1 - opcode[5:0];
  wire [15:0] and_ = regs[a]&regs[b];
  wire [15:0] or_ = regs[a]|regs[b];
  wire [16:0] add = regs[a]+regs[b]+(flags[3]&(!flags[4]));
  wire [16:0] sub = regs[a]-regs[b]-((~flags[3])&(~flags[4]));
  wire [31:0] mul = {{16{regs[a][15]}},regs[a]}*{{16{regs[b][15]}},regs[b]};
  wire [15:0] xor_ = regs[a]^regs[b];
  //

  //load and store
  reg [15:0] data_addr_r;
  assign data_addr = data_addr_r;
  reg writer;
  reg [15:0]write_d;
  assign data_write = write_d;
  assign write = writer;
  reg readr;
  assign read = readr;
  reg [3:0] prevd;
  always @ ( negedge clock ) begin
    if (readr) begin
      regs[prevd] <= data_read;
      flags[1:0] <= {~|data_read,data_read[15]};
      readr <= 0;
    end
  end

  always @ ( posedge clock ) begin
    if (reset) begin
      pc <= 0;
      flags <= 0;
      {regs[1],regs[2],regs[3],regs[4],
        regs[5],regs[6],regs[7],regs[8],
        regs[9],regs[10],regs[11],regs[12],
        regs[13],regs[14],regs[15]} <= 0;
      writer <= 0;
      readr <= 0;
      prevd <= 0;
    end else begin
      prevd <= d;
      writer <= (opcode[15:13] == 3'b011);
      casez (opcode)
        16'b0000_????_????????: //b?r(*)
          if (cond)
            pc <= pc + {{8{opcode[7]}},opcode[7:0]};
        16'b0001_????_0000_????://b?(b)
          if (cond)
            pc <= regs[b];
          else
            pc <= pc + 1;
        16'b0010_000?_????_????: begin// call/return (a,b)
            regs[14] <= regs[a];
            regs[a] <= regs[14];
            pc <= regs[b];
            regs[b] <= pc+1;
          end

        //coco stuff is after the other stuff

        16'b0011_????_0000_????:begin //lsl
            pc <= pc + 1;
            {flags[3],regs[d]} <= {regs[b],flags[3]&(!flags[4])};
            flags[0] <= regs[b][14];
            flags[1] <= !(|{regs[b][14:0],flags[3]&(!flags[4])});
          end
        16'b0011_????_0001_????:begin //lsr
            pc <= pc + 1;
            {regs[d],flags[3]} <= {flags[3]&(!flags[4]),regs[b]};
            flags[0] <= flags[3]&(!flags[4]);
            flags[1] <= !(|{flags[3]&(!flags[4]),regs[b][15:1]});
          end
        16'b0011_????_0010_????:begin //lsl8
            pc <= pc + 1;
            regs[d] <= {regs[b][7:0],8'h00};
            flags[0] <= regs[b][7];
            flags[1] <= !(|regs[b][7:0]);
          end
        16'b0011_????_0011_????:begin //lsr8
            pc <= pc + 1;
            regs[d] <= {8'h00,regs[b][15:8]};
            flags[0] <= 0;
            flags[1] <= !(|regs[b][15:8]);
          end
        16'b0011_????_0100_????:begin //asl
            pc <= pc + 1;
            {flags[3],regs[d]} <= {regs[b],flags[3]&(!flags[4])};
            flags[0] <= regs[b][14];
            flags[1] <= !(|{regs[b][14:0],flags[3]&(!flags[4])});
            flags[2] <= ^regs[b][15:14];
          end
        16'b0011_????_0101_????:begin //asr
            pc <= pc + 1;
            {regs[d],flags[3]} <= {regs[b][15],regs[b]};
            flags[0] <= regs[b][15];
            flags[1] <= !(|regs[b][15:1]);
          end
        16'b0011_????_0111_0000:begin//save flags
            pc <= pc + 1;
            regs[d] <= {11'h000,flags};
          end
        16'b0011_????_0111_1000:begin//rstr flags
            pc <= pc + 1;
            flags <= regs[d][4:0];
          end
        16'b0011_000?_0110_????:begin//fon
            pc <= pc + 1;
            flags <= flags | {opcode[8],b};
          end
        16'b0011_010?_0110_????:begin//fset5
            pc <= pc + 1;
            flags <= {opcode[8],b};
          end
        16'b0011_100?_0110_????:begin//foff
            pc <= pc + 1;
            flags <= flags & ~{opcode[8],b};
          end
        16'b0011_110?_0110_????:begin//fset4
            pc <= pc + 1;
            flags[3:0] <= b;
          end

        16'b0011_????_10??_????:begin//inc
            pc <= pc + 1;
            {flags[3],regs[d]} <= inc;
            //cvzs
            flags[2:0] <= {(~regs[d][15])&(inc[15]),
              ~|(inc[15:0]),
              inc[15]};
          end
        16'b0011_????_11??_????:begin//dec
            pc <= pc + 1;
            {flags[3],regs[d]} <= dec;
            //cvzs
            flags[2:0] <= {(regs[d][15])&(~(dec[15])),
              ~|(dec[15:0]),
              dec[15]};
          end
        16'b010?_????_????_????:begin//load
            pc <= pc + 1;
            readr <= 1;
            data_addr_r <= regs[b] + {opcode[12],a};
          end
        16'b011?_????_????_????:begin//store
            pc <= pc + 1;
            write_d <= regs[d];
            data_addr_r <= regs[b] + {opcode[12],a};
          end

        16'h8???:begin//and
            pc <= pc + 1;
            regs[d] <= and_;
            flags[1:0] <= {~|and_,and_[15]};
          end
        16'h9???:begin//or
            pc <= pc + 1;
            regs[d] <= or_;
            flags[1:0] <= {~|or_,or_[15]};
          end
        16'hA???:begin//add
            pc <= pc + 1;
            {flags[3],regs[d]} <= add;
            flags[2:0] <= {(regs[a][15]==regs[b][15])?regs[a][15]^add[15]:1'b0,~|add[15:0],add[15]};
          end
        16'hB???:begin//sub
            pc <= pc + 1;
            {flags[3],regs[d]} <= sub;
            flags[2:0] <= {(regs[a][15]!=regs[b][15])?regs[a][15]^sub[15]:1'b0,~|sub[15:0],sub[15]};
          end
        16'hC???:begin//mul
            pc <= pc + 1;
            //cb, c,v,z,s
            case (flags)
              5'b0_0000,
              5'b1_????: begin
                regs[d] <= mul[15:0];
                flags[2:0] <= {(~|mul[31:15])|(&mul[31:15]),~|mul,mul[31]};
              end
              5'b0_0001: begin
                regs[d] <= mul[31:16];
                flags[2:0] <= {(~|mul[31:15])|(&mul[31:15]),~|mul,mul[31]};
              end
              //not in spec:
              // probably gonna put fma here
              // and mul get both results?
              // maybe fixed point 8.8 mult? (z would reveal underflows (res=0 but z=0), v - signed overflows, c - carry bits)
              // maybe div???
              // halfFloat? no.
              // probably mask? ()
              //end not spec
              default: ;
            endcase

          end
        16'hD???:begin//xor
            pc <= pc + 1;
            regs[d] <= xor_;
            flags[1:0] <= {~|xor_[15:0],xor_[15]};
          end

        16'hE???:begin//setlo
            pc <= pc + 1;
            regs[d] <= {{8{opcode[7]}},opcode[7:0]};
          end
        16'hF???:begin//sethi
            pc <= pc + 1;
            regs[d][15:8] <= opcode[7:0];
          end




        //coco stuff
        16'b0010_0010_0000_????:begin //swi(i)

            pc <= pc + 1;
          end
        16'b0010_0011_0000_0000:begin //rti(i)
            pc <= pc + 1;
          end
        //





        //free opcodes:   #
        //1010 - 10ff :  240
        //2210 - 22ff :  240
        //2301 - 2fff : 3327
        //3071 - 3077 :    7
        //3079 - 307f :    7
        //3171 - 3177 :    7
        //3179 - 317f :    7
        //


        default: //effectively halt
        ;

      endcase

    end
  end



endmodule // hera






/ *
module top (
    input CLK,    // 16MHz clock
    output LED,   // User/boot LED next to power LED

);

  wire h_clock;
  wire h_reset;

  reg [15:0] h_opcode;
  wire [15:0] h_pc;

  wire h_write;
  wire [15:0] h_write_data;

  wire h_read;
  wire [15:0] h_data;
  wire [15:0] h_addr;

  hera proc (
    .clock(h_clock),
    .reset(h_reset),
    .opcode(h_opcode),
    .pc_o(h_pc),

    .write(h_write),
    .read(h_read),
    .data_read(h_data),
    .data_write(h_write_data),
    .data_addr(h_addr)
    );

  reg [15:0] prog_mem [0:4095];
  reg [15:0] data_mem [0:4095];
  assign h_data = data_mem[h_addr];

  always @ ( negedge h_clock ) begin
    h_opcode <= prog_mem[h_pc];
    if (h_write)
      data_mem[h_addr] <= h_write_data;
  end



endmodule
*/

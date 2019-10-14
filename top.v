// look in pins.pcf for all the pin names on the TinyFPGA BX board


module top (
    input CLK,    // 16MHz clock
    output LED,   // User/boot LED next to power LED

    //ABCDE
    output PIN_1,
    output PIN_2,
    output PIN_3,
    output PIN_4,
    output PIN_5,

    //rgb1
    output PIN_6,
    output PIN_7,
    output PIN_8,

    //rgb2
    output PIN_9,
    output PIN_10,
    output PIN_11,

    //latch
    output PIN_12,

    //clock
    output PIN_13,

    //output enable
    output PIN_14,

    //spi bus
    input PIN_24,//SCLK
    input PIN_23,//mosi
    output PIN_22,//miso
    input PIN_21,//select
    input PIN_20,//cmd/DATA

    input PIN_19,//clock select
    input PIN_18,//clock

    input PIN_17,//red scan pin
    output PIN_16, //notify scan
    output USBPU  // USB pull-up resistor
);
    // drive USB pull-up resistor to '0' to disable USB
    assign USBPU = 0;


    reg [6+5-1:0] position = 0;
    reg [7:0] bitCounter = 1;
    wire latch;



    //screen ram
    reg [8*3-1:0] vram [0:32*64*2-1];

    reg [6*2-1:0] brightness = 12'b001000_001000;
    //control registers
    reg [14:0] vset = 15'b0_1_1__111_111_111__111;
    wire [3:0] redBits = vset[12]?vset[11:9] + 1:0;
    wire [3:0] greenBits = vset[13]?vset[8:6] + 1:0;
    wire [3:0] blueBits = vset[14]?vset[5:3] + 1:0;

    wire [2:0] depth = vset[2:0];

    wire [7:0] blueDat =  (dat & ((1<<blueBits)-1))<<(8-blueBits);
    wire [7:0] greenDat = ((dat>>blueBits) & ((1<<greenBits)-1))<<(8-greenBits);
    wire [7:0] redDat =   (((dat>>blueBits)>>greenBits) & ((1<<redBits)-1))<<(8-redBits);
    //wire [23:0] writeMask = (blueMask<<(8-blueBits)) | (greenMask<<(8-greenBits+8-blueBits)) | (redMask<<(8-redBits+8-greenBits+8-blueBits));



    wire [7:0] modulus = (2**(depth[2:0]+1))-1;
    //spi bus
    //assign PIN_22 = 0;
    wire spiclk;
    wire writeMem;
    assign spiclk = PIN_24 && PIN_21;


    reg [1:0] cmd = 0;
    reg [3:0] ctr = 0;
    reg [6*2-1:0] pos = 0;
    reg [8*3-1:0] dat = 0;
    reg [4:0] datPos = 0;

    wire [4:0] datPosMax = redBits + greenBits + blueBits;

    reg [23:0] tmp = 0;
    always @ ( posedge spiclk ) begin
      if (PIN_20) begin
        //three commands: 0 is to reset the screen pointer and data channel
        //                11 is to set the color bit depth and row xor mask
        //                10 is to set the brightness bounds
        if (PIN_23 == 0 && cmd == 0)begin
          //reset <= 1;
          datPos <= -1;
          //dat <= 0;
          pos <= 0;
        end
        else begin
          if (cmd[1] == 0) begin
            cmd = (cmd << 1) | PIN_23;
            ctr = 0;
          end else begin
            if (cmd[0] == 1) begin
              vset = (vset << 1) | PIN_23;
              ctr = ctr + 1;
              if (ctr == 15)
                cmd = 0;

            end else begin
              brightness = (brightness << 1) | PIN_23;
              ctr = ctr + 1;
              if (ctr == 12)
                cmd = 0;
            end
          end
        end
      end else begin
        dat = (dat <<1) | PIN_23;
        datPos = datPos + 1;
        if (datPos == datPosMax)
          begin
            begin
              if (vset[12] == 1)
                vram[pos][7:0] <= redDat;//((dat & blueMask)<<(8-blueBits)) | ((dat & greenMask)<<(8-greenBits+8-blueBits)) | ((dat & redMask)<<(8-redBits+8-greenBits+8-blueBits));
              if (vset[13] == 1)
                vram[pos][15:8] <= greenDat;
              if (vset[14] == 1)
                vram[pos][23:16] <= blueDat;
            end
            pos = pos + 1;
            datPos <= 0;
        end
      end
    end








    //tmp vars bc cant have async reading of block ram
    wire [2:0] rgb1;
    wire [2:0] rgb2;
    reg [23:0] trgb1;
    reg [23:0] trgb2;
    //reg [0:0] oeMask = 0;
    wire [4:0] row;

    wire clock = (PIN_19?PIN_18:CLK);

    reg [0:0] preScanned = 0;
    reg [0:0] whichScan = 0;
    reg [0:0] scanning = 0;
    reg [0:0] willScan = 0;
    wire [0:0] setScan = (position == 0 && whichScan == 0)?1:0;
    always @(posedge PIN_17 | setScan) begin
      willScan = PIN_17;
    end
    assign PIN_16 = scanning;

    assign row = position[10:6] - (preScanned == 1?0:1);
    wire which = (whichScan==0 && position[10:6]>=31)? 1:whichScan;


    always @(posedge clock) begin

      trgb1 <= vram[position]      ;
      trgb2 <= vram[position+64*32];

        if (scanning == 0)
        begin
          position = position + 1;
          if (position == 0) begin
            bitCounter = (bitCounter%modulus) + 1;
            scanning = willScan;
            preScanned = 0;
          end
        end
        else
        begin
          if (preScanned == 1)
            { preScanned, scanning , whichScan , position } = { preScanned, scanning , whichScan , position } + 1;
          else
            { preScanned , position[5:0] } = position[5:0] + 1;

        end
        //bitCounter <= (scanning == 0 && Nposition == 0)? (bitCounter%modulus) + 1 : bitCounter;
        //scanning <= (Nposition == 0)? willScan:scanning;
        //preScanned <= (scanning == 0)? ((Nposition == 0)? 0:preScanned) : ((Nposition == 64 && preScanned == 0)?1:preScanned);
        //position <= (scanning == 1 && Nposition == 64 && preScanned == 0)? 0 : Nposition;
        //whichScan <= (Nposition == 0)? ~whichScan : whichScan;
    end

    assign LED = bitCounter[depth[2:0]];
    assign PIN_22 = (bitCounter == 1 && position == 0?1:0); //also tell the processor it's ready for a new frame

    assign latch = (preScanned == 1? clock : (position[6-1:0] == 0? 1: 0)) ;
    wire [0:0] oelow;
    assign oelow = (position[6-1:0] >= brightness[5+6:0+6])? 0:1;
    wire oe = preScanned? clock : (position[6-1:0] <= brightness[5:0]? oelow:1);
    wire [2:0] bitID;

    assign bitID[2] = (bitCounter[7:4] == 0? 0: 1);
    assign bitID[1] = (bitID[2]?(bitCounter[4+3:4+2] == 0? 0:1):(bitCounter[3:2] == 0? 0:1));
    assign bitID[0] = (bitCounter[bitID[2:1]*2+1] == 0? 0:1);

    wire [2:0] whichBit = bitID + (7-depth);


    assign rgb1[0] = scanning == 0? trgb1[whichBit]    :((position[5:0] == 63 && which == 0)? 1:0);
    assign rgb1[1] = scanning == 0? trgb1[whichBit+8]  :0;
    assign rgb1[2] = scanning == 0? trgb1[whichBit+8*2]:0;

    assign rgb2[0] = scanning == 0? trgb2[whichBit]    :((position[5:0] == 63 && which == 1)? 1:0);
    assign rgb2[1] = scanning == 0? trgb2[whichBit+8]  :0;
    assign rgb2[2] = scanning == 0? trgb2[whichBit+8*2]:0;

    //rgb1
    assign PIN_6 = rgb1[0];
    assign PIN_7 = rgb1[1];
    assign PIN_8 = rgb1[2];

    //rgb2
    assign PIN_9 = rgb2[0];
    assign PIN_10 = rgb2[1];
    assign PIN_11 = rgb2[2];


    //same clock, but other phase
    assign PIN_13 = ~clock;

    //latch when done with each row
    assign PIN_12 = latch;

    //oe
    assign PIN_14 = oe;

    //put row select out
    assign PIN_1 = row[0];// ^ depth[3];
    assign PIN_2 = row[1];// ^ depth[4];
    assign PIN_3 = row[2];// ^ depth[5];
    assign PIN_4 = row[3];// ^ depth[6];
    assign PIN_5 = row[4];// ^ depth[7];
endmodule

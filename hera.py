#talk to the fpga mmc
from fpga import fpga
def disasmH(opc,cond_pre="",cond_post="",reg_pre="",reg_post=""):
    def reg(n):
        return reg_pre+"r"+str(n)+reg_post
    def cond(n):
        return cond_pre+["R","!","L","GE","LE","G","ULE","UG","Z","NZ","C","NC","S","NS","V","NV"][n]+cond_post
    def signed(v,bits=8):
        return v&((1<<bits)-1)|((((v>>(bits-1))&1)*-1)<<bits)
    a = opc>>12
    b = (opc>>8)&15
    c = (opc>>4)&15
    d = opc&15
    if a == 0:
        return "B"+cond(b)+"R("+str(signed(opc,8))+")"
    if a == 1 and c == 0:
        return "B"+cond(b)+"("+reg(d)+")"
    if a == 2:
        if b <= 1:
            return ["CALL(","RETURN("][b]+reg(c)+","+reg(d)+")"
        if b == 2 and c == 0:
            return "SWI("+str(d)+")"
        if b == 3 and c == 0 and d == 0:
            return "RTI()"
    if a == 3:
        if c < 6:
            return ["LSL(","LSR(","LSL8(","LSR8(","ASL(","ASR("][c]+reg(b)+","+reg(d)+")"
        if c == 6 and b&6==0:
            return ["SETF(","CLRF("][b>>3]+bin((b&1<<4)|d)+")"
        if c == 7 and d&7==0:
            return ["SAVEF(","RSTRF("][d>>3]+reg(b)+")"
        if c > 7:
            return ["INC(","DEC("][(c>>2)&1]+reg(b)+","+str(1+opc&0x3f)+")"
    if a>>2 == 1:
        return ["LOAD(","STORE("][(a&2)>>1]+reg(b)+","+str(((a&1)<<4)|c)+","+reg(d)+")"
    if 8 <= a <= 13:
        return ["AND(","OR(","ADD(","SUB(","MULT(","XOR("][a-8]+reg(b)+","+reg(c)+","+reg(d)+")"
    if a >= 14:
        return ["SETLO(","SETHI("][a&1]+reg(b)+","+str(signed(opc&0xff,8+(a&1)))+")"
    return "?"+hex(0x10000|opc)[3:]+"?"

def disasmA(opc,cond_pre="",cond_post="",reg_pre="",reg_post=""):
    def reg(n):
        return reg_pre+"r"+str(n)+reg_post
    def cond(n):
        return cond_pre+["","!,","<,","≥,","≤,",">,","u≤,","u>,","z,","nz,","c,","nc,","s,","ns,","v,","nv,"][n]+cond_post
    def signed(v,bits=8):
        return v&((1<<bits)-1)|((((v>>(bits-1))&1)*-1)<<bits)
    a = opc>>12
    b = (opc>>8)&15
    c = (opc>>4)&15
    d = opc&15
    if a == 0:
        if opc&0xff == 0:
            return "halt "+cond(b).rstrip(',')
        return "jr "+cond(b)+str(signed(opc,8))
    if a == 1 and c == 0:
        return "jp "+cond(b)+reg(d)
    if a == 2:
        if b <= 1:
            return ["call ","ret "][b]+reg(d)+", fp:"+reg(b)
        if b == 2 and c == 0:
            return "swi "+str(d)
        if b == 3 and c == 0 and d == 0:
            return "rti"
    if a == 3:
        if c < 6:
            return ["lsl ","lsr ","lsl8 ","lsr8 ","asl ","asr "][c]+reg(b)+" <- "+reg(d)
        if c == 6 and b&6==0:
            return ["setf ","clrf "][b>>3]+bin((b&1<<4)|d)
        if c == 7 and d&7==0:
            r = reg(b)
            return "ld "+[r+' <- f','f <- '+r][d>>3]
        if c > 7:
            return ["inc ","dec "][(c>>2)&1]+reg(b)+" by "+str(1+opc&0x3f)
    if a>>2 == 1:
        r1 = reg(b)
        r2 = reg(d)
        of = str(((a&1)<<4)|c)
        return "ld "+[r1+" <- ("+r2+"+"+of+")","("+r2+"+"+of+") <- "+r1][(a&2)>>1]
    if 8 <= a <= 13:
        return reg(b) + " <- "+reg(c)+[" & "," | "," + "," - "," * "," ^ "][a-8]+reg(d)
    if a >= 14:
        return "ld "+reg(b)+["","h"][a&1]+" <- "+str(signed(opc&0xff,8+(a&1)))
    return "?"+hex(0x10000|opc)[3:]+"?"

disasm = disasmA

import struct
import pyb
class Hera_comm:
    def __init__(self,fpga):
        self.fpga = fpga
    def init_spi(self,phase=0,polarity=0,**ka):
        self.fpga.spi.init(mode=pyb.SPI.MASTER,phase=phase,polarity=polarity,**ka)
        self.fpga.cs.init(mode=pyb.Pin.OUT_PP)
    def loadfpga(self,path="fpga configs/hera_np.bin"):
        with open(path,"rb") as f:
            self.fpga.viper_load(f)
        self.init_spi()
        return self.ping()
    def send(self,cmd):
        self.fpga.cs(0)
        self.fpga.spi.send(b'\0')
        self.fpga.cs(1)
        return self.fpga.spi.send_recv(cmd)
    def read(self,i):
        r = self.send(b'R'+struct.pack(">H",i)+b'\0\0\0')
        return struct.unpack(">H",r[4:6])[0]
    def write(self,i,v):
        r = self.send(b'W'+struct.pack(">HH",v,i))
        return r
    def __getitem__(self,i):
        return self.read(i)
    def __setitem__(self,i,v):
        self.write(i,v)
    def halt(self):
        return self.send(b'H\0')
    def run(self):
        return self.send(b'h\0')
    def step(self):
        return self.send(b'S\0')
    def ping(self):
        return self.send(b'PING\0')
    def toggle_reset(self):
        return self.send(b'r\0')[1] == 0
    def set_reset(self):
        if not self.toggle_reset():
            self.toggle_reset()
    def reset_reset(self):
        if self.toggle_reset():
            self.toggle_reset()
    def load(self,program,addr=0):
        self.set_reset()
        i = 0
        for v in program:
            self[addr+i] = v
            i += 1
    def disasm(self,start=0,num=16,*a):
        return "\n".join((disasm(self[i],*a) for i in range(start,start+num)))

    def reg(self,i):
        return struct.unpack(">H",self.send(b'Dr'+struct.pack(">B",i)+'\0\0')[3:5])[0]
    def flags(self):
        r = struct.unpack(">BH",self.send(b'Df\0\0\0')[2:5])
        return {'opcode':r[1],
            '1':r[0]>>7,
            'data':(r[0]>>6)&1,
            'w':(r[0]>>5)&1,
            'cb':(r[0]>>4)&1,
            'c':(r[0]>>3)&1,
            'v':(r[0]>>2)&1,
            'z':(r[0]>>1)&1,
            's':r[0]&1,
        }

    def mm(self):
        r = struct.unpack(">BH",h.send(b'Dm\0\0\0')[2:5])
        return {'opcode':r[1],
            '1':r[0]>>7,
            'step':(r[0]>>6)&1,
            'step_r':(r[0]>>5)&1,
            'run':(r[0]>>4)&1,
            'hclk':(r[0]>>3)&1,
            'res':(r[0]>>2)&1,
            'imm_op':(r[0]>>1)&1,
            'imm_op_r':r[0]&1,
        }
    def debug(self):
        return [self.flags()]+[self.reg(i) for i in range(16)]

    def opcode(self,opc):
        return self.send(b'O'+struct.pack(">H",opc))

    def debugger_print_status(self,true='\x1b[m\x1b[38:5:10m\x1b[1m',false='\x1b[m\x1b[38:5:1m'):
        c = '\x1b[m'
        m = self.mm()
        vs = (m['1'],m['step']^m['step_r'],m['run'],m['hclk'],m['res'],m['imm_op']^m['imm_op_r'])
        r = " ".join(((false,true)[vs[i]]+('1','step','run','clk','rst','imm_op')[i]+c for i in range(6)))
        r += '\n'
        f = self.flags()
        rs = [self.reg(i) for i in range(16)]
        #regs = ['pc','r0']
        def reg(i):
            if i:
                return "r"+str(i)
            return "pc"
        def addr(v):
            return hex(0x10000|(v&0xffff))[3:]
        b = '\x1b[1m'
        pc = rs[0]
        for i in range(8):
            v = self[pc-3+i]
            r += b+reg(i)+c+'  =\t'+str(rs[i])+"\t"+b+reg(i+8)+c+'  =\t'+str(rs[i+8])+"\t|"+b*(i==3)+addr(pc-3+i)+c+":"+addr(v)+" "+disasm(v)+"\n"
        r += "flags:"
        fs = (f['1'],f['data'],f['w'],f['cb'],f['c'],f['v'],f['z'],f['s'])
        r += " ".join(((false,true)[fs[i]]+('1','data','write','cb','c','v','z','s')[i]+c for i in range(8)))
        r += " opcode:"+disasm(f['opcode'])
        print(r)


    def test(self):
        print("#init")
        self.fpga.viper_load(open("fpga configs/hera_np.bin","rb"))
        self.init_spi(1,1,baudrate=1)
        print("#ping")
        print(self.send(b"P\0\0\0\0"))
        print("#load")
        self.load([0xe100,0xf101,0xe2ff,0xe319,0xe405,0x6201,0x3180,0x33c0,0x1904,0x0000])
        print("#disasm")
        print(self.disasm())
        print("#mm")
        print(self.mm())
        print("#status")
        self.debugger_print_status()
        print("#unreset")
        print(self.send(b"r\0\0"))
        print("#unhalt")
        print(self.send(b"h\0\0"))
        pyb.delay(100)
        print("#status")
        self.debugger_print_status()
        print("#mem[255,256,257]")
        print(self[255],self[256],self[257])

    def test_rst(self):
        self.set_reset()
        self.halt()
        self.step()
        print(self.mm())
        print(self.flags())
        print('pc=',self.reg(0))
    def debugger():
        pass
    


h = Hera_comm(fpga)

#example program
# 0: setlo r1 0      :0xe100
# 1: sethi r1 1      :0xf101
# 2: setlo r2 -1     :0xe2ff
# 3: setlo r3 25     :0xe319
# 4: setlo r4 5      :0xe405
# 5: store (r1) r2   :0x6201
# 6: inc r1          :0x3180
# 7: dec r3          :0x33c0
# 8: bnz r4          :0x1904
# 9: halt (brr(0))   :0x0000
# h.load([0xe100,0xf101,0xe2ff,0xe319,0xe405,0x6201,0x3180,0x33c0,0x1904,0x0000])

fpga.viper_load(open("fpga configs/hera_np.bin","rb"))
h.init_spi(1,1,baudrate=1)

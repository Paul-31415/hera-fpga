#from hera import disasm
from text_ui import Ansi_decode,ansi_move_csr,Char_grid
import sys





class Hera_Debugger:
    def __init__(self,hera_comm,stdin = sys.stdin):
        self.h = hera_comm
        self.stdin = stdin
        self.ansi_stdin = Ansi_decode(stdin)
        #other state vars:
        self.reg_selected = 1


    def do_state(self):
        v = {'raw':''}
        while v['raw'] != "\x03":#ctrl-c
            v = self.ansi_stdin.read1()
            mx = 0
            my = 0
            if v['cmd'] is not None:
                if v['cmd'] != '?':
                    if v['cmd'][0] == 'cursor move x':
                        mx = v['cmd'][1]
                    elif v['cmd'][0] == 'cursor move y':
                        my = v['cmd'][1]
            self.reg_selected = (self.reg_selected+my+8*mx)%16
            
            self.print_state()
        

    def print_state(self):
        true='\x1b[m\x1b[38;5;10m\x1b[1m'
        false='\x1b[m\x1b[38;5;1m'
        c = '\x1b[m'
        invert = '\x1b[7m'
        m = self.h.mm()
        vs = (m['1'],m['step']^m['step_r'],m['run'],m['hclk'],m['res'],m['imm_op']^m['imm_op_r'])
        r = " ".join(((false,true)[vs[i]]+('1','step','run','clk','rst','imm_op')[i]+c for i in range(6)))
        r += '\n\r'
        f = self.h.flags()
        rs = [self.h.reg(i) for i in range(16)]
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
            v = self.h[pc-3+i]
            sel1 = invert*(self.reg_selected == i)
            sel2 = invert*(self.reg_selected == i+8)
            r += b+reg(i)+c+'  =\t'+sel1+str(rs[i])+c+"\t"+b+reg(i+8)+c+'  =\t'+sel2+str(rs[i+8])+c+"\t|"+b*(i==3)+addr(pc-3+i)+c+":"+addr(v)+" "+disasm(v)+"\n\r"
        r += "flags:"
        fs = (f['1'],f['data'],f['w'],f['cb'],f['c'],f['v'],f['z'],f['s'])
        r += " ".join(((false,true)[fs[i]]+('1','data','write','cb','c','v','z','s')[i]+c for i in range(8)))
        r += " opcode:"+disasm(f['opcode'])
        print(r)
        print(ansi_move_csr(0,-10),end='\r')
        





        
        
    def debug(self):        
        self.do_state()

        





























def disasm(opc,cond_pre="",cond_post="",reg_pre="",reg_post=""):
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




















class dummy_hera_comm: #for debugging
    def __init__(self):
        self._mem = [0]*8192
        self._rst = 0
        self._run = 0
        self._regs = [0]*16
        self._step = 0
        self._opcode = 0
        self._flags = 0
    def halt(self):
        old = self._run
        self._run = 0
        return [b'\0H',b'\0h'][old]
    def run(self):
        old = self._run
        self._run = 1
        return [b'\0H',b'\0h'][old]
    def step(self):
        self._regs[0] += 1
        return b'\0S'
    def toggle_reset(self):
        self._rst ^= 1
        return self._rst == 0
    def set_reset(self):
        if not self.toggle_reset():
            self.toggle_reset()
    def reset_reset(self):
        if self.toggle_reset():
            self.toggle_reset()
    def disasm(self,start=0,num=16,*a):
        return "\n".join((disasm(self[i],*a) for i in range(start,start+num)))
    def reg(self,i):
        return self._regs[i%16]
    def flags(self):
        return {'opcode':self._opcode,
                '1':1,
                'data':0,
                'w':0,
                'cb':(self._flags>>4)&1,
                'c':(self._flags>>3)&1,
                'v':(self._flags>>2)&1,
                'z':(self._flags>>1)&1,
                's':self._flags&1,
                }
    def mm(self):
        return {'opcode':self._opcode,
                '1':1,
                'step':self._step,
                'step_r':self._step,
                'run':self._run,
                'hclk':0,
                'res':self._rst,
                'imm_op':0,
                'imm_op_r':0,
                }
    def opcode(self,opc):
        self._opcode = opc&0xffff
    def debugger_print_status(self,true='\x1b[m\x1b[38;5;10m\x1b[1m',false='\x1b[m\x1b[38;5;1m'):
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
    def __getitem__(self,i):
        return self._mem[i%8192]
    def __setitem__(self,i,v):
        self._mem[i&8192]=v&0xffff



class workaround:
    def __init__(self):
        pass
    def read(self,n):
        return ''.join((getch() for i in range(n)))
        

h = dummy_hera_comm()


hd = Hera_Debugger(h,workaround())













#from https://code.activestate.com/recipes/134892-getch-like-unbuffered-character-reading-from-stdin/
class _Getch:
    """Gets a single character from standard input.  Does not echo to the
screen."""
    def __init__(self):
        try:
            self.impl = _GetchWindows()
        except ImportError:
            self.impl = _GetchUnix()

    def __call__(self): return self.impl()


class _GetchUnix:
    def __init__(self):
        import tty, sys

    def __call__(self):
        import sys, tty, termios
        fd = sys.stdin.fileno()
        old_settings = termios.tcgetattr(fd)
        try:
            tty.setraw(sys.stdin.fileno())
            ch = sys.stdin.read(1)
        finally:
            termios.tcsetattr(fd, termios.TCSADRAIN, old_settings)
        return ch


class _GetchWindows:
    def __init__(self):
        import msvcrt

    def __call__(self):
        import msvcrt
        return msvcrt.getch()


getch = _Getch()

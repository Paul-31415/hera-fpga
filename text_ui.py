import sys

class Ansi_decode:
    def __init__(self,filelike=sys.stdin):
        self.f = filelike
    def read_1_code(self):
        c = self.f.read(1)
        if c != '\x1b':
            return c
        t = self.f.read(1)
        if t == '[': #csi
            r = c+t
            while 1:
                c = self.f.read(1)
                r += c
                if 0x40 <= ord(c) <= 0x7e:
                    return r
        #else assume it is ST terminated
        r = c+t
        while 1:
            c = t
            t = self.f.read(1)
            r += t
            if c+t == '\x1b\\':
                return r  
    def interperet_important_cs(self,cs):
        final = cs[-1]
        args = cs[2:-1]
        if final in "ABCD": #arrow keys
            return ["cursor move x","cursor move y"][final in "AB"], ((final in "BC")*2-1)*(int(args) if len(args) else 1)
        return "?"
    def read1(self):
        r = self.read_1_code()
        if r[0] == '\x1b':
            try:
                c = self.interperet_important_cs(r)
            except:
                c = "?"
            return {'raw':r,'cmd':c,'text':''}
        return {'raw':r,'cmd':None,'text':r}
    def read_until_cmd(self):
        r = ''
        while 1:
            c = self.read1()
            if c['cmd'] is not None:
                return r,c
            r += c['text']
        
def itify(v,short=False):
    try:
        v = iter(v)
    except TypeError:
        yield v
        while not short:
            yield v
    else:
        for r in v:
            yield r

def it_vals(v):
    try:
        return [i for i in v]
    except TypeError:
        return [v]

def is_iterable(v):
    try:
        iter(v)
    except TypeError:
        return False
    else:
        return True

class Vec:
    def __init__(self,a):
        self.a = a
    def __repr__(self):
        return "Vec("+repr(self.a)+")"
    def __iter__(self):
        return iter(self.a)
    def __len__(self):
        return len(self.a)
    def __add__(self,o):
        o = itify(o)
        return Vec([v+next(o) for v in self.a])
    def __radd__(self,o):
        o = itify(o)
        return Vec([next(o)+v for v in self.a])
    def __sub__(self,o):
        o = itify(o)
        return Vec([v-next(o) for v in self.a])
    def __rsub__(self,o):
        o = itify(o)
        return Vec([next(o)-v for v in self.a])
    def __mul__(self,o):
        o = itify(o)
        return Vec([v*next(o) for v in self.a])
    def __rmul__(self,o):
        o = itify(o)
        return Vec([next(o)*v for v in self.a])
    def __truediv__(self,o):
        o = itify(o)
        return Vec([v/next(o) for v in self.a])
    def __rtruediv__(self,o):
        o = itify(o)
        return Vec([next(o)/v for v in self.a])
    def __mod__(self,o):
        o = itify(o)
        return Vec([v%next(o) for v in self.a])
    def __rmod__(self,o):
        o = itify(o)
        return Vec([next(o)%v for v in self.a])
    def __and__(self,o):
        o = itify(o)
        return Vec([v&next(o) for v in self.a])
    def __rand__(self,o):
        o = itify(o)
        return Vec([next(o)&v for v in self.a])
    def __or__(self,o):
        o = itify(o)
        return Vec([v|next(o) for v in self.a])
    def __ror__(self,o):
        o = itify(o)
        return Vec([next(o)|v for v in self.a])
    def __xor__(self,o):
        o = itify(o)
        return Vec([v^next(o) for v in self.a])
    def __rxor__(self,o):
        o = itify(o)
        return Vec([next(o)^v for v in self.a])
    def __lshift__(self,o):
        o = itify(o)
        return Vec([v<<next(o) for v in self.a])
    def __rlshift__(self,o):
        o = itify(o)
        return Vec([next(o)<<v for v in self.a])
    def __rshift__(self,o):
        o = itify(o)
        return Vec([v>>next(o) for v in self.a])
    def __rrshift__(self,o):
        o = itify(o)
        return Vec([next(o)>>v for v in self.a])
    def __neg__(self):
        return Vec([-v for v in self.a])
    def __abs__(self):
        return Vec([abs(v) for v in self.a])
    def __invert__(self):
        return Vec([~v for v in self.a])
    
    
def ansi_move_csr(dx,dy):
    r = ''
    if dx != 0:
        r += '\x1b['+str(abs(dx))+'CD'[dx<0]
    if dy != 0:
        r += '\x1b['+str(abs(dy))+'BA'[dy<0]
    return r
    

class Char_grid:
    def __init__(self,w,h):
        class c:
            def __init__(self,v):
                self.v = v
            def __repr__(self):
                return repr(self.v)+".c"
            def __getitem__(self,i):
                return self.v.getcolors(i)
            def __setitem__(self,i,v):
                return self.v.__setitem__(i,v)
        self.c = c(self)
        self.init(w,h)
    def init(self,w,h):
        self.width = w
        self.height = h
        self.chars = [" "]*w*h
        self.colors = [15]*w*h
    def __len__(self):
        return len(self.chars)
    def ind_calc(self,x,y=0):
        return (x+self.width*y)%len(self.chars)
    def inds_iter(self,i,region=False,short=False,cont=False):
        if type(i) is tuple:
            x,y = i
        else:
            x = i
            y = 0
        if type(x) is slice:
            x = self.slice_iter(x,self.width,short)
        if type(y) is slice:
            y = self.slice_iter(y,self.height,short)
        if region:
            x = it_vals(x)
            for yy in itify(y,True):
                for xx in x:
                    yield xx,yy
        else:
            if is_iterable(x) or is_iterable(y) or not short:
                if cont and not (is_iterable(x) or is_iterable(y)):
                    x = self.slice_iter(slice(x,None,1),len(self.chars))
                else:
                    x = itify(x)
                y = itify(y)
                try:
                    while 1:
                        yield next(x),next(y)
                except StopIteration as e:
                    pass
            else:
                yield x,y
                
    def slice_iter(self,s,mod,short=False):
        if short:
            for i in range(*s.indices(mod)):
                yield i
        else:
            l,d,h = s.start or 0,s.step if s.step is not None else 1,s.stop
            l %= mod
            n = ((h%mod)-l)//d if h is not None else -1
            while n != 0:
                yield l
                l = (l+d)%mod
                n -= 1
    def __getitem__(self,i):
        return ''.join((self.chars[self.ind_calc(x,y)] for x,y in self.inds_iter(i,short=True)))
    def getcolor(self,x,y=0):
        return self.colors[self.ind_calc(x,y)]
    def getcolors(self,i):
        return Vec([self.getcolor(x,y) for x,y in self.inds_iter(i,short=True)])
    def __setitem__(self,i,v):
        if type(v) is str:
            if len(v) == 1:
                for x,y in self.inds_iter(i,True):
                    self.chars[self.ind_calc(x,y)] = v
            else:
                it = self.inds_iter(i,cont=True)
                for c in v:
                    x,y = next(it)
                    self.chars[self.ind_calc(x,y)] = c
        elif type(v) is int:
            for x,y in self.inds_iter(i,True):
                self.colors[self.ind_calc(x,y)] = v
        elif is_iterable(v):
            it = self.inds_iter(i,cont=True)
            for c in v:
                x,y = next(it)
                self[x,y] = c
    def color(self,c):
        effects = (1,4,5,7,8)
        e = ''
        for i in range(len(effects)):
            if ((c>>16)>>i)&1:
                e += '\x1b['+str(effects[i])+'m'
        return "\x1b[38;5;"+str(c&0xff)+"m\x1b[48;5;"+str((c>>8)&0xff)+"m"+e
    def __repr__(self):
        return "Char_grid("+str(self.width)+"x"+str(self.height)+")"
    def __str__(self):
        nl = '\x1b[B\x1b['+str(self.width)+'D'
        return '\x1b[m'+nl.join(('\x1b[m'.join((self.color(self.colors[i])+self.chars[i] for i in range(r*self.width,(r+1)*self.width))) for r in range(self.height)))+'\x1b[m\x1b['+str(self.height)+'A'
    def print(self,ox=0,oy=0,end=""):
        print(ansi_move_csr(ox,oy)+str(self)+ansi_move_csr(-ox,-oy),end=end)
    
                
        
    

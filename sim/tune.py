import math, sim
def xpN(L): return XPF(L)
XPF=lambda L: 20+L*15+max(0,L-8)*L*3
sim.xpNeed=xpN
orig=sim.sim
def run(hiCap, hiDiv, starF, coinF):
    # patch hi formula
    import types
    src=sim.sim
    def s2(**kw):
        L=1; xp=0; stars=0; coins=0; done=0; out=[]
        for d in range(1,91):
            glv = 1 if d<10 else (2 if d<30 else 3)
            nch=sum(1 for c,u in sim.CH if u<=L)
            taps=min(3*min(100,nch*(24,36,48)[glv-1])+100, 400)
            V=taps*sim.avgval(glv)*0.7
            hi=min(hiCap, 3+L//hiDiv); lo=max(2,hi-3)
            n=1 if L<3 else 1.6
            v=sum(2**(t-1) for t in range(lo,hi+1))/(hi-lo+1)*n
            orders=V/v
            st=orders*starF(v)+9+(6 if d%7 in (6,0) else 0)
            stars+=st; c=orders*coinF(v)+6*coinF(v); coins+=c
            xp+=orders*max(1,v/2)+V
            while xp>=xpN(L): xp-=xpN(L); L+=1
            while done<72 and stars>=sim.TASKS[done]: stars-=sim.TASKS[done]; done+=1
            out.append((d,L,round(orders,1),round(st),round(c),done))
        return out
    for r in s2():
        if r[0] in (1,2,3,5,7,10,14,21,30,45,60,75,90): print('day %2d  L%2d  orders %5s  stars %3d  coins %4d  tasks %d/72'%r)
print('A: hi<=7, 3+L/4, stars=clamp(v/8,1,3)+?, coins v/8')
run(7,4, lambda v:max(1,min(3,round(v/10))), lambda v:max(1,round(v/8)))
def xpN2(L): return 30+L*20+max(0,L-8)*L*4
sim_x = xpN2
import sim as S
XPF=xpN2
print('B: stars v/13, xp slower')
run(7,4, lambda v:max(1,min(3,round(v/13))), lambda v:max(1,round(v/8)))

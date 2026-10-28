import random, math
random.seed(1)
CH=[('rice',1),('veg',1),('tea',2),('sweet',3),('fruit',5),('snack',7),('milk',10),('egg',13)]
APPL={4:1,6:1,8:1,11:1,14:1}
TASKS=[2,3,4,4,5,6,6,7,8,9,10,12]+[10,11,12,13,14,15,14,15,16,17,18,20]+[16,17,18,20,21,22,22,24,25,26,28,30]+[22,24,25,27,28,30,30,32,34,35,37,40]+[30,32,34,35,37,40,38,40,42,44,46,50]+[40,43,45,48,50,52,52,55,58,60,64,70]
CHAPEND={i for i in range(11,72,6)}
def xpNeed(L): return 12+L*10+max(0,L-10)*L*2
def avgval(glv): return {1:1.1,2:1.4,3:1.75}[glv]
def sim(days=90, mins=18, sessions=3, hiCap=8, starF=lambda v: max(1,min(6,round(math.sqrt(v)/2))), coinF=lambda v:max(1,v//6), charges=(24,36,48), eff=0.7, verbose=False):
    L=1; xp=0; stars=0; gems=10; coins=0; done=0; glv=1; log=[]
    for d in range(1,days+1):
        # gens upgrade over time: merging 2 gens needs 2 of same -> assume via chests: lvl2 at day 10, lvl3 at day 30
        glv = 1 if d<10 else (2 if d<30 else 3)
        nch=sum(1 for c,u in CH if u<=L)
        perSession=min(100, nch*charges[glv-1])
        taps=sessions*perSession + 60 + 30 + 10   # steps, goals, login
        taps=min(taps, sessions*100+100)
        V=taps*avgval(glv)*eff
        hi=min(hiCap, 3+L//3); lo=max(2,hi-3)
        n=1 if L<3 else 1.95
        itemv=sum(2**(t-1) for t in range(lo,hi+1))/(hi-lo+1)
        v=itemv*n
        orders=V/v
        dayStars=orders*starF(v) + 3*3 + (6 if d%7 in (6,0) else 0)
        dayCoins=orders*coinF(int(v)) + 3*2*coinF(int(v))
        stars+=dayStars; coins+=dayCoins
        dxp=V/2*0+orders*max(1,v/2)+V   # merges ~ V
        xp+=dxp
        while xp>=xpNeed(L): xp-=xpNeed(L); L+=1
        while done<72 and stars>=TASKS[done]: stars-=TASKS[done]; done+=1
        log.append((d,L,round(orders,1),round(dayStars),round(dayCoins),done))
    return log
if __name__=='__main__':
    import sys
    for name,kw in [('current-ish',dict(hiCap=10,starF=lambda v:max(1,min(4,v//12+1)),coinF=lambda v:max(1,v),charges=(8,12,16))),('proposed',{})]:
        log=sim(**kw)
        print('==',name)
        for r in log:
            if r[0] in (1,2,3,5,7,10,14,21,30,45,60,75,90): print('day %2d  L%2d  orders/day %5s  stars/day %3d  coins/day %4d  tasks %d/72'%r)

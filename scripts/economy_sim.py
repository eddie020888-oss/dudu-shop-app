# 一天的需求消耗 vs 收入：三种人
import math
def day(hours, night_factor, sleep=(23,7)):
    # 一天有效流逝小时（睡觉时段按 night_factor 计）
    s,w=sleep; night=(24-s)+w
    return (24-night)+night*night_factor
foods={'carrot':(5,{'h':.20}),'rice':(12,{'h':.40,'j':.05}),'coffee':(8,{'t':.30,'j':.15}),'popcorn':(15,{'h':.10,'j':.30}),'cake':(20,{'h':.25,'j':.20})}
def cost_per_bar(): return {k:v[0]/v[1].get('h',1e9) for k,v in foods.items()}
personas={
 '躺平党':dict(checkin=10,found=15,chat=5,play=6,wake=0,steps=0,workout=0),
 '上班族':dict(checkin=14,found=12,chat=5,play=8,wake=10,steps=10,workout=0),   # 8k 步=5+10
 '运动狂':dict(checkin=20,found=8,chat=5,play=10,wake=10,steps=30,workout=40),
}
for label,(H,nf) in {'现在(饿6h,夜间照常)':(6,1),'改后(饿16h,夜间×0.3)':(16,.3)}.items():
    eff=day(24,nf); bars=eff/H
    print(f'\n== {label}: 每天要补 {bars:.2f} 格饱食')
    print('   最便宜(胡萝卜 5币/20%) 每天花', round(bars/.2*5), '币；饭团', round(bars/.4*12),'币；混吃(一半饭团一半胡萝卜)', round(bars/.2*5/2+bars/.4*12/2))
    for p,inc in personas.items():
        tot=sum(inc.values()); food=round(bars/.2*5/2+bars/.4*12/2)
        print(f'   {p}: 收入 {tot}/天，吃饭 {food}，结余 {tot-food} → 一件配饰(均价~55)要 {55/max(1,tot-food):.1f} 天' if tot>food else f'   {p}: 收入 {tot}/天，吃饭 {food}，每天亏 {food-tot}')

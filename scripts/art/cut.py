import sys, json, os
from PIL import Image
import numpy as np
MAP = {
 "acc1": [("acc_hat_chef",360),("acc_hat_crown",360),("acc_hat_night",360),("acc_hat_flower",360)],
 "acc2": [("acc_hat_beret",360),("acc_hat_bunny",360),("acc_hat_witch",360),("acc_scarf_plaid",360)],
 "acc3": [("acc_glasses_heart",360),("acc_glasses_star",360),("acc_glasses_monocle",360),("acc_glasses_cat",360)],
 "acc4": [("acc_glasses_goggle",360),("acc_glasses_3d",360),("acc_neck_bell",360),("acc_neck_bib",360)],
 "acc5": [("acc_neck_pearls",360),("acc_neck_tie",360),("acc_neck_lei",360),("acc_neck_medal",360)],
 "acc1b": [("acc_hat_chef",360),("acc_hat_crown",360),("acc_hat_night",360),("acc_hat_flower",360)],
 "acc2b": [("acc_hat_beret",360),("acc_neck_pearls",360),("acc_hat_witch",360),("acc_neck_lei",360)],
 "c1": [("mk_gen_coffee",220),("mk_coffee1",220),("mk_coffee2",220),("mk_coffee3",220)],
 "c2": [("mk_coffee4",220),("mk_coffee5",220),("mk_coffee6",220),("mk_coffee7",220)],
 "c3": [("mk_coffee8",220),("mk_coffee9",220),("mk_coffee10",220),("mk_coffeemaker",220)],
 "h1": [("mk_gen_honey",220),("mk_honey1",220),("mk_honey2",220),("mk_honey3",220)],
 "h2": [("mk_honey4",220),("mk_honey5",220),("mk_honey6",220),("mk_honey7",220)],
 "h3": [("mk_honey8",220),("mk_honey9",220),("mk_honey10",220),("mk_dish_honeylemon",220)],
 "e1": [("mk_dish_affogato",220),("mk_dish_tiramisu",220),("mk_dish_latteart",220),("mk_dish_honeytoast",220)],
 "food1": [("food_starcandy",256),("food_sweetpotato",256),("food_strawmilk",256),("food_pudding",256)],
 "food2": [("food_donut",256),("food_icecream",256),("food_boba",256),("food_watermelon",256)],
 "n01": [("nest_cushion_v1",440),("nest_cushion_v2",440),("nest_blanket_v1",440),("nest_blanket_v2",440)],
 "n02": [("nest_lamp_v1",440),("nest_lamp_v2",440),("nest_tv_v1",440),("nest_tv_v2",440)],
 "n03": [("nest_snack_v1",440),("nest_snack_v2",440),("nest_window_v1",440),("nest_window_v2",440)],
 "n04": [("nest_telescope_v1",440),("nest_telescope_v2",440),("nest_nightstand_v1",440),("nest_nightstand_v2",440)],
 "n05": [("nest_lights_v1",440),("nest_lights_v2",440),("nest_painting_v1",440),("nest_painting_v2",440)],
 "n06": [("nest_glowplant_v1",440),("nest_glowplant_v2",440),("nest_slippers_v1",440),("nest_slippers_v2",440)],
 "n07": [("nest_clock_v1",440),("nest_clock_v2",440),("nest_plush_v1",440),("nest_plush_v2",440)],
 "n08": [("nest_floorlamp_v1",440),("nest_floorlamp_v2",440),("nest_beanbag_v1",440),("nest_beanbag_v2",440)],
 "n09": [("nest_plant_v1",440),("nest_plant_v2",440),("nest_chime_v1",440),("nest_chime_v2",440)],
 "n10": [("nest_globe_v1",440),("nest_globe_v2",440),("nest_lounger_v1",440),("nest_lounger_v2",440)],
 "n11": [("nest_books_v1",440),("nest_books_v2",440),("nest_pinboard_v1",440),("nest_pinboard_v2",440)],
 "n12": [("nest_trophies_v1",440),("nest_trophies_v2",440),("nest_beanbag2_v1",440),("nest_beanbag2_v2",440)],
 "n13": [("nest_toybox_v1",440),("nest_toybox_v2",440),("mk_book_home",220),("mk_book_sweet",220)],
 "misc": [("mk_book_star",220),("ui_weekly_gift",220),("ui_coin_pouch",220),("ui_hourglass",220)],
 "d1": [("mk_dish_onigiriset",220),("mk_dish_carrotcake",220),("mk_dish_honeytea",220),("mk_dish_fruitsando",220)],
 "d2": [("mk_dish_daifuku",220),("mk_dish_bobaroll",220),("mk_dish_icesando",220),("mk_dish_popsicle",220)],
 "deep1": [("mk_dish_bubbletea",220),("mk_dish_deluxebento",220),("mk_dish_fruittart",220),("mk_dish_mocha",220)],
 "deep2": [("mk_dish_honeycrepe",220),("mk_dish_curryomu",220),("mk_dish_teatower",220),("mk_dish_parfaittower",220)],
 "deep3": [("mk_dish_starbox",220),("x_starbox_b",220),("x_curryomu_b",220),("x_teatower_b",220)],
 "lucky": [("mk_luckybag",220),("x_luckybag_b",220),("x_x2_badge",220),("x_bolt",220)],
 "w1": [("mk_gen_tea",220),("mk_tea1",220),("mk_tea2",220),("mk_tea3",220)],
 "w2": [("mk_tea4",220),("mk_tea5",220),("mk_tea6",220),("mk_tea7",220)],
 "w3": [("mk_tea8",220),("mk_tea9",220),("mk_tea10",220),("mk_egg5",220)],
 "w4": [("mk_rice4",220),("mk_rice5",220),("mk_rice6",220),("mk_dish_onigiriset",220)],
 "w5": [("mk_dish_teacake",220),("mk_dish_honeytea",220),("mk_dish_bun",220),("mk_dish_mooncake",220)],
 "w6": [("mk_dish_hotpot",220),("x_burger_b",220),("x_croissant_b",220),("x_sushi_b",220)],
 "sugar": [("mk_gen_sweet",220),("mk_sweet1",220),("mk_sweet2",220),("x_pinksugar",220)],
 "t1": [("mk_rice10",220),("mk_rice11",220),("mk_veg10",220),("mk_veg11",220)],
 "t2": [("mk_tea10",220),("mk_tea11",220),("mk_sweet10",220),("mk_sweet11",220)],
 "t3": [("mk_fruit10",220),("mk_fruit11",220),("mk_snack10",220),("mk_snack11",220)],
 "t4": [("mk_milk10",220),("mk_milk11",220),("mk_egg10",220),("mk_egg11",220)],
 "t5": [("mk_coffee10",220),("mk_coffee11",220),("mk_honey10",220),("mk_honey11",220)],
 "f1": [("mk_veg11",220),("mk_tea11",220),("mk_fruit11",220),("mk_coffee10",220)],
 "f2": [("mk_coffee11",220),("mk_honey10",220),("mk_honey11",220),("mk_snack9",220)],
 "f3": [("mk_honey9",220),("mk_egg11",220),("x_saladcart",220),("x_honeydrop",220)],
 "d3": [("mk_dish_ramen",220),("mk_dish_dumpling",220),("mk_dish_pancake",220),("mk_dish_pumpkin",220)],
 # 2026-10-27 纪念款（装修完一整片地方送）
 "aw1": [("nest_snack_v3",440),("nest_painting_v3",440),("nest_plant_v3",440),("nest_floorlamp_v3",440)],
 "aw2": [("nest_globe_v3",440),("nest_window_v3",440),("nest_blanket_v3",440),("nest_lounger_v3",440)],
 "aw3": [("nest_trophies_v3",440),("x_aw_spare1",440),("x_aw_spare2",440),("x_aw_spare3",440)],
}
def cut(sheet, path):
    im = Image.open(path).convert("RGBA"); W,H = im.size
    a = np.array(im)
    # kill near-invisible fringe
    al = a[:,:,3]
    out=[]
    from scipy import ndimage
    solid = al > 20
    lab, n = ndimage.label(ndimage.binary_dilation(solid, iterations=12))
    groups = {0:[],1:[],2:[],3:[]}
    for k in range(1, n+1):
        mk = (lab == k) & solid
        cnt = mk.sum()
        if cnt < 0.002*W*H: continue
        ys,xs = np.where(mk); cy,cx = ys.mean(), xs.mean()
        groups[(1 if cx > W/2 else 0) + (2 if cy > H/2 else 0)].append(mk)
    for q,(name,mx) in enumerate(MAP[sheet]):
        if not groups[q]: out.append((name,None)); continue
        mk = np.any(groups[q], axis=0)
        mk = ndimage.binary_dilation(mk, iterations=3) & (al > 0)
        sub = a.copy(); sub[~mk] = 0
        ys,xs = np.where(mk)
        crop = Image.fromarray(sub[ys.min():ys.max()+1, xs.min():xs.max()+1])
        warn = ys.min()<=1 or xs.min()<=1 or ys.max()>=H-2 or xs.max()>=W-2
        crop.thumbnail((mx,mx), Image.LANCZOS)
        pad = max(2, int(max(crop.size)*0.03))
        c2 = Image.new("RGBA",(crop.width+2*pad, crop.height+2*pad),(0,0,0,0)); c2.paste(crop,(pad,pad))
        c2.save(f"/home/claude/art/out/{name}.png", optimize=True)
        out.append((name, c2.size, "EDGE!" if warn else ""))
    return out
if __name__ == "__main__":
    print(cut(sys.argv[1], sys.argv[2]))

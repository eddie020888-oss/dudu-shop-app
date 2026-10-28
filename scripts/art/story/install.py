import sys, json, os
from PIL import Image
src='/mnt/user-data/uploads/Downloads/isl_art'; dst='/home/claude/island-me/IslandMe/Resources/Assets.xcassets'
for n in sys.argv[1:]:
    im=Image.open(f'{src}/{n}.png').convert('RGB').resize((900,900), Image.LANCZOS)
    d=f'{dst}/{n}.imageset'; os.makedirs(d, exist_ok=True)
    for f in os.listdir(d): os.remove(f'{d}/{f}')
    im.save(f'{d}/{n}.jpg', quality=86, optimize=True)
    json.dump({"images":[{"idiom":"universal","filename":f"{n}.jpg"}],"info":{"author":"xcode","version":1}}, open(f'{d}/Contents.json','w'), indent=2)
    print(n, os.path.getsize(f'{d}/{n}.jpg'))

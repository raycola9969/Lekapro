from pathlib import Path
import json
from PIL import Image, ImageDraw

root = Path(__file__).resolve().parents[1]
folder = root / 'Lekapro/Assets.xcassets/AppIcon.appiconset'
folder.mkdir(parents=True, exist_ok=True)
image = Image.new('RGB', (1024, 1024), '#10222a')
draw = ImageDraw.Draw(image)
draw.rounded_rectangle((174, 194, 758, 778), radius=115, fill='#174250')
draw.rounded_rectangle((224, 244, 808, 828), radius=115, fill='#246374')
draw.rounded_rectangle((274, 294, 858, 878), radius=115, fill='#63e5c2')
draw.line([(444, 426), (444, 708), (694, 708)], fill='#10222a', width=68, joint='curve')
image.save(folder / 'AppIcon.png')
(folder / 'Contents.json').write_text(json.dumps({'images': [{'filename': 'AppIcon.png', 'idiom': 'universal', 'platform': 'ios', 'size': '1024x1024'}], 'info': {'author': 'xcode', 'version': 1}}, indent=2))
(folder.parent / 'Contents.json').write_text(json.dumps({'info': {'author': 'xcode', 'version': 1}}, indent=2))
print('Generated app icon')

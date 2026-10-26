# -*- coding: utf-8 -*-
"""
物件插畫庫：emoji → 扁平繪本風插畫（同 gen_art.py 的 STYLE），全 App 共用。
第 2 批＝扭蛋玩具、成就獎盃、使用者頭像；第 3 批題目物件之後往 ITEMS 追加即可。

產出：
  assets/images/items/<key>.webp       白底原圖（之後跑 tool/cutout.py 去背）
  lib/content/emoji_art_map.dart        emoji → asset 對照（EmojiArt 元件用）
  docs/style_proposal/items.html        審圖頁
🐧 一律對應吉祥物企企（assets/images/mascot/wave.webp），不另畫。

用法：python tool/gen_items.py [--force]
"""
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_mascot as gm  # noqa: E402
import gen_style_samples as gs  # noqa: E402

OUT = os.path.join(gs.ROOT, "assets", "images", "items")
DART = os.path.join(gs.ROOT, "lib", "content", "emoji_art_map.dart")
STYLE = gm.STYLE
WHITE = ("single subject, centered, filling most of the frame, isolated on a plain pure "
         "white background")
MASCOT_EMOJI = {"🐧": "assets/images/mascot/wave.webp"}
VS16 = "️"  # 變體選擇字元；對照表 key 一律去掉，EmojiArt 查表時也去掉

# (emoji, key, 分組, 題材)
ITEMS = [
    # ---- 扭蛋：普通 ----
    ("🚗", "car", "玩具", "A cute red toy car with a happy face"),
    ("🚌", "bus", "玩具", "A cute yellow school bus seen from the side, long body with a row of passenger windows and two big wheels"),
    ("🚓", "police_car", "玩具", "A cute police car with a siren light on top"),
    ("🚒", "fire_truck", "玩具", "A cute red fire truck with a ladder"),
    ("🚜", "tractor", "玩具", "A cute green farm tractor with big back wheels"),
    ("⛵", "sailboat", "玩具", "A cute little sailboat with a white sail on a small wave"),
    ("🐶", "dog", "玩具", "A cute puppy sitting and wagging its tail"),
    ("🐱", "cat", "玩具", "A cute grey and white kitten sitting, no stripes"),
    ("🐰", "rabbit", "玩具", "A cute white bunny with long ears"),
    ("🐸", "frog", "玩具", "A cute green frog sitting"),
    ("🐢", "turtle", "玩具", "A cute turtle with a patterned green shell"),
    ("⚽", "soccer_ball", "玩具", "A classic black and white soccer ball"),
    ("🪀", "yoyo", "玩具", "A classic round red and blue toy yo-yo seen from the side, hanging from a short string with a finger loop at the top"),
    ("🪁", "kite", "玩具", "A colorful diamond-shaped kite with a ribbon tail"),
    ("🧸", "teddy_bear", "玩具", "A cute brown teddy bear with a bow tie"),
    ("🎈", "balloon", "玩具", "A shiny red balloon with a curly string"),
    ("🎀", "ribbon", "玩具", "A big pink ribbon bow"),
    ("🐮", "cow", "玩具", "A cute black and white dairy cow"),
    ("🐷", "pig", "玩具", "A cute pink piglet"),
    ("🐔", "chicken", "玩具", "A cute white hen with a red comb"),
    ("🐵", "monkey", "玩具", "A cute little brown monkey"),
    ("🐠", "tropical_fish", "玩具", "A cute colorful striped tropical fish"),
    ("🐝", "bee", "玩具", "A cute round honey bee with little wings"),
    ("🐞", "ladybug", "玩具", "A cute red ladybug with black spots"),
    ("🦆", "duck", "玩具", "A cute yellow duck"),
    ("🐴", "horse", "玩具", "A cute brown pony"),
    ("🐑", "sheep", "玩具", "A cute fluffy white sheep"),
    ("🍎", "apple", "玩具", "A shiny red apple with a green leaf"),
    ("🍌", "banana", "玩具", "A ripe yellow banana"),
    ("🍓", "strawberry", "玩具", "A juicy red strawberry"),
    ("🍇", "grapes", "玩具", "A bunch of purple grapes"),
    ("🍉", "watermelon", "玩具", "A slice of red watermelon with seeds"),
    ("🍪", "cookie", "玩具", "A round chocolate chip cookie"),
    ("🍩", "donut", "玩具", "A pink frosted donut with sprinkles"),
    ("🌈", "rainbow", "玩具", "A bright rainbow arc with two fluffy clouds at its ends"),
    ("🌟", "glowing_star", "玩具", "A glowing golden star with sparkles around it"),
    ("🍄", "mushroom", "玩具", "A cute red mushroom with white spots"),
    # ---- 扭蛋：稀有 ----
    ("🚀", "rocket", "玩具", "A cute red and white rocket with a flame"),
    ("🚁", "helicopter", "玩具", "A cute blue helicopter"),
    ("🦊", "fox", "玩具", "A cute orange fox with a fluffy tail"),
    ("🐬", "dolphin", "玩具", "A cute blue dolphin jumping"),
    ("🦋", "butterfly", "玩具", "A colorful butterfly with patterned wings"),
    ("🦒", "giraffe", "玩具", "A cute giraffe with a long neck"),
    ("🐘", "elephant", "玩具", "A cute grey baby elephant"),
    ("🎠", "carousel", "玩具", "A colorful merry-go-round carousel"),
    ("🎡", "ferris_wheel", "玩具", "A colorful ferris wheel"),
    ("🦜", "parrot", "玩具", "A cute colorful parrot"),
    ("🦩", "flamingo", "玩具", "A cute pink flamingo standing on one leg"),
    ("🦚", "peacock", "玩具", "A cute peacock with its tail feathers fanned out"),
    ("🦛", "hippo", "玩具", "A cute purple-grey hippo"),
    ("🐊", "crocodile", "玩具", "A cute friendly green crocodile"),
    ("🦓", "zebra", "玩具", "A cute zebra with black and white stripes"),
    ("🦏", "rhino", "玩具", "A cute grey rhinoceros"),
    ("🎢", "roller_coaster", "玩具", "An amusement park roller coaster: a colorful track with hills and one loop, and a small red cart with riders' raised arms on the track"),
    ("🎸", "guitar", "玩具", "A cute red acoustic guitar"),
    # ---- 扭蛋：傳說 ----
    ("🦄", "unicorn", "玩具", "A magical white unicorn with a rainbow mane and golden horn, sparkles around"),
    ("🐉", "dragon", "玩具", "A cute friendly Chinese-style green dragon flying, with clearly visible bat-like wings, two small golden horns and a curly tail, sparkles around"),
    ("👑", "crown", "玩具", "A shiny golden crown with colorful jewels, sparkles around"),
    ("💎", "diamond", "玩具", "A big sparkling blue diamond gem, sparkles around"),
    ("🛸", "ufo", "玩具", "A cute flying saucer UFO with a glowing dome, sparkles around"),
    ("🦕", "brachiosaurus", "玩具", "A cute long-necked green dinosaur, sparkles around"),
    ("🦖", "t_rex", "玩具", "A cute friendly T-rex dinosaur, sparkles around"),
    ("👽", "alien", "玩具", "A cute friendly little green alien, sparkles around"),
    ("🤖", "robot", "玩具", "A cute friendly toy robot with an antenna, sparkles around"),
    # ---- 頭像（扭蛋池沒有的）----
    ("🐻", "bear", "頭像", "A cute brown bear cub face and body, sitting"),
    ("🦁", "lion", "頭像", "A cute lion cub with a fluffy mane"),
    ("🐯", "tiger", "頭像", "A cute tiger cub with orange stripes"),
    ("🐼", "panda", "頭像", "A cute giant panda cub sitting"),
    # ---- 成就獎盃（扭蛋池沒有的）----
    ("🧭", "compass", "成就", "A shiny golden explorer compass"),
    ("⭐", "star", "成就", "A big plump golden star"),
    ("🔥", "fire", "成就", "A cute friendly orange flame with a happy face"),
    ("🎮", "game_controller", "成就", "A cute colorful handheld game controller"),
    ("💠", "crystal", "成就", "A cluster of three sparkly light-blue crystal gems growing upward, plain smooth facets"),
    ("🤑", "gold_coins", "成就", "A pile of shiny gold coins with sparkles"),
    ("💯", "perfect_medal", "成就", "A shiny gold medal on a red ribbon with a big star in the middle"),
    ("📅", "calendar", "成就", "A cute desk calendar with a red ring and a heart sticker"),
    ("📚", "books", "成就", "A neat stack of three colorful books"),
    # ---- 第 3 批：題目物件 ----
    ("🦔", "hedgehog", "題目", "A cute hedgehog"),
    ("🦦", "otter", "題目", "A cute otter"),
    ("🦘", "kangaroo", "題目", "A cute kangaroo"),
    ("🐙", "octopus", "題目", "A cute octopus"),
    ("🦀", "crab", "題目", "A cute crab"),
    ("🦉", "owl", "題目", "A cute owl"),
    ("🦥", "sloth", "題目", "A cute sloth"),
    ("🚂", "steam_locomotive", "題目", "A cute steam locomotive"),
    ("🛵", "motor_scooter", "題目", "A cute motor scooter"),
    ("🚑", "ambulance", "題目", "A cute ambulance"),
    ("🚲", "bicycle", "題目", "A cute bicycle"),
    ("🌋", "volcano", "題目", "A volcano with a little smoke"),
    ("🏔", "snowy_mountain", "題目", "A single tall triangular mountain with a white snowy cap on its peak and grey-blue slopes"),
    ("🌊", "wave", "題目", "A big blue ocean wave"),
    ("🏝", "island", "題目", "A small tropical island with a palm tree"),
    ("☁", "cloud", "題目", "A single fluffy white cloud"),
    ("⛄", "snowman", "題目", "A cute snowman with a carrot nose and scarf"),
    ("🌵", "cactus", "題目", "A cute cactus"),
    ("🍕", "slice_of_pizza", "題目", "A cute slice of pizza"),
    ("🍜", "noodle_bowl", "題目", "A steaming bowl of noodle soup with chopsticks"),
    ("🍣", "sushi", "題目", "A cute sushi"),
    ("🥗", "green_salad", "題目", "A cute green salad"),
    ("🥪", "sandwich", "題目", "A cute sandwich"),
    ("🍍", "pineapple", "題目", "A cute pineapple"),
    ("🔭", "telescope", "題目", "A telescope on a tripod"),
    ("🎻", "violin", "題目", "A cute violin"),
    ("📷", "camera", "題目", "A camera"),
    ("🔑", "key", "題目", "A golden key"),
    ("🎁", "present", "題目", "A wrapped gift box with a ribbon bow"),
    ("🍊", "tangerine", "題目", "A cute tangerine"),
    ("🍑", "peach", "題目", "A cute peach"),
    ("🍒", "cherries", "題目", "A cute cherries"),
    ("🥝", "kiwifruit", "題目", "A cute kiwifruit"),
    ("✈", "airplane", "題目", "A cute airplane"),
    ("🥁", "drum_with_drumsticks", "題目", "A cute drum with drumsticks"),
    ("🎹", "piano_keyboard", "題目", "A small piano keyboard"),
    ("🎺", "trumpet", "題目", "A cute trumpet"),
    ("🪗", "accordion", "題目", "A cute accordion"),
    ("🪘", "long_drum", "題目", "A tall hand drum (conga)"),
    ("🪈", "flute", "題目", "A wooden recorder flute"),
    ("👕", "t_shirt", "題目", "A cute t-shirt"),
    ("👖", "jeans", "題目", "A cute jeans"),
    ("🧦", "socks", "題目", "A cute socks"),
    ("🧢", "billed_cap", "題目", "A cute billed cap"),
    ("👗", "dress", "題目", "A cute dress"),
    ("🧥", "coat", "題目", "A cute coat"),
    ("🧤", "gloves", "題目", "A cute gloves"),
    ("👟", "athletic_shoe", "題目", "A cute athletic shoe"),
    ("🩳", "shorts", "題目", "A cute shorts"),
    ("🧣", "scarf", "題目", "A cute scarf"),
    ("😀", "grinning_face", "題目", "A round yellow face with a wide grin showing teeth and open round eyes"),
    ("😢", "crying_face", "題目", "A round yellow sad face with one single blue tear drop on its cheek"),
    ("☀", "sun", "題目", "A bright smiling sun with rays"),
    ("🌙", "crescent_moon", "題目", "A plain yellow crescent moon without a face"),
    ("🐇", "hare", "題目", "A brown wild hare running, side view, long legs stretched"),
    ("❄", "snowflake", "題目", "A white-blue snowflake"),
    ("👍", "thumbs_up", "題目", "A single hand giving a thumbs up"),
    ("👎", "thumbs_down", "題目", "A single hand giving a thumbs down"),
    ("🐭", "mouse", "題目", "A cute grey mouse"),
    ("👶", "baby", "題目", "A cute baby in a diaper sitting"),
    ("👴", "grandpa", "題目", "A kind smiling grandpa with white hair and glasses"),
    ("🏃", "running_child", "題目", "A child running fast, side view"),
    ("🧍", "standing_child", "題目", "A child standing still upright, front view, arms at the sides"),
    ("🏜", "desert", "題目", "A sandy desert with dunes"),
    ("🪨", "rock", "題目", "A grey rock"),
    ("⛰", "mountain", "題目", "A single triangular green and brown mountain with no snow, a few small trees at its base"),
    ("💧", "water_drop", "題目", "A single blue water drop"),
    ("🌳", "tree", "題目", "A round green tree"),
    ("🌸", "cherry_blossom", "題目", "A pink cherry blossom flower"),
    ("🐟", "fish", "題目", "A simple blue fish"),
    ("🐦", "bird", "題目", "A cute small blue bird"),
    ("🌧", "rain_cloud", "題目", "A grey cloud with rain drops falling"),
    ("🚪", "door", "題目", "A wooden door"),
    ("✋", "raised_hand", "題目", "A single open hand raised with palm facing forward"),
    ("☂", "umbrella", "題目", "A closed red umbrella standing upright, no rain"),
    ("🏫", "school", "題目", "A school building with a clock"),
    ("🍽", "plate_and_cutlery", "題目", "An empty round plate with a fork on the left and a knife on the right"),
    ("🍚", "rice_bowl", "題目", "A bowl of white rice"),
    ("🔪", "kitchen_knife", "題目", "A kitchen knife"),
    ("🍲", "stew_pot", "題目", "A pot of hot stew"),
    ("👦", "boy", "題目", "A cheerful little boy"),
    ("🏠", "house", "題目", "A small house with a red roof"),
    ("📄", "paper", "題目", "A single sheet of white paper with lines"),
    ("🪟", "window", "題目", "A window with curtains"),
    ("🥬", "leafy_greens", "題目", "A bunch of leafy green vegetables"),
    ("🥤", "cup_with_straw", "題目", "A paper cup with a straw"),
    ("👵", "grandma", "題目", "A kind smiling grandma with grey hair in a bun and glasses"),
    ("💡", "light_bulb", "題目", "A glowing light bulb"),
    ("🧺", "laundry_basket", "題目", "A wicker basket"),
    ("😭", "sobbing_face", "題目", "A round yellow face wailing loudly with mouth wide open and two streams of tears pouring down"),
    ("📦", "package", "題目", "A plain brown cardboard shipping box taped shut with packing tape, no ribbon, no bow"),
    ("🍖", "meat_on_bone", "題目", "A piece of meat on a bone"),
    ("👄", "mouth", "題目", "A pair of smiling pink lips"),
    ("🌿", "herb", "題目", "A green herb sprig"),
    ("👃", "nose", "題目", "A cute cartoon nose"),
    ("🎩", "top_hat", "題目", "A black top hat"),
    ("🏞", "park_landscape", "題目", "A green park landscape with a lake, trees and mountains"),
    ("🌉", "bridge", "題目", "A big bridge over a river"),
    ("🐺", "wolf", "題目", "A cute grey wolf"),
    ("👔", "necktie", "題目", "A shirt collar with a necktie"),
    ("🎽", "running_shirt", "題目", "A sleeveless running shirt with a sash"),
    ("✏", "pencil", "題目", "A yellow pencil"),
    ("✂", "scissors", "題目", "A pair of scissors"),
    ("📏", "ruler", "題目", "A straight ruler"),
    ("🖊", "pen", "題目", "A ballpoint pen"),
    ("📐", "set_square", "題目", "A triangle ruler"),
    ("🖍", "crayon", "題目", "A crayon"),
    ("📎", "paperclip", "題目", "A paperclip"),
    ("🍳", "fried_egg_pan", "題目", "A frying pan with a sunny-side-up egg"),
    ("🥄", "spoon", "題目", "A cute spoon"),
    ("🍴", "fork_and_knife", "題目", "A fork and a knife crossed, no plate"),
    ("🥢", "chopsticks", "題目", "A cute chopsticks"),
    ("🥣", "cereal_bowl", "題目", "A bowl of cereal with a spoon"),
    ("🍶", "bottle_and_cup", "題目", "A small white ceramic bottle and a little cup"),
    ("🫕", "fondue", "題目", "A small pot of melted cheese fondue with a bread cube on a fork"),
    ("🏀", "basketball", "題目", "An orange basketball"),
    ("🎾", "tennis", "題目", "A tennis racket and a tennis ball"),
    ("🏐", "volleyball", "題目", "A volleyball"),
    ("⚾", "baseball", "題目", "A baseball"),
    ("🏈", "american_football", "題目", "An american football"),
    ("🏓", "ping_pong", "題目", "A ping pong paddle and ball"),
    ("🥎", "softball", "題目", "A yellow softball"),
    ("⛈", "storm_cloud", "題目", "A dark grey cloud with a lightning bolt and rain"),
    ("🌪", "tornado", "題目", "A swirling grey tornado"),
    ("🥕", "carrot", "題目", "A cute carrot"),
    ("🌽", "ear_of_maize", "題目", "A cute ear of maize"),
    ("🍞", "bread", "題目", "A cute bread"),
    ("🍰", "cake_slice", "題目", "A slice of strawberry shortcake"),
    ("🍦", "ice_cream", "題目", "A soft-serve ice cream cone"),
    ("🥛", "milk", "題目", "A glass of milk"),
    ("🥚", "egg", "題目", "A cute egg"),
    ("🍬", "candy", "題目", "A wrapped candy"),
    ("🐓", "rooster", "題目", "A colorful rooster"),
    ("🐐", "goat", "題目", "A cute goat"),
    ("🦗", "cricket", "題目", "A green cricket insect"),
    ("🐋", "whale", "題目", "A cute whale"),
    ("🪥", "toothbrush", "題目", "A toothbrush with toothpaste"),
    ("🧼", "soap", "題目", "A bar of soap with bubbles"),
    ("🦴", "bone", "題目", "A white dog bone"),
    ("🤱", "mother_and_baby", "題目", "A mother lovingly holding a baby in her arms"),
    ("🧱", "bricks", "題目", "A small stack of red bricks"),
    ("🧃", "juice_box", "題目", "A juice box with a straw"),
    ("📰", "newspaper", "題目", "A folded newspaper"),
    ("🌷", "tulip", "題目", "A red tulip"),
    ("🧹", "broom", "題目", "A broom"),
    ("😴", "sleeping_face", "題目", "A round yellow face sleeping with closed eyes"),
    ("🎨", "paint_palette", "題目", "An artist paint palette with colorful paints and a brush"),
    ("📖", "open_book", "題目", "An open book"),
    ("🎤", "microphone", "題目", "A microphone"),
    ("💃", "dancing_girl", "題目", "A little girl dancing happily in a twirling dress"),
    ("🤝", "handshake", "題目", "Two hands shaking hands"),
    ("🛁", "bathtub", "題目", "A bathtub with bubbles"),
    ("💗", "pink_heart", "題目", "A glowing pink heart with small sparkles"),
    ("🚶", "walking_child", "題目", "A child walking slowly, side view"),
    ("⛅", "sun_behind_cloud", "題目", "A sun peeking out from behind a white cloud"),
    ("👩‍🏫", "teacher", "題目", "A friendly female teacher standing in front of a small chalkboard"),
    ("🚸", "children_crossing", "題目", "Two children holding hands walking across a zebra crosswalk"),
    ("✍", "writing_hand", "題目", "A hand holding a pencil writing on a sheet of paper"),
    ("🌱", "seedling", "題目", "A small green seedling sprouting from soil"),
    ("🙋", "child_raising_hand", "題目", "A child happily raising one hand high"),
    ("🌛", "moon_with_face", "題目", "A yellow crescent moon with a sleepy smiling face"),
    ("🤸", "cartwheel_child", "題目", "A child doing a cartwheel"),
    ("🚦", "traffic_light", "題目", "A vertical traffic light with red, yellow and green lights"),
    ("🙏", "folded_hands", "題目", "Two hands pressed together palm to palm saying please or thank you"),
    ("😊", "smiling_face", "題目", "A round yellow face with a gentle closed-mouth smile, curved smiling eyes and pink blushing cheeks"),
    ("🛏", "bed", "題目", "A cozy bed with a pillow and blanket"),
    ("☔", "umbrella_in_rain", "題目", "An open blue umbrella with rain drops falling on it"),
    ("🥦", "broccoli", "題目", "A cute broccoli"),
    ("🌅", "sunrise", "題目", "The sun rising over the sea"),
    ("👨‍👩‍👧", "family", "題目", "A happy family of a dad, a mom and a little girl"),
    ("🤗", "hugging_face", "題目", "A round yellow smiling face with two open hands reaching out for a hug"),
    ("🗑", "trash_can", "題目", "A grey trash can"),
    ("😮‍💨", "relief_face", "題目", "A round yellow face blowing out a big puff of air in relief, a small white puff cloud at its mouth"),
    ("🙇", "bowing_child", "題目", "A child bowing politely"),
    ("👩‍⚕", "doctor", "題目", "A friendly female doctor in a white coat with a stethoscope"),
    ("😄", "laughing_face", "題目", "A round yellow face laughing with eyes squeezed shut into happy arcs and a big open mouth"),
    ("🚽", "toilet", "題目", "A white toilet"),
    ("🐥", "baby_chick", "題目", "A cute fluffy yellow baby chick, front view"),
    ("🌻", "sunflower", "題目", "A sunflower"),
    ("🔔", "bell", "題目", "A golden bell"),
    ("🪇", "maracas", "題目", "A pair of colorful maracas"),
    ("🎵", "music_note", "題目", "A single musical note"),
    ("🙉", "monkey_covering_ears", "題目", "A cute monkey covering its ears with its hands"),
    ("🏰", "castle", "題目", "A fairy tale castle"),
    ("🧀", "cheese", "題目", "A wedge of yellow cheese with holes"),
]


def write_dart():
    # 只收實際存在的圖：生圖中斷或待重生時，缺圖的 emoji 由 EmojiArt 退回顯示字元。
    lines = [f"  '{e.replace(VS16, '')}': 'assets/images/items/{k}.webp',"
             for e, k, _, _ in ITEMS
             if os.path.exists(os.path.join(OUT, k + ".webp"))]
    lines += [f"  '{e}': '{p}'," for e, p in MASCOT_EMOJI.items()]
    body = "\n".join(lines)
    dart = f"""// 由 tool/gen_items.py 產生，勿手改；新增物件請改 ITEMS 再重跑。
/// emoji → 扁平繪本風插畫（去背 webp）。沒有對應圖的 emoji 由 EmojiArt 退回顯示字元。
library;

const Map<String, String> kEmojiArt = <String, String>{{
{body}
}};
"""
    with open(DART, "w", encoding="utf-8") as f:
        f.write(dart)


def write_html():
    groups = {}
    for e, k, g, _ in ITEMS:
        groups.setdefault(g, []).append((e, k))
    sections = []
    for g, items in groups.items():
        cells = "".join(
            f'<figure><img src="../../assets/images/items/{k}.webp" alt="{e}">'
            f'<figcaption>{e} {k}</figcaption></figure>' for e, k in items)
        sections.append(f'<section><h2>{g}（{len(items)}）</h2><div class="grid">{cells}</div></section>')
    html = f"""<!doctype html>
<html lang="zh-Hant"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>物件插畫</title>
<style>
:root{{--bg:#fbf8f3;--fg:#2b2b2b;--muted:#6b6b6b;--card:#fff;--line:#e8e2d8}}
@media (prefers-color-scheme:dark){{:root{{--bg:#1d1c1a;--fg:#eee;--muted:#aaa;--card:#2a2926;--line:#3a3833}}}}
body{{margin:0;background:var(--bg);color:var(--fg);font-family:system-ui,"Noto Sans TC",sans-serif}}
main{{max-width:1100px;margin:0 auto;padding:24px 16px 64px}}
h1{{margin:0 0 4px}} .sub{{color:var(--muted);margin:0 0 24px}}
section{{background:var(--card);border:1px solid var(--line);border-radius:16px;padding:20px;margin-bottom:20px}}
h2{{margin:0 0 14px}}
.grid{{display:grid;grid-template-columns:repeat(auto-fill,minmax(120px,1fr));gap:12px}}
figure{{margin:0;text-align:center}} figure img{{width:100%;height:auto;border-radius:12px;background:#fff}}
figcaption{{font-size:13px;color:var(--muted);margin-top:6px}}
</style></head><body><main>
<h1>物件插畫（第 2 批：玩具／頭像／成就）</h1>
<p class="sub">🐧 一律用企企本人，不在此列。</p>
{''.join(sections)}
</main></body></html>"""
    with open(os.path.join(gs.OUT, "items.html"), "w", encoding="utf-8") as f:
        f.write(html)


def main():
    if not gs.KEY:
        sys.exit("tool/secrets.env 沒有 GEMINI_API_KEY")
    keys = [k for _, k, _, _ in ITEMS]
    emojis = [e for e, _, _, _ in ITEMS]
    assert len(set(keys)) == len(keys) and len(set(emojis)) == len(emojis), "key/emoji 重複"
    os.makedirs(OUT, exist_ok=True)
    fail = []
    for _, key, _, subj in ITEMS:
        final = os.path.join(OUT, key + ".webp")
        if os.path.exists(final) and not gs.FORCE:
            continue
        print("gen", key, "...", flush=True)
        data = gs.gen_one(f"{subj}, {WHITE}. {STYLE} {gs.NO_TEXT}")
        if not data:
            print("  FAILED", key)
            fail.append(key)
            continue
        gs.save(data, final, "tile")
        time.sleep(2)  # 緩一下，降低限流
    write_dart()
    write_html()
    print(f"完成，失敗 {len(fail)} {fail}")


if __name__ == "__main__":
    main()

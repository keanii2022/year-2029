"""Builds gallery.html: every item's preview, shrunk with macOS sips and embedded, so the file works on its own anywhere.
Run from art: python3 _kit/gallery.py"""
import base64, glob, os, subprocess, tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GROUPS = [("robots", "Robots"), ("haunt", "Haunts"), ("critters", "Critters"), ("dog", "Dog"), ("story", "Story spots"), ("gear", "Guns and gear"), ("fun", "Fun props"), ("food", "Food"), ("furniture", "Furniture"), ("lab", "Lab pieces"), ("warehouse", "Warehouse kit"), ("viewmodel", "First-person hands")]

tmp = tempfile.mkdtemp()
sections = []
for folder, title in GROUPS:
    cards = []
    for png in sorted(glob.glob(os.path.join(ROOT, folder, "*", "preview.png"))):
        name = os.path.basename(os.path.dirname(png))
        small = os.path.join(tmp, f"{folder}_{name}.jpg")
        subprocess.run(["sips", "-Z", "360", "-s", "format", "jpeg", "-s", "formatOptions", "70", png, "--out", small],
                       check=True, capture_output=True)
        data = base64.b64encode(open(small, "rb").read()).decode()
        cards.append(f'<figure><img src="data:image/jpeg;base64,{data}" alt="{name}"><figcaption>{name.replace("_", " ")}</figcaption></figure>')
    if cards:
        sections.append(f"<h2>{title} <span>{len(cards)}</span></h2><div class=grid>{''.join(cards)}</div>")

for title, pattern in (("Robots at night (what's chasing you)", "robots/*_night/night.png"), ("Posters", "posters/*.png"),
                       ("TV channels and screens", "posters/screens/*.png")):
    cards = []
    for png in sorted(glob.glob(os.path.join(ROOT, pattern))):
        name = os.path.splitext(os.path.basename(png))[0]
        if name == "night":
            name = os.path.basename(os.path.dirname(png))
        small = os.path.join(tmp, f"poster_{name}.jpg")
        subprocess.run(["sips", "-Z", "420", "-s", "format", "jpeg", "-s", "formatOptions", "70", png, "--out", small], check=True, capture_output=True)
        data = base64.b64encode(open(small, "rb").read()).decode()
        cards.append(f'<figure><img class=flat src="data:image/jpeg;base64,{data}" alt="{name}"><figcaption>{name.replace("_", " ")}</figcaption></figure>')
    if cards:
        sections.append(f"<h2>{title} <span>{len(cards)}</span></h2><div class=grid>{''.join(cards)}</div>")

html = f"""<!doctype html><html><head><meta charset=utf-8><meta name=viewport content="width=device-width,initial-scale=1">
<title>Year 2029 Models</title><style>
:root{{--bg:#16171a;--card:#212328;--text:#e9e7e1;--dim:#8d9096}}
body{{margin:0;padding:16px;background:var(--bg);color:var(--text);font:15px system-ui,sans-serif}}
h1{{font-size:22px;margin:4px 0 4px}} p{{color:var(--dim);margin:0 0 8px}}
h2{{font-size:17px;margin:28px 0 10px}} h2 span{{color:var(--dim);font-weight:400}}
.grid{{display:grid;grid-template-columns:repeat(auto-fill,minmax(150px,1fr));gap:10px}}
figure{{margin:0;background:var(--card);border-radius:10px;overflow:hidden}}
img{{width:100%;display:block;aspect-ratio:1;object-fit:cover}} img.flat{{aspect-ratio:auto;object-fit:contain}}
figcaption{{padding:6px 8px;font-size:13px;text-transform:capitalize}}
</style></head><body><h1>Year 2029 models</h1><p>Blender asset run, work in progress.</p>{''.join(sections)}</body></html>"""
open(os.path.join(ROOT, "gallery.html"), "w").write(html)
vids = sorted(glob.glob(os.path.join(ROOT, "*", "*", "anim", "preview.mp4")))
cards = "".join(f'<figure><video src="{os.path.relpath(v, ROOT)}" controls loop muted playsinline preload=metadata></video><figcaption>{v.split(os.sep)[-3].replace("_", " ")}</figcaption></figure>' for v in vids)
open(os.path.join(ROOT, "animations.html"), "w").write(html.split("<h1>")[0].replace("Year 2029 Models", "Year 2029 Animations").replace("img{{", "video{{").replace("img{", "video{width:100%;display:block}img{")
    + f"<h1>Year 2029 animations</h1><p>Each video plays every clip in a row. Keep this file next to the model folders.</p><div class=grid style=grid-template-columns:repeat(auto-fill,minmax(260px,1fr))>{cards}</div></body></html>")
print("wrote animations.html with", len(vids), "videos")
print("wrote gallery.html", os.path.getsize(os.path.join(ROOT, "gallery.html")) // 1024, "KB")

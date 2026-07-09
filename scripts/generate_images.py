"""
Peru Eterno - AI Image Generator via Pollinations.ai (free, no API key needed)
Generates 35 watercolor-style illustrations for all 7 historical eras.
"""

import urllib.request
import urllib.parse
import time
import os
import sys

BASE_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "images")

ERAS = {
    "caral": [
        "Aerial view of ancient Caral city pyramids in Supe Valley Peru desert 3000 BC, monumental stepped pyramids at golden hour, dry river valley, watercolor illustration style, warm ochre amber palette, parchment texture, painterly edges, epic scale, no people",
        "Ancient circular amphitheater of Caral civilization Peru, stone terraces, sacred ceremonial space, Andean mountains background, watercolor art style, terracotta sand colors, soft ink outlines, golden hour light, mystical atmosphere",
        "Close-up of adobe brick pyramid wall at Caral archaeological site Peru, ancient stone construction, desert erosion, warm sand tones, watercolor painting style, parchment background, dramatic side lighting, archaeological atmosphere",
        "Ancient Caral people playing bone flutes in ceremonial dress, stylized figures, Peruvian watercolor illustration, warm golden tones, ritual music scene, desert background, parchment texture, elegant symbolic art",
        "Ancient Caral trading market scene, stylized figures exchanging dried fish and cotton textiles, desert oasis setting, Peruvian watercolor painting, warm earthy palette, soft dreamlike illustration, parchment texture",
    ],
    "moche": [
        "Massive Huaca del Sol pyramid northern coast Peru, terracotta red adobe bricks, dramatic desert sky, Pacific Ocean in distance, watercolor illustration, deep terracotta burnt sienna palette, parchment texture, epic cinematic scale, warm sunset",
        "Portrait of Lord of Sipan Moche ruler, magnificent gold headdress, turquoise gold jewelry, ceremonial regalia, dignified expression, Peruvian watercolor illustration, warm terracotta gold palette, parchment texture, regal composition",
        "Moche gold silver ceremonial objects, intricate deity masks, ear ornaments arranged on dark fabric, Peruvian watercolor painting, warm metallic gold terracotta palette, soft glow, artistic museum illustration, parchment background",
        "Collection of iconic Moche portrait ceramics, human faces different expressions, terracotta clay, arranged artistically, Peruvian watercolor illustration, earthy warm tones, soft painterly rendering, archaeological aesthetic",
        "Ancient Moche irrigation canals cutting through coastal desert, green agriculture patches in dry landscape, geometric field patterns, aerial view, watercolor style, contrast terracotta desert and green fields, warm midday light",
    ],
    "tiahuanaco": [
        "Gateway of the Sun at Tiwanaku Bolivia, monolithic stone arch carved with Viracocha deity, dramatic Andean sky, Lake Titicaca distance, watercolor illustration, cool blue grey palette with golden accents, misty high altitude atmosphere, mystical",
        "Lake Titicaca at sunset with reed totora boats, high altitude Andean landscape, snow-capped mountains reflected in deep blue water, ancient stone ruins silhouette, watercolor illustration, blue and amber palette, soft romantic light, dreamy",
        "Ancient Tiwanaku city layout from above, megalithic stone structures, rectangular plazas, sunken temple, vast Altiplano plateau, Lake Titicaca visible, watercolor aerial illustration, cool blue-grey palette, crisp high altitude light",
        "Enormous andesite stone blocks of Puma Punku Tiwanaku Bolivia, perfectly carved geometric shapes, scattered on ancient site, mysterious awe-inspiring, watercolor style, grey stone tones with blue sky, dramatic perspective, archaeological",
        "Close-up carved stone figure at Tiwanaku, ancient deity ruler, intricate bas-relief, grey andesite stone, watercolor illustration, cool grey blue palette, dramatic side lighting revealing carving details, mystical atmosphere",
    ],
    "inca": [
        "Machu Picchu Inca citadel, dramatic mountain peak shrouded morning mist, perfectly cut stone terraces, green mountains, dramatic clouds, Peruvian watercolor illustration, rich emerald green stone grey palette gold accents, mystical fog, epic scale",
        "Sapa Inca emperor seated on golden throne, magnificent feathered headdress, golden sun disc, imperial court attendants, mountain palace setting, watercolor illustration, rich gold deep purple palette, majestic ceremonial atmosphere",
        "Ancient Inca road Qhapaq Nan winding through dramatic Andean landscape, stone-paved path, llama caravans, steep mountains, waterfalls, cloud forest, watercolor illustration, lush green and stone grey palette, epic mountain scenery",
        "Inti Raymi Inca sun festival at Sacsayhuaman, large plaza, costumed priests dancers celebrating, fire golden sun symbols, Inca stone fortress background, watercolor illustration, golden red ceremonial palette, festive dynamic composition",
        "Inca agricultural terraces at Pisac, circular stepped stone terraces on mountain slopes, green crops, dramatic Andean sky, watercolor style, green and warm earth tones, geometric patterns of agriculture, aerial perspective, Peru",
    ],
    "conquista": [
        "Historic encounter at Cajamarca 1532, Inca Atahualpa surrounded by nobles meeting Spanish conquistadors, clash of two worlds, elaborate Inca costumes versus Spanish armor, tense atmosphere, watercolor illustration, dark dramatic palette gold crimson accents",
        "Spanish galleons arriving on Peruvian coast, dramatic ocean waves, imposing dark ships with sails, indigenous Peruvians watching from shore, watercolor illustration, dramatic dark sea grey sky, tension and historical weight",
        "Portrait of Francisco Pizarro Spanish conquistador, armor and helmet, stern expression, Peru mountains behind, watercolor illustration, dark dramatic tones, historical gravitas, parchment texture background, conquistador aesthetic",
        "Inca emperor Atahualpa as captive, gold ransom room scene, golden objects brought in by Inca nobles, Spanish soldiers watching, dramatic chiaroscuro lighting, watercolor illustration, warm gold against dark shadows, emotional historical moment",
        "Francisco Pizarro founding city of Lima 1535, ceremonial act with Spanish flag, indigenous people watching, colonial architecture rising, Pacific coast, watercolor illustration, warm colonial tones, historical documentary aesthetic",
    ],
    "virreinato": [
        "Colonial Lima Plaza Mayor 18th century, grand baroque cathedral, government palace, fountain, people in period costumes, horses and carriages, watercolor illustration, warm gold white colonial palette, atmospheric afternoon light, historical grandeur",
        "Cerro Rico mountain Potosi at night, silver mines lit by torches, indigenous miners carrying loads, dramatic mountain landscape, colonial era, watercolor illustration, dark palette with silver torch-light accents, gritty historical realism",
        "Opulent interior Lima Viceroy Palace, baroque architecture, painted ceilings, colonial art, aristocrats in elaborate costumes, watercolor illustration, rich warm gold deep red palette, colonial baroque splendor",
        "Tupac Amaru II leading indigenous revolt, dramatic mountain setting, banner with sun symbol, crowd of followers, historical resistance, watercolor illustration, dramatic red and earth tones, revolutionary energy, emotional historical scene",
        "Bustling colonial Lima market, cultural fusion scene, mestizo traders, indigenous textiles, Spanish goods, African influences, colorful chaos, watercolor illustration, warm vibrant palette, multicultural energy, baroque Lima buildings background",
    ],
    "independencia": [
        "General Jose de San Martin proclaiming Peru independence July 28 1821 Lima Plaza Mayor, dramatic dawn light, crowd cheering, red and white Peruvian flag raised, watercolor illustration, patriotic red white gold palette, triumphant emotional atmosphere",
        "Portrait of General Jose de San Martin liberator of Peru, military uniform, dignified noble expression, Andes mountains behind, watercolor illustration, warm heroic palette, patriotic atmosphere, parchment texture background",
        "Battle of Ayacucho December 1824, dramatic Andean battlefield, cavalry charge, patriot and royalist forces, mountains and clouds, watercolor illustration, dramatic warm cool color contrast, historic decisive moment, epic military scene",
        "Simon Bolivar entering Lima in triumph, liberator on horseback, cheering crowds, colonial Lima streets, red and white Peruvian flags, watercolor illustration, warm golden triumphant palette, liberation and joy in composition",
        "Allegorical scene Peru independence, woman figure representing Peru breaking chains, Andean landscape, dawn light, new flag, indigenous and mestizo figures united, watercolor illustration, hopeful golden green palette, liberty new beginning",
    ],
}

WIDTH = 1200
HEIGHT = 800
SEED_BASE = 42


def build_url(prompt: str, index: int) -> str:
    encoded = urllib.parse.quote(prompt)
    seed = SEED_BASE + index
    return f"https://image.pollinations.ai/prompt/{encoded}?width={WIDTH}&height={HEIGHT}&seed={seed}&nologo=true&model=flux"


def download_image(url: str, dest_path: str, label: str) -> bool:
    print(f"  Descargando: {label}...", end="", flush=True)
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "PeruEterno/1.0"})
        with urllib.request.urlopen(req, timeout=120) as response:
            data = response.read()
        if len(data) < 5000:
            print(" FALLO (respuesta muy pequeña)")
            return False
        with open(dest_path, "wb") as f:
            f.write(data)
        print(f" OK ({len(data) // 1024} KB)")
        return True
    except Exception as e:
        print(f" ERROR: {e}")
        return False


def main():
    total = sum(len(prompts) for prompts in ERAS.values())
    done = 0
    failed = []
    global_idx = 0

    print(f"\nPeru Eterno — Generando {total} ilustraciones con Pollinations.ai")
    print("=" * 60)

    for era_id, prompts in ERAS.items():
        era_dir = os.path.join(BASE_DIR, era_id)
        os.makedirs(era_dir, exist_ok=True)
        print(f"\n[{era_id.upper()}]")

        for i, prompt in enumerate(prompts, start=1):
            filename = f"{era_id}_{i}.png"
            dest = os.path.join(era_dir, filename)

            if os.path.exists(dest) and os.path.getsize(dest) > 10000:
                print(f"  {filename}: ya existe, saltando")
                done += 1
                global_idx += 1
                continue

            url = build_url(prompt, global_idx)
            success = download_image(url, dest, filename)
            global_idx += 1

            if success:
                done += 1
            else:
                failed.append(f"{era_id}/{filename}")

            if i < len(prompts):
                time.sleep(2)

        time.sleep(3)

    print("\n" + "=" * 60)
    print(f"Completado: {done}/{total} imagenes descargadas")
    if failed:
        print(f"Fallidos ({len(failed)}): {', '.join(failed)}")
    else:
        print("Todas las imagenes generadas correctamente!")
    print("\nEjecuta 'flutter run' para ver las imagenes en la app.")


if __name__ == "__main__":
    main()

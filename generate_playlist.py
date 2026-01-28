"""
IPTV Playlist Generator
Executa automaticamente via GitHub Actions

URL fixa: https://raw.githubusercontent.com/tenorioabsgit/iptv/main/playlist.m3u
"""

import requests
import gzip
import json
from io import BytesIO
from datetime import datetime
from concurrent.futures import ThreadPoolExecutor, as_completed
import multiprocessing

# ============================================================
# CONFIGURACAO
# ============================================================

SOURCES = {
    # Brasil (apsattv.com)
    'samsung_br': {
        'name': 'Samsung TV Plus Brasil',
        'url': 'https://www.apsattv.com/ssungbra.m3u',
        'type': 'direct_m3u',
        'region': 'BR',
    },
    'lg_br': {
        'name': 'LG Channels Brasil',
        'url': 'https://www.apsattv.com/brlg.m3u',
        'type': 'direct_m3u',
        'region': 'BR',
    },
    'tcl_br': {
        'name': 'TCL Brasil',
        'url': 'https://www.apsattv.com/tclbr.m3u',
        'type': 'direct_m3u',
        'region': 'BR',
    },

    # EUA (apsattv.com)
    'roku_us': {
        'name': 'Roku Channel',
        'url': 'https://www.apsattv.com/rok.m3u',
        'type': 'direct_m3u',
        'region': 'US',
    },
    'firetv_us': {
        'name': 'Amazon Fire TV',
        'url': 'https://www.apsattv.com/firetv.m3u',
        'type': 'direct_m3u',
        'region': 'US',
    },

    # Samsung TV Plus (i.mjh.nz)
    'samsung_us': {'name': 'Samsung TV Plus US', 'region': 'us', 'type': 'mjh'},
    'samsung_gb': {'name': 'Samsung TV Plus UK', 'region': 'gb', 'type': 'mjh'},
    'samsung_ca': {'name': 'Samsung TV Plus CA', 'region': 'ca', 'type': 'mjh'},
}

MJH_CHANNELS_URL = 'https://i.mjh.nz/SamsungTVPlus/.channels.json.gz'
TARGET_REGIONS = ['BR', 'US', 'GB', 'CA', 'us', 'gb', 'ca']
OUTPUT_FILE = 'playlist.m3u'


# ============================================================
# FUNCOES
# ============================================================

def download_direct_m3u(url, name):
    """Baixa uma playlist M3U diretamente."""
    print(f"  Baixando {name}...")
    headers = {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'}

    try:
        response = requests.get(url, headers=headers, timeout=30)
        response.raise_for_status()
        content = response.text
        channel_count = content.count('#EXTINF')
        print(f"    OK! ({channel_count} canais)")
        return content, channel_count
    except Exception as e:
        print(f"    ERRO: {e}")
        return None, 0


def download_mjh_data():
    """Baixa dados do i.mjh.nz."""
    print("  Baixando dados Samsung TV Plus (i.mjh.nz)...")
    headers = {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'}

    try:
        response = requests.get(MJH_CHANNELS_URL, headers=headers, timeout=30)
        response.raise_for_status()
        with gzip.GzipFile(fileobj=BytesIO(response.content)) as f:
            data = json.loads(f.read().decode('utf-8'))
        print("    OK!")
        return data
    except Exception as e:
        print(f"    ERRO: {e}")
        return None


def parse_m3u_to_channels(content, source_name):
    """Converte conteudo M3U em lista de canais."""
    lines = content.split('\n')
    channels = []
    current_extinf = None

    for line in lines:
        line = line.strip()
        if line.startswith('#EXTINF'):
            current_extinf = line
        elif line.startswith('http') and current_extinf:
            name = current_extinf.split(',')[-1].strip() if ',' in current_extinf else 'Unknown'
            channels.append({
                'name': name,
                'url': line,
                'extinf': current_extinf,
                'source': source_name
            })
            current_extinf = None

    return channels


def generate_mjh_channels(data, region, source_name):
    """Gera lista de canais a partir do i.mjh.nz."""
    regions_data = data.get('regions', {})
    if region not in regions_data:
        return []

    region_info = regions_data[region]
    channels_data = region_info.get('channels', {})
    slug_template = data.get('slug', 'stvp-{id}')

    channels = []
    for channel_id, channel_info in channels_data.items():
        name = channel_info.get('name', 'Unknown')
        chno = channel_info.get('chno', 0)
        group = channel_info.get('group', 'Other')
        logo = channel_info.get('logo', '')

        slug = slug_template.replace('{id}', channel_id)
        stream_url = f"https://jmp2.uk/{slug}"

        extinf = f'#EXTINF:-1 tvg-id="{channel_id}" tvg-name="{name}" tvg-logo="{logo}" tvg-chno="{chno}" group-title="{group}",{name}'

        channels.append({
            'name': name,
            'url': stream_url,
            'extinf': extinf,
            'source': source_name
        })

    return channels


def test_channel(channel, timeout=8):
    """Testa se um canal esta funcionando."""
    url = channel['url']
    headers = {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'}

    try:
        response = requests.get(url, headers=headers, timeout=timeout, stream=True)

        if response.status_code == 200:
            first_bytes = next(response.iter_content(1024), b'')
            response.close()

            if first_bytes:
                return {**channel, 'status': 'OK'}

        return {**channel, 'status': f'HTTP_{response.status_code}'}

    except:
        return {**channel, 'status': 'ERROR'}


def test_channels_parallel(channels):
    """Testa canais em paralelo."""
    cpu_count = multiprocessing.cpu_count()
    max_workers = max(4, cpu_count - 1)

    print(f"\nTestando {len(channels)} canais com {max_workers} workers...")

    results = []
    working = 0

    with ThreadPoolExecutor(max_workers=max_workers) as executor:
        future_to_channel = {executor.submit(test_channel, ch): ch for ch in channels}

        for i, future in enumerate(as_completed(future_to_channel), 1):
            result = future.result()
            results.append(result)

            if result['status'] == 'OK':
                working += 1

            if i % 100 == 0 or i == len(channels):
                print(f"  Progresso: {i}/{len(channels)} ({working} OK)")

    return results, working


def collect_all_channels():
    """Coleta canais de todas as fontes."""
    print("\nColetando canais...")

    all_channels = []
    mjh_data = None

    needs_mjh = any(s.get('type') == 'mjh' for s in SOURCES.values())
    if needs_mjh:
        mjh_data = download_mjh_data()

    for source_key, source in SOURCES.items():
        region = source.get('region', '')
        if region not in TARGET_REGIONS:
            continue

        source_type = source.get('type')

        if source_type == 'direct_m3u':
            content, count = download_direct_m3u(source['url'], source['name'])
            if content:
                channels = parse_m3u_to_channels(content, source['name'])
                all_channels.extend(channels)

        elif source_type == 'mjh' and mjh_data:
            print(f"  Processando {source['name']}...")
            channels = generate_mjh_channels(mjh_data, region, source['name'])
            all_channels.extend(channels)
            print(f"    OK! ({len(channels)} canais)")

    print(f"\nTotal coletados: {len(all_channels)}")
    return all_channels


def generate_m3u_content(channels):
    """Gera conteudo M3U."""
    lines = ['#EXTM3U']
    lines.append(f'# Atualizado: {datetime.utcnow().strftime("%Y-%m-%d %H:%M:%S UTC")}')
    lines.append(f'# Canais: {len(channels)}')
    lines.append('')

    for ch in channels:
        lines.append(ch['extinf'])
        lines.append(ch['url'])

    return '\n'.join(lines)


# ============================================================
# MAIN
# ============================================================

def main():
    print("=" * 60)
    print("IPTV PLAYLIST GENERATOR")
    print("=" * 60)
    print(f"Data: {datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S UTC')}")

    # 1. Coletar canais
    all_channels = collect_all_channels()

    if not all_channels:
        print("Nenhum canal encontrado!")
        return

    # 2. Testar canais
    results, working = test_channels_parallel(all_channels)

    # Filtrar funcionando
    working_channels = [r for r in results if r['status'] == 'OK']

    print(f"\nResultado: {working}/{len(all_channels)} funcionando ({working*100//len(all_channels)}%)")

    # 3. Gerar playlist
    playlist_content = generate_m3u_content(working_channels)

    # 4. Salvar
    with open(OUTPUT_FILE, 'w', encoding='utf-8') as f:
        f.write(playlist_content)

    print(f"\nPlaylist salva: {OUTPUT_FILE}")
    print(f"Total de canais: {len(working_channels)}")


if __name__ == '__main__':
    main()

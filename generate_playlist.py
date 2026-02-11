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
    'soultv_br': {
        'name': 'Soul TV Brasil',
        'url': 'https://www.apsattv.com/soultv.m3u',
        'type': 'direct_m3u',
        'region': 'BR',
    },
    'redeitv_br': {
        'name': 'Rede iTV Brasil',
        'url': 'https://www.apsattv.com/redeitv.m3u',
        'type': 'direct_m3u',
        'region': 'BR',
    },
    'movieark_br': {
        'name': 'Movieark Brasil',
        'url': 'https://www.apsattv.com/moviearkbr.m3u',
        'type': 'direct_m3u',
        'region': 'BR',
    },

    # Brasil (GitHub agregadores)
    'iptv_org_br': {
        'name': 'IPTV-Org Brasil',
        'url': 'https://iptv-org.github.io/iptv/countries/br.m3u',
        'type': 'direct_m3u',
        'region': 'BR',
    },
    'freetv_br': {
        'name': 'Free-TV Brasil',
        'url': 'https://raw.githubusercontent.com/Free-TV/IPTV/master/playlists/playlist_brazil.m3u8',
        'type': 'direct_m3u',
        'region': 'BR',
    },
    'fta_br': {
        'name': 'FTA-IPTV Brasil',
        'url': 'https://raw.githubusercontent.com/joaoguidugli/FTA-IPTV-Brasil/master/playlist.m3u8',
        'type': 'direct_m3u',
        'region': 'BR',
    },

    # Brasil (Pluto TV)
    'plutotv_br': {
        'name': 'Pluto TV Brasil',
        'url': 'https://raw.githubusercontent.com/BuddyChewChew/app-m3u-generator/refs/heads/main/playlists/plutotv_br.m3u',
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

# Canais extras (VH1 e MTV) adicionados manualmente
EXTRA_CHANNELS = [
    # VH1 - Pluto TV US
    {'name': 'VH1 Classics', 'url': 'https://service-stitcher.clusters.pluto.tv/v1/stitch/embed/hls/channel/6076cd1df8576d0007c82193/master.m3u8?deviceId=channel&deviceModel=web&deviceVersion=1.0&appVersion=1.0&deviceType=web&deviceMake=web&deviceDNT=1', 'region': 'US', 'source': 'Pluto TV US'},
    {'name': 'VH1 I Love Reality', 'url': 'https://service-stitcher.clusters.pluto.tv/v1/stitch/embed/hls/channel/5d7154fa8326b6ce4ec31f2e/master.m3u8?deviceId=channel&deviceModel=web&deviceVersion=1.0&appVersion=1.0&deviceType=web&deviceMake=web&deviceDNT=1', 'region': 'US', 'source': 'Pluto TV US'},
    {'name': 'VH1 Hip Hop Family', 'url': 'https://service-stitcher.clusters.pluto.tv/v1/stitch/embed/hls/channel/5d71561df6f2e6d0b6493bf5/master.m3u8?deviceId=channel&deviceModel=web&deviceVersion=1.0&appVersion=1.0&deviceType=web&deviceMake=web&deviceDNT=1', 'region': 'US', 'source': 'Pluto TV US'},
    {'name': 'VH1 Queens of Reality', 'url': 'https://service-stitcher.clusters.pluto.tv/v1/stitch/embed/hls/channel/66abefe5d2d50d00082c7d12/master.m3u8?deviceId=channel&deviceModel=web&deviceVersion=1.0&appVersion=1.0&deviceType=web&deviceMake=web&deviceDNT=1', 'region': 'US', 'source': 'Pluto TV US'},
    # VH1 - Pluto TV Italia
    {'name': 'VH1+ Music Legends', 'url': 'https://service-stitcher.clusters.pluto.tv/v1/stitch/embed/hls/channel/62e8cc10ca869f00078efca8/master.m3u8?deviceId=channel&deviceModel=web&deviceVersion=1.0&appVersion=1.0&deviceType=web&deviceMake=web&deviceDNT=1', 'region': 'IT', 'source': 'Pluto TV IT'},
    {'name': "VH1+ Back to 90's", 'url': 'https://service-stitcher.clusters.pluto.tv/v1/stitch/embed/hls/channel/6552085aab05240008b05f6c/master.m3u8?deviceId=channel&deviceModel=web&deviceVersion=1.0&appVersion=1.0&deviceType=web&deviceMake=web&deviceDNT=1', 'region': 'IT', 'source': 'Pluto TV IT'},
    {'name': 'VH1+ Rock!', 'url': 'https://service-stitcher.clusters.pluto.tv/v1/stitch/embed/hls/channel/636a4173e34fd50007534542/master.m3u8?deviceId=channel&deviceModel=web&deviceVersion=1.0&appVersion=1.0&deviceType=web&deviceMake=web&deviceDNT=1', 'region': 'IT', 'source': 'Pluto TV IT'},
    {'name': 'VH1+ Dance', 'url': 'https://service-stitcher.clusters.pluto.tv/v1/stitch/embed/hls/channel/65e5d9d2ec9fda0008c35f91/master.m3u8?deviceId=channel&deviceModel=web&deviceVersion=1.0&appVersion=1.0&deviceType=web&deviceMake=web&deviceDNT=1', 'region': 'IT', 'source': 'Pluto TV IT'},
    {'name': 'VH1+ Classici', 'url': 'https://service-stitcher.clusters.pluto.tv/v1/stitch/embed/hls/channel/6690f892d51259000880d1c4/master.m3u8?deviceId=channel&deviceModel=web&deviceVersion=1.0&appVersion=1.0&deviceType=web&deviceMake=web&deviceDNT=1', 'region': 'IT', 'source': 'Pluto TV IT'},
    # VH1 - Outros
    {'name': 'VH1 Italia', 'url': 'https://content.uplynk.com/channel/36953f5b6546464590d2fcd954bc89cf.m3u8', 'region': 'IT', 'source': 'iptv-org'},
    # MTV - MoveOnJoy (alta confiabilidade)
    {'name': 'MTV East', 'url': 'https://fl1.moveonjoy.com/MTV/index.m3u8', 'region': 'US', 'source': 'MoveOnJoy'},
    {'name': 'MTV2', 'url': 'https://fl1.moveonjoy.com/MTV_2/index.m3u8', 'region': 'US', 'source': 'MoveOnJoy'},
    {'name': 'MTV Live', 'url': 'https://fl1.moveonjoy.com/MTV_LIVE/index.m3u8', 'region': 'US', 'source': 'MoveOnJoy'},
    {'name': 'mtvU', 'url': 'https://fl1.moveonjoy.com/MTV_U/index.m3u8', 'region': 'US', 'source': 'MoveOnJoy'},
    # MTV - Pluto TV US
    {'name': "MTV Spankin' New", 'url': 'http://cfd-v4-service-channel-stitcher-use1-1.prd.pluto.tv/stitch/hls/channel/5d14fdb8ca91eedee1633117/master.m3u8?appName=web&appVersion=unknown&deviceDNT=0&deviceId=mtv-spankin&deviceMake=Chrome&deviceModel=web&deviceType=web&deviceVersion=unknown&includeExtendedEvents=false&serverSideAds=false', 'region': 'US', 'source': 'Pluto TV US'},
    {'name': 'MTV en Español', 'url': 'http://cfd-v4-service-channel-stitcher-use1-1.prd.pluto.tv/stitch/hls/channel/5cf96d351652631e36d4331f/master.m3u8?appName=web&appVersion=unknown&deviceDNT=0&deviceId=mtv-espanol&deviceMake=Chrome&deviceModel=web&deviceType=web&deviceVersion=unknown&includeExtendedEvents=false&serverSideAds=false', 'region': 'US', 'source': 'Pluto TV US'},
    {'name': 'MTV Flow Latino', 'url': 'http://cfd-v4-service-channel-stitcher-use1-1.prd.pluto.tv/stitch/hls/channel/5d3609cd6a6c78d7672f2a81/master.m3u8?appName=web&appVersion=unknown&deviceDNT=0&deviceId=mtv-flow&deviceMake=Chrome&deviceModel=web&deviceType=web&deviceVersion=unknown&includeExtendedEvents=false&serverSideAds=false', 'region': 'US', 'source': 'Pluto TV US'},
    # MTV - Pluto TV Europa
    {'name': 'MTV Music', 'url': 'http://cfd-v4-service-channel-stitcher-use1-1.prd.pluto.tv/stitch/hls/channel/6245d15062cd1f00070a2338/master.m3u8?appName=web&appVersion=unknown&deviceDNT=0&deviceId=mtv-music&deviceMake=Chrome&deviceModel=web&deviceType=web&deviceVersion=unknown&includeExtendedEvents=false&serverSideAds=false', 'region': 'DE', 'source': 'Pluto TV DE'},
    {'name': 'MTV Classics FR', 'url': 'http://cfd-v4-service-channel-stitcher-use1-1.prd.pluto.tv/stitch/hls/channel/5f92b56a367e170007cd43f4/master.m3u8?appName=web&appVersion=unknown&deviceDNT=0&deviceId=mtv-classics-fr&deviceMake=Chrome&deviceModel=web&deviceType=web&deviceVersion=unknown&includeExtendedEvents=false&serverSideAds=false', 'region': 'FR', 'source': 'Pluto TV FR'},
    {'name': 'MTV Originals ES', 'url': 'https://service-stitcher.clusters.pluto.tv/stitch/hls/channel/5f1aadf373bed3000794d1d7/master.m3u8?advertisingId=&appName=web&appVersion=DNT&deviceDNT=0&deviceId=mtv-originals&deviceMake=web&deviceModel=web&deviceType=web&deviceVersion=DNT&includeExtendedEvents=false&serverSideAds=false', 'region': 'ES', 'source': 'Pluto TV ES'},
    # MTV - Streams adicionais
    {'name': 'MTV 00s', 'url': 'http://myott.top/stream/DT6QU63K5VX/165.m3u8', 'region': 'INT', 'source': 'myott'},
    {'name': 'MTV 80s', 'url': 'http://myott.top/stream/DT6QU63K5VX/87.m3u8', 'region': 'INT', 'source': 'myott'},
    {'name': 'MTV 90s', 'url': 'http://myott.top/stream/DT6QU63K5VX/88.m3u8', 'region': 'INT', 'source': 'myott'},
    {'name': 'MTV Hits', 'url': 'http://myott.top/stream/DT6QU63K5VX/302.m3u8', 'region': 'INT', 'source': 'myott'},
    # Notícias BR - canais extras
    {'name': 'BandNews TV', 'url': 'https://evpp.mm.uol.com.br/geob_band/bandnewstv/playlist.m3u8', 'region': 'BR', 'source': 'Band'},
]

# Mapeamento de região para nome do país
REGION_TO_COUNTRY = {
    'BR': 'Brasil',
    'br': 'Brasil',
    'US': 'USA',
    'us': 'USA',
    'GB': 'UK',
    'gb': 'UK',
    'CA': 'Canada',
    'ca': 'Canada',
}

# Classificação de canais brasileiros por categoria
# Ordem importa: a primeira categoria que bater ganha
BR_CATEGORIES = [
    ('BR Legislativo', [
        'tv câmara', 'tv camara', 'tv justiça', 'tv justica', 'alerj', 'almg', 'alesp',
        'canal gov', 'tv senado', 'erga omnes', 'câmara lins', 'camara lins',
    ]),
    ('BR Anime', [
        'naruto', 'death note', 'hunter x hunter', 'one piece', 'boruto', 'yu-gi-oh',
        'pokémon', 'pokemon', 'beyblade', 'inuyasha', 'jojo', 'anime', 'tokusato',
        'super onze', 'dragon ball', 'shippuden', 'otaku sign',
    ]),
    ('BR Kids', [
        'nick jr', 'nickelodeon', 'turma da mônica', 'turma da monica', 'bob esponja',
        'dpa', 'cocoricó', 'cocorico', 'teletubbies', 'smurfs', 'tartarugas ninja',
        'reino infantil', 'padrinhos mágicos', 'padrinhos magicos', 'popeye',
        'oggy', 'jetsons', 'inspetor bugiganga', 'icarly', 'kenan', 'babyfirst',
        'moranguinho', 'pluto tv junior', 'pluto tv kids', 'kids club',
        'gospel cartoon', 'ministério infantil', 'ministerio infantil', 'dm kids',
        'f. kids', 'kids mais',
    ]),
    ('BR Notícias', [
        'cnn brasil', 'jovem pan', 'record news', 'sbt news', 'bm&c news',
        'bloomberg', 'euronews', 'news now', 'cbs news', 'usa today',
        'newsmax', '011 news', 'canal uol', 'norte news', 'bandnews',
        'tv 247', 'times brasil', 'cnbc', 'canal rural', 'notícias agrícolas',
        'noticias agricolas', 'new brasil', 'terraviva', 'veja mais',
    ]),
    ('BR Esportes', [
        'fifa', 'dazn', 'pfl mma', 'fuel tv', 'racer', 'ge tv', 'sft combat',
        'kickboxing', 'esporte', 'sport', 'baseball', 'billiard', 'poker',
        'combat', 'horse', 'play tv horse', 'playtv horse', 'unique sports',
        'rs sports', 'trace sport', 'people are awesome', 'speedvision',
        'motorvision', 'pluto tv turbo', 'pluto tv esportes', 'auto tv',
    ]),
    ('BR Filmes', [
        'pluto tv cine', 'pluto tv filmes', 'filmelier', 'darkflix', 'cinemonde',
        'adrenalina pura', 'filmes suspense', 'cine sucessos', 'cine comédia',
        'cine comedia', 'cine drama', 'cine terror', 'cine clássicos', 'cine classicos',
        'cine romance', 'cine família', 'cine familia', 'ficção científica',
        'ficcao cientifica', 'filmes nacionais', 'filmes aventura', 'filmes ação',
        'filmes acão', 'filmes de luta', 'cine crime', 'cine inspiração',
        'cine inspiracao', 'sony one cinema', 'movieark', 'clube do terror',
        'terror trash', 'pluto tv bang bang', 'pluto tv policial', 'netmovies',
        'runtime', 'tu cine', 'freetv acción', 'freetv accion', 'freetv drama',
        'freetv terror', 'freetv familia', 'freetv sureño', 'freetv sureno',
        'spark tv luz', 'gospel movie',
    ]),
    ('BR Séries', [
        'walking dead', 'csi', 'ncis', 'charmed', 'macgyver', 'jornada nas estrelas',
        'star trek', 'z nation', 'rookie blue', 'numbers', 'feiticeira',
        'pluto tv séries', 'pluto tv series', 'séries classic', 'series classic',
        'diff\'rent strokes', 'pluto tv novelas', 'séries novelescas',
        'caçadora de relíquias', 'cacadora de reliquias', 'mistérios sem solução',
        'misterios sem solucao', 'pluto tv retrô', 'pluto tv retro',
        'pluto tv investigação', 'pluto tv investigacao', 'arquivos do fbi',
        'estado paranormal', 'caçadores de óvnis', 'cacadores de ovnis',
        'assombrações', 'assombracoes', 'pluto tv mistérios', 'pluto tv misterios',
        'pluto tv aliens', 'detetives médicos', 'detetives medicos',
        'pronto-socorro', 'acumuladores', 'pluto tv vida real', 'pluto tv curiosidade',
        'obsessão favorita', 'obsessao favorita', 'negócio fechado', 'negocio fechado',
        'homem que veio do céu', 'homem que veio do ceu',
    ]),
    ('BR Entretenimento', [
        'comedy central', 'failarmy', 'masterchef', 'south park',
        'pegadinhas', 'just for laughs', 'shark tank', 'encantador de cães',
        'encantador de caes', 'pluto tv animais', 'pet collective', 'fashiontv',
        'caras tv', 'pluto tv história', 'pluto tv historia', 'smithsonian',
        'pluto tv natureza', 'nature time', 'weatherspy', 'pluto tv cozinha',
        'kfood', 'gusto tv', 'receitas fast', 'tastemade', 'pluto tv viagens',
        'gousa', 'arirang', 'bet pluto', 'pluto tv gaming', 'realmadrid tv',
        'geekdot', 'salon line', 'sony one emoções', 'sony one emocoes',
        'malhacao', 'malhação', 'novela',
    ]),
    ('BR Religiosas', [
        'aparecida', 'canção nova', 'cancao nova', 'rit tv', 'rittv', 'evangelizar',
        'novo tempo', 'gospel', 'igreja', 'católica', 'catolica', 'cristão', 'cristao',
        'promessas', 'pai eterno', 'terceiro anjo', 'avivando', 'apóstolos', 'apostolos',
        'imjc', 'kuriakos', 'adorador', 'adorar', 'katholika', 'família de jesus',
        'familia de jesus', 'maanaim', 'manancial', 'tv sbn', 'angel tv',
        'caminho antigo', 'tv alpha', 'web tv catolica', 'unifé', 'unife',
        'tv feliz', 'tenda tv',
    ]),
    ('BR Música', [
        'stingray', 'karaokê', 'karaoke', 'forró', 'forro', 'sertanejo',
        'pop retrô', 'pop retro', 'rock show', 'qwest tv', 'hits', 'kpop',
        'classique tv', 'rede blitz',
        'rádio forró', 'radio forro', 'hip-hop', 'hip hop', 'caipira',
        'pluto tv shows por stingray', 'pluto tv paisagens', 'pluto tv karaokê',
        'tikitok radio', 'tiktok radio',
    ]),
]

# Ordem de relevância para BR Notícias (menor = mais relevante)
NEWS_RELEVANCE = [
    'cnn brasil',
    'record news',
    'bandnews',
    'jovem pan',
    'sbt news',
    'bm&c news',
    'times brasil',
    'cnbc',
    'bloomberg',
    'canal uol',
    'euronews',
    'cnn portugal',
    'canal rural',
    'terraviva',
    'new brasil',
    'veja mais',
    'notícias agrícolas',
    'noticias agricolas',
    'tv 247',
    '011 news',
    'cbs news',
    'usa today',
    'newsmax',
    'norte news',
]


# ============================================================
# FUNCOES
# ============================================================

def get_news_relevance(channel_name):
    """Retorna prioridade de relevância para canais de notícias."""
    name_lower = channel_name.lower()
    for i, keyword in enumerate(NEWS_RELEVANCE):
        if keyword in name_lower:
            return i
    return 999


def classify_br_channel(channel_name):
    """Classifica um canal brasileiro em subcategoria."""
    name_lower = channel_name.lower()
    for category, keywords in BR_CATEGORIES:
        for kw in keywords:
            if kw in name_lower:
                return category
    return 'BR Variedades'


def get_final_group(original_group, region, channel_name=''):
    """Determina o grupo final baseado no país, categoria ou música."""
    name_lower = channel_name.lower() if channel_name else ''

    # VH1 e MTV são categorias globais (qualquer região)
    if 'vh1' in name_lower:
        return 'VH1'
    import re
    if re.search(r'\bmtv\b', name_lower):
        return 'MTV'

    original_lower = original_group.lower() if original_group else ''

    # Se for música (qualquer região), coloca no grupo Music
    if 'music' in original_lower:
        return 'Music'

    # Se for Brasil, classifica em subcategoria
    if region.upper() == 'BR':
        return classify_br_channel(channel_name)

    # Demais regiões: retorna o país
    return REGION_TO_COUNTRY.get(region, 'Other')


def extract_group_from_extinf(extinf_line):
    """Extrai o group-title de uma linha EXTINF."""
    import re
    match = re.search(r'group-title="([^"]*)"', extinf_line)
    return match.group(1) if match else ''


def extract_logo_from_extinf(extinf_line):
    """Extrai o tvg-logo de uma linha EXTINF."""
    import re
    match = re.search(r'tvg-logo="([^"]*)"', extinf_line)
    return match.group(1) if match else ''


def update_extinf_group(extinf_line, new_group):
    """Atualiza o group-title em uma linha EXTINF."""
    import re
    if 'group-title="' in extinf_line:
        return re.sub(r'group-title="[^"]*"', f'group-title="{new_group}"', extinf_line)
    else:
        # Adiciona group-title se não existir
        return extinf_line.replace('#EXTINF:-1 ', f'#EXTINF:-1 group-title="{new_group}" ')


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


def parse_m3u_to_channels(content, source_name, region):
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
            original_group = extract_group_from_extinf(current_extinf)
            logo = extract_logo_from_extinf(current_extinf)
            channels.append({
                'name': name,
                'url': line,
                'extinf': current_extinf,
                'source': source_name,
                'region': region,
                'original_group': original_group,
                'logo': logo
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
            'source': source_name,
            'region': region,
            'original_group': group,
            'logo': logo
        })

    return channels


def deduplicate_channels(channels):
    """Remove canais duplicados baseado na URL do stream."""
    seen_urls = set()
    unique = []
    for ch in channels:
        url = ch['url'].split('?')[0].rstrip('/')
        if url not in seen_urls:
            seen_urls.add(url)
            unique.append(ch)
    removed = len(channels) - len(unique)
    if removed:
        print(f"  Duplicados removidos: {removed}")
    print(f"  Canais unicos: {len(unique)}")
    return unique


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
                channels = parse_m3u_to_channels(content, source['name'], region)
                all_channels.extend(channels)

        elif source_type == 'mjh' and mjh_data:
            print(f"  Processando {source['name']}...")
            channels = generate_mjh_channels(mjh_data, region, source['name'])
            all_channels.extend(channels)
            print(f"    OK! ({len(channels)} canais)")

    # Adicionar canais extras (VH1, MTV)
    if EXTRA_CHANNELS:
        print(f"\n  Adicionando {len(EXTRA_CHANNELS)} canais extras (VH1/MTV)...")
        for ch in EXTRA_CHANNELS:
            logo = ch.get('logo', '')
            extinf = f'#EXTINF:-1 tvg-name="{ch["name"]}" tvg-logo="{logo}",{ch["name"]}'
            all_channels.append({
                'name': ch['name'],
                'url': ch['url'],
                'extinf': extinf,
                'source': ch.get('source', 'Extra'),
                'region': ch.get('region', 'INT'),
                'original_group': '',
                'logo': logo
            })

    print(f"\nTotal coletados: {len(all_channels)}")
    all_channels = deduplicate_channels(all_channels)

    # Filtrar canais sem logo
    before_filter = len(all_channels)
    all_channels = [ch for ch in all_channels if ch.get('logo', '').strip()]
    removed_no_logo = before_filter - len(all_channels)
    if removed_no_logo:
        print(f"  Canais sem logo removidos: {removed_no_logo}")
    print(f"  Canais com logo: {len(all_channels)}")

    return all_channels


def generate_m3u_content(channels):
    """Gera conteudo M3U."""
    lines = ['#EXTM3U']
    lines.append(f'# Atualizado: {datetime.utcnow().strftime("%Y-%m-%d %H:%M:%S UTC")}')
    lines.append(f'# Canais: {len(channels)}')
    lines.append('')

    # Pré-calcular grupo final de cada canal
    enriched = []
    for ch in channels:
        original_group = ch.get('original_group', '')
        region = ch.get('region', '')
        channel_name = ch.get('name', '')
        final_group = get_final_group(original_group, region, channel_name)
        enriched.append((ch, final_group))

    # Ordenar BR Notícias por relevância
    enriched.sort(key=lambda x: get_news_relevance(x[0].get('name', '')) if x[1] == 'BR Notícias' else 999)

    for ch, final_group in enriched:
        updated_extinf = update_extinf_group(ch['extinf'], final_group)
        lines.append(updated_extinf)
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

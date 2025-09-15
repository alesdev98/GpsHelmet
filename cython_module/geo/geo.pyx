# cython: language_level=3

from shapely.geometry import Point
from os import path
from json import load
from geopy.distance import geodesic
from PIL import Image, ImageSequence
import geopandas as gpd, pickle, time, matplotlib.pyplot as plt, io, gc, logging

matplotlib_logger = logging.getLogger('matplotlib')
PIL_logger = logging.getLogger('PIL')
matplotlib_logger.setLevel(logging.WARNING)
PIL_logger.setLevel(logging.WARNING)

plt.switch_backend('agg')

cdef str regioni_path = path.join(path.dirname(path.dirname(path.realpath(__file__))), "files", "shapefiles.json")
cdef str regioni_gdfs = path.join(path.dirname(path.dirname(path.realpath(__file__))), "files", "gdfs.geojson.pkl")
cdef str image_path = path.join(path.dirname(path.dirname(path.realpath(__file__))), "files", "image.bmp")
cdef str gif_path = path.join(path.dirname(path.dirname(path.realpath(__file__))), "files", "mappa.gif")

cdef list regioni_list = []
cdef object regioni_pkl, regioni_json
cdef int minimum_distance = 50

def load_regioni(bint debug = False) -> None:
    """
    Carica i dati delle regioni italiane
    """
    cdef double time1, time2

    with open(regioni_path, 'r') as f:
        obj = load(f)

        global regioni_json
        regioni_json = gpd.GeoDataFrame.from_features(obj)
        regioni_list = list(set(regioni_json["nome_reg"].values))

    if not path.exists(regioni_gdfs):
        print("File not found")
    else:
        with open(regioni_gdfs, 'rb') as f:
            time1 = time.time()
            global regioni_pkl
            regioni_pkl = pickle.load(f)
            time2 = time.time()

            if debug:
                print("Time to load pickle file: ", (time2 - time1))

def check() -> tuple[bint, bint]:
    return path.exists(regioni_path), path.exists(regioni_gdfs)

def check_pkl() -> bint:
    return regioni_pkl != None

def get_regione(lon : double, lat : double) -> str:
    """
    Funziona che ritorna la regione corrente
    :param lon: Longitudine.
    :param lat: Latitudine.
    :return: La regione in cui il punto fa parte
    """
    point = Point(lon, lat)
    filtered_gdf = regioni_json[regioni_json.contains(point)]
    return list(dict(filtered_gdf.nome_reg).values())[0]

def find_nearby_roads(gdf : object, coordinate : tuple(double, double), buffer_distance : float = 0.001) -> object:
    """
    Funzione che ha lo scopo di ritorna tutte le strade vicine al punto
    :param gdf: GeoDataFrame, recuperato precedentemente.
    :param coordinate: Coordinate Longitudine, Latitudine.
    :return: GeoDataFrame della mappa (più precisa)
    """
    buffer_distance = (buffer_distance / 100000) if buffer_distance > 0 else buffer_distance

    point = Point(coordinate)

    # Applica un buffer al punto per ottenere una zona circostante
    return gdf[gdf.intersects(point.buffer(buffer_distance))]

def find_nearest_road(gdf : object, coordinate : tuple(double, double)) -> tuple(double, double):
    """
    Funzione che ha lo scopo di ritornare la strada più vicina al punto
    :param gdf: GeoDataFrame, recuperato precedentemente.
    :param coordinate: Coordinate Longitudine, Latitudine.
    :return: Coordinate della strada più vicina
    """
    cdef float nearest_distance = float('inf') # Valore infinito
    cdef object nearest_geometry = None

    point = Point(coordinate)

    # Itera sul GeoDataFrame per trovare la geometria più vicina al punto
    for idx, row in gdf.iterrows():
        distance = row.geometry.distance(point)
        if distance < nearest_distance:
            nearest_distance = distance
            nearest_geometry = row.geometry
    
     # Crea un punto sulla strada più vicina alla posizione del punto di interesse
    new_point = nearest_geometry.interpolate(nearest_geometry.project(Point(coordinate)))

    return (float(new_point.x), float(new_point.y))

def get_minDistance(coordinate_lat : double, coordinate_lon : double, bbox: tuple(double, double, double, double)) -> tuple(double, tuple(double, double), list):
        """
        Funzione che calcola la distanza minima dal punto ai bordi della bbox
        :param coordinate_lat: Latitudine del punto.
        :param coordinate_lon: Longitudine del punto.
        :param bbox: BoundyBox dell'aerea.
        :return: Distanza minima, Punto più vicino, Buffers
        """
        y_min, x_min, y_max, x_max = bbox

        # Calcola le coordinate dei vertici della bbox & coordinata
        bbox_vertices = [
            (coordinate_lon, y_min),  # Vertice in basso a sinistra
            (x_max, coordinate_lat),  # Vertice in basso a destra
            (coordinate_lon, y_max),  # Vertice in alto a destra
            (x_min, coordinate_lat)   # Vertice in alto a sinistra
        ]

        buffers = []
        # 0 => DOWN
        # 1 => RIGHT
        # 2 => UP
        # 3 => LEFT

        # Calcola la distanza minima dal punto ai bordi della bbox
        min_distance = float('inf')  # Inizializza con un valore elevato
        for vertex_lon, vertex_lat in bbox_vertices:

            buffers.append((coordinate_lat - vertex_lat) if(coordinate_lat - vertex_lat)!=0 else (coordinate_lon - vertex_lon))

            distance = geodesic((coordinate_lat, coordinate_lon), (vertex_lat, vertex_lon)).meters
            if distance < min_distance:
                min_distance = distance
                nearest_point = (vertex_lon, vertex_lat)
        
        # self._logger.info(msg = f"Distanza minima: {min_distance} meters")
        # self._logger.info(msg = f"Buffers (DOWN, RIGHT, UP, LEFT): {buffers}")

        return min_distance, nearest_point, buffers
def roads_to_image(roads_gdf : object, coordinate : tuple(double, double), margin : float, bbox : tuple(double, double, double, double), dpi: int) -> tuple[object, list]:
    """
    Funzione che ha lo scopo di ritornare l'immagine della mappa
    :param roads_gdf: GeoDataFrame, recuperato precedentemente.
    :param coordinate: Coordinate Longitudine, Latitudine.
    :param zoom: Zoom dell'area.
    :param bbox: BoundyBox dell'aerea.
    :return: Immagine della mappa, BBox della mappa
    """
    coordinate_lon, coordinate_lat = coordinate

    cdef int target_width = 128
    cdef int target_height = 64
    
    cdef double y_min, x_min, y_max, x_max

    # Crea un'immagine binaca con strade nere
    cdef object fig
    cdef object ax
    fig, ax = plt.subplots(figsize=(12, 6), dpi=dpi)
    ax.set_aspect('equal')

    # Rimuovi assi
    ax.axis('off')

    y_min, x_min, y_max, x_max = bbox

    if not(x_min <= coordinate_lon <= x_max and y_min <= coordinate_lat <= y_max):
        # Nuovo bbox
        bbox = y_min, x_min, y_max, x_max = coordinate_lat - margin/2, coordinate_lon - margin, coordinate_lat + margin/2, coordinate_lon + margin
    
    min_distance, nearest_point, buffers = get_minDistance(coordinate_lat, coordinate_lon, bbox)

    if min_distance < minimum_distance:
        bbox = y_min, x_min, y_max, x_max = coordinate_lat - (-buffers[2]), coordinate_lon - (-buffers[1]), coordinate_lat + (buffers[0]), coordinate_lon + (buffers[3])

        meters_per_degree_latitude = 111139
        # Calculate the distance in degrees
        distance_degrees = minimum_distance / meters_per_degree_latitude

        if coordinate_lat - y_min < distance_degrees:
            diff = distance_degrees - (coordinate_lat - y_min)
            y_min -= diff
            y_max -= diff
        elif y_max - coordinate_lat < distance_degrees:
            diff = distance_degrees - (y_max - coordinate_lat)
            y_min += diff
            y_max += diff
        
        if coordinate_lon - x_min < distance_degrees:
            diff = distance_degrees - (coordinate_lon - x_min)
            x_min -= diff
            x_max -= diff
        elif x_max - coordinate_lon < distance_degrees:
            diff = distance_degrees - (x_max + coordinate_lon)
            x_min += diff
            x_max += diff
        
        bbox = y_min, x_min, y_max, x_max
        
        _, nearest_point, _ = get_minDistance(coordinate_lat, coordinate_lon, bbox)

    # Filter the GeoDataFrame of roads for the desired bounding box and plot directly
    roads_gdf.cx[x_min:y_min, x_max:y_max].plot(ax=ax, color='black', linewidth=5)

    # Disegna il punto (la tua coordinata)
    ax.plot(coordinate_lon, coordinate_lat, marker='o', color='black', markersize=35)

    # Imposta lo sfondo bianco
    ax.set_facecolor('white')

    # Calcola i limiti degli assi
    ax.set_xlim(x_min, x_max)
    ax.set_ylim(y_min, y_max)

    # Salva l'immagine
    buffer_img = io.BytesIO()
    plt.savefig(buffer_img, format='png', bbox_inches='tight', pad_inches=0)
    plt.close(fig)
    del fig, ax
    gc.collect()

    # Rewind the buffer_img to the beginning
    buffer_img.seek(0)

    # Apri l'immagine dal buffer_img e ridimensiona
    with Image.open(buffer_img) as img:
        resized_image = img.resize((target_width, target_height))

    # Converti l'immagine ridimensionata in bytes
    with io.BytesIO() as output_buffer:
        resized_image.save(output_buffer, format='png')
        output_buffer.seek(0)
        image_bytes = output_buffer.getvalue()
    
    del img
    gc.collect()

    # Chiudi il buffer_img originale
    buffer_img.close()

    return image_bytes, list(bbox)

def convert_png_to_bmp(image_bytes : object) -> object:
    """
    Funzione che converte un'immagine PNG in BMP
    :param image_bytes: Immagine in bytes.
    :return: Immagine convertita in BMP.
    """
    try:
        # Open the PNG image file
        with Image.open(io.BytesIO(image_bytes)) as img:

            # Convert the image to RGB mode (if it's in indexed or RGBA mode)
            img = img.convert("RGB")

            # Save the image as BMP format
            bmp_buffer = io.BytesIO()
            img.save(bmp_buffer, format='BMP')
            bmp_buffer.seek(0)

            # Read the content of the buffer and return as bytes
            # bmp_bytes = bmp_buffer.getvalue()
            
            return bmp_buffer
    except Exception as e:
        print(f"Conversion failed: {e}")

def create_image(coordinate: tuple(double, double), bbox : list = [0,0,0,0], zoom : float = 0.004, buffer_distance: float = 500, dpi: int = 300) -> tuple(list, list):
    """
    Funzione che genererà l'immagine/mappa del luogo adiacente alla posizione
    :param coordinate: Coordinate Longitudine, Latitudine.
    :param bbox: BoundyBox dell'aerea.
    :param zoom: Zoom dell'area.
    :param buffer_distance: Distanza dal punto per il recupero delle mappe.
    :return: Immagine, Coordinate del Punto (calcolato), BBox della mappa, Regione in cui si trova il Punto
    """
    lon, lat = coordinate
    cdef str regione = get_regione(lon, lat)

    nearby_roads = find_nearby_roads(gdf = regioni_pkl[regione], coordinate = coordinate, buffer_distance = buffer_distance)

    if nearby_roads.empty:
        raise Exception("No roads found near the point")
    
    coordinate : tuple(double, double) = find_nearest_road(gdf = nearby_roads, coordinate = coordinate)

    image, bbox = roads_to_image(roads_gdf = nearby_roads, coordinate = coordinate, margin = zoom, bbox = tuple(bbox), dpi = dpi)

    image = convert_png_to_bmp(image)

    with open(image_path, "wb") as f:
        f.write(image.getvalue())

    return coordinate, list(bbox)


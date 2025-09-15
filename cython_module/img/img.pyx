# from waveshare_OLED.lib import OLED_1in3
import sys, time, logging
from PIL import Image, ImageDraw, ImageFont, ImageSequence
from os import path

# Cython Modules
from cython_module.gps import get_latest_gps_data
from cython_module.geo import get_regione, find_nearby_roads, find_nearest_road, get_minDistance

logging.basicConfig(level=logging.DEBUG)

# Lib OLED_1in3

cdef str waveshare_dir = path.join(path.dirname(path.dirname(path.realpath(__file__))), "waveshare_OLED", "pic")
cdef str waveshare_lib = path.join(path.dirname(path.dirname(path.realpath(__file__))), "waveshare_OLED", "lib")
cdef str waveshare_font = path.join(waveshare_dir, 'Font.ttc')

cdef str bmp_image = path.join(path.dirname(path.dirname(path.realpath(__file__))), "files", "image.bmp")
cdef str gif_path = path.join(path.dirname(path.dirname(path.realpath(__file__))), "files", "mappa.gif")

if path.exists(waveshare_lib):
    sys.path.append(waveshare_lib)

import OLED_1in3 # type: ignore

###############
## INIT OLED ##
###############

cdef object disp = OLED_1in3.OLED_1in3()
disp.Init()

###############
## FUNCTIONS ##
###############

def show_text_originale(text: str, font_size: int = 14, sleep_time: float = 0.5) -> None:
    """
    Show text on OLED Display
    : param disp: OLED Display
    : param text: Text to show
    : param sleep_time: Time to show text
    : return: None
    """

    try:

        img = Image.new(
            mode = '1', 
            size = (disp.width, disp.height), 
            color= "WHITE")
        font = ImageFont.truetype(
            font = waveshare_font, 
            size = font_size)
        draw = ImageDraw.Draw(img)

        draw.text((20,0), text, font = font, fill = 0)
        img = img.rotate(180)

        disp.ShowImage(disp.getbuffer(img))

        if sleep_time != 0.5:
            disp_clean(sleep_time)
    except Exception as e:
        print("Error:", e)

def show_text(text: str, font_size: int = 14, sleep_time: float = 0.5, scroll_speed: float = 0.025) -> None:
    """
    Show text on OLED Display with automatic scrolling if text is too large for the screen.
    
    :param text: Text to show
    :param font_size: Size of the font to use
    :param sleep_time: Time to show the text before clearing the screen
    :param scroll_speed: Speed at which the text scrolls (in seconds)
    :return: None
    """
    
    try:
        # Create image to fit display
        img = Image.new(mode='1', size=(disp.width, disp.height), color="WHITE")
        font = ImageFont.truetype(font=waveshare_font, size=font_size)
        draw = ImageDraw.Draw(img)
        
        # Get the bounding box of the text
        text_bbox = draw.textbbox((0, 0), text, font=font)
        text_width = text_bbox[2] - text_bbox[0]  # Width of the text
        text_height = text_bbox[3] - text_bbox[1]  # Height of the text
        
        # Check if the text fits within the screen width
        if text_width <= disp.width:
            # If the text fits, draw it directly
            draw.text((10, 10), text, font=font, fill=0)
            img = img.rotate(180)
            img = img.transpose(Image.FLIP_TOP_BOTTOM)
            disp.ShowImage(disp.getbuffer(img))
            time.sleep(sleep_time)
        else:
            # If the text doesn't fit, scroll it
            for y_offset in range((int(text_height / (disp.height % 70)) + 1) if text_height > disp.height else 1):
                y_offset = (disp.height % 30) * y_offset
                for x_offset in range(0, text_width - disp.width + 1):
                    try:
                        # Clear the previous drawing
                        img = Image.new(mode='1', size=(disp.width, disp.height), color="WHITE")
                        draw = ImageDraw.Draw(img)

                        # Draw the text with the scrolling offset
                        draw.text((-x_offset, -y_offset), text, font=font, fill=0)
                        img = img.rotate(180)
                        img = img.transpose(Image.FLIP_TOP_BOTTOM)
                        
                        disp.ShowImage(disp.getbuffer(img))
                        
                        # Pause for the scrolling effect
                        time.sleep(scroll_speed)
                    except KeyboardInterrupt:
                        logging.info(" ctrl + c")
                        disp_clean()
                        break

        # Clean display if necessary
        if sleep_time != 0.5:
            disp_clean(sleep_time)
    
    except Exception as e:
        print("Error:", e)



def disp_clean(sleep_time: float = 0.5) -> None:
    """
    Clean OLED Display
    : param disp: OLED Display
    : param sleep_time: Time to clean display
    : return: None
    """
    time.sleep(sleep_time)
    disp.clear()

def close_disp() -> None:
    """
    Close OLED Display
    : return: None
    """

    show_text(text = "\n     --- Goodbye! ---", font_size = 12, sleep_time = 2)

    disp.clear()
    disp.module_exit()

def display_gif(gif_path, duration=0.1):
    # Carica la GIF
    gif = Image.open(path.join(waveshare_dir, gif_path))
    
    # Scorri attraverso i fotogrammi della GIF
    for frame in ImageSequence.Iterator(gif):
        # Ridimensiona il fotogramma alla risoluzione del display OLED
        frame = frame.resize((128, 64))
        
        # Converti il fotogramma in una bitmap (bianco e nero)
        frame = frame.convert('1')
        
        # Ottieni il buffer dell'immagine dal fotogramma
        buffer = disp.getbuffer(frame)
        
        # Mostra l'immagine sul display OLED
        disp.ShowImage(buffer)
        
        # Attendi per la durata specificata (frame delay)
        time.sleep(duration)
    
    disp.clear()

def show_map() -> None:
    """
    Show a map on the OLED display.
    """
    while(True):
        try:
            # logging.info ("***draw image")
            img = Image.new(mode='1', size=(disp.width, disp.height), color="WHITE")
            bmp = Image.open(bmp_image)
            img.paste(bmp, (0,0))
            img=img.rotate(180)
            img = img.transpose(Image.FLIP_TOP_BOTTOM)
            disp.ShowImage(disp.getbuffer(img))
            # time.sleep(0.5)
        except Exception as e:
            logging.info(e)
            continue
        finally:
            # disp.clear()
            pass

###############
#### TEST ####
###############
# show_text("Hello, World!", 12, 4)
import sys, os, logging, time, threading
from PIL import Image, ImageDraw, ImageFont, ImageSequence

# Cython Modules
import cython_module.gps as gps # type: ignore
import cython_module.geo as geo # type: ignore
import cython_module.img as img # type: ignore

# Logging

logging.basicConfig(level=logging.DEBUG)

enable_check = True
# enable_check = False

if __name__ == "__main__":

    try:

        #####################
        #####   INIT    #####
        #####################
        
        # Thread Init
        th_tmp = threading.Thread(target=img.show_text, kwargs={"text":f"Inizializzazione... \nLoad Regioni... \nLoad GPS...", "font_size": 14, "sleep_time":5})
        th_tmp.daemon = True
        th_tmp.start()

        # Thread GEO
        th_geo = threading.Thread(target=geo.load_regioni, kwargs={'debug': True})
        th_geo.daemon = True
        th_geo.start()

        # Thread GPS
        th_gps = threading.Thread(target=gps.read_gps_data, kwargs={'debug': False})
        th_gps.daemon = True
        th_gps.start()

        # Kill Threads
        th_tmp.join()

        #####################
        ######  CHECK  ######
        #####################
        if enable_check:
            limit = 10 # seconds for timeout

            check_geo1 = check_geo2 = False
            start_time = time.time()

            while ((not check_geo1) and (not check_geo2)) and (time.time() - start_time < limit):
                check_geo1, check_geo2 = geo.check()
                if check_geo1 and check_geo2:
                    # img.show_text(text = 'Thread GEO: OK', sleep_time = 1)
                    break
                time.sleep(1)

            check_gps = False
            check_data_gps = (None, None, None)
            start_time = time.time()
            while (not check_gps) and (time.time() - start_time < limit):
                check_data_gps = gps.get_latest_gps_data()
                if check_data_gps != (None, None, None):
                    # img.show_text(text = 'Thread GPS: OK', sleep_time = 1)
                    check_gps = True
                    break
                time.sleep(1)
            
            text = f"Check GEO: {'OK' if (check_geo1 and check_geo2) else 'Error'} \nCheck GPS: {'OK' if check_gps else 'Error'}"
            img.show_text(text = text, sleep_time = 1)

            if not((check_gps) and (check_geo1 and check_geo2)):
                # img.show_text(text = 'Exit', sleep_time = 1)
                exit()
            
            del check_geo1, check_geo2, start_time, limit, check_gps, check_data_gps, text

        img.show_text(text = 'Checks passed', sleep_time = 1)

        #####################
        ### GET GPS DATA ####
        #####################
        
        th_loading = threading.Thread(target=img.display_gif, kwargs={"gif_path":f"loading.gif", "duration": 0.1})
        th_loading.daemon = True
        th_loading.start()

        while not (geo.check_pkl()):
            time.sleep(1)
        th_geo.join()
        th_loading.join()

        
        # Thread GPS
        th_img = threading.Thread(target=img.show_map)
        th_img.daemon = True
        th_img.start()

        bbox = [0,0,0,0]

        i = 0
        speed = 0.00
        coord = [[44.979213842916465, 8.566036475980964],
[44.979299995924585, 8.566131204721652],
[44.97960312626724, 8.566455991134188],
[44.979887111683865, 8.566428926334977],
[44.980218959668356, 8.565973318027964],
[44.98068800591733, 8.565580867755388],
[44.98102941744561, 8.565301191847253],
[44.98135806962276, 8.56508917299625],
[44.98158460408342, 8.56467416966037],
[44.981855816779316, 8.564299753622562],
[44.98148568662383, 8.564177964377313],
[44.98101026156943, 8.564078733548387],
[44.98072308894788, 8.563411119401687],
[44.98051248967389, 8.562901391646172],
[44.98023171140059, 8.562175124169936],
[44.97993177003429, 8.561430825951726],
[44.979717990393254, 8.560862451367381],
[44.979497811876534, 8.559915165021108],
[44.97943400040123, 8.55910770427052],
[44.97920426094329, 8.558137858271923],
[44.97857566342873, 8.557001103972572],
[44.9781672244454, 8.556216208311506],
[44.97758009901368, 8.555598206892364],
[44.97683979351433, 8.555061414024719],
[44.976511120282055, 8.554935101206594],
[44.97588886973584, 8.554948633825195],
[44.97531128852977, 8.554957652985971],
[44.97451032234257, 8.554899014419266],
[44.97388166833287, 8.554452431775037],
[44.97296260787555, 8.5533066583467],
[44.972467964985206, 8.552661605705975]]

        while True:
            try:
                # latitude, longitude, speed = gps.get_latest_gps_data()
                latitude, longitude = coord[i][0], coord[i][1]
                i += 1

                current_reg : str = geo.get_regione(longitude, latitude)

                # disp_clean(disp)
                # img.show_text(text = f"Lat: {latitude} \nLon: {longitude} \nKmh: {round(speed,2)} \nReg: {current_reg.capitalize()}", font_size = 9)

                try:
                    coordinate, bbox = geo.create_image(coordinate = (longitude, latitude), bbox = bbox, dpi=200, zoom=0.00225)
                    print(f"latitude, longitude, speed: {coordinate, round(speed,2)}")
                except Exception as e: # type: ignore
                    img.show_text(text = f'{e}', font_size = 10, sleep_time = 3)

            except Exception as e:
                # logging.error(e)
                pass
                
    except KeyboardInterrupt:
        logging.info(" ctrl + c")

    except Exception as e:
        logging.error(e)

    # se viene chiuso il programm con un comando esterno "pkill python"
    except SystemExit:
        logging.info("Program terminated")

    finally:
        img.close_disp()
        exit()
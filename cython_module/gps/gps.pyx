# cython: language_level=3

import serial, pynmea2, time
from threading import Lock

cdef object latest_gps_data = None

def read_gps_data(str port = '/dev/ttyACM0', int baud_rate = 9600, bint debug = False) -> None:
    """
    Funzione per leggere dati GPS da una porta seriale.
    :param port: La porta seriale, come '/dev/ttyACM0' o 'COM3'.
    :param baud_rate: Il baud rate della connessione seriale.
    """

    cdef object ser # Oggetto seriale
    cdef str line # Riga letta dalla seriale
    cdef float latitude, longitude, speed # Variabili per dati GPS

    try:
        # Open serial port
        ser = serial.Serial(port, baud_rate, timeout=1)
        while True:
            # Leggi una linea di dati dalla seriale
            line = ser.readline().decode('ascii', errors='replace')

            # Parsifica i dati GPS
            if "$GPRMC" in line:
                latitude, longitude, speed = parse_gps(line)

            # Controlla se i dati sono validi
            if (latitude is not None) and (longitude is not None) and (speed is not None):
                global latest_gps_data
                latest_gps_data = (latitude, longitude, speed)

                if debug:
                    print(f"{time.time()}: {latest_gps_data}")
    except KeyboardInterrupt:
        print("Stopping GPS reading")# Chiudi la porta seriale se è aperta
        if ser.is_open:
            ser.close()
    except serial.SerialException as e:
        print(f"Local variable 'ser' referenced before assignment")
    except Exception as e:
        print(f"An error occurred: {type(e)}")
    # finally:
    #     # Chiudi la porta seriale se è aperta
    #     if ser.is_open:
    #         ser.close()

# Funzione Python per parsificare le stringhe GPS NMEA
def parse_gps(str data):
    """
    Parsifica i dati GPS dal formato NMEA.
    :param data: Una stringa di dati NMEA.
    :return: Latitudine, Longitudine e Velocità in nodi, oppure None se non è valido.
    """
    if data[0:6] == '$GPRMC':
        try:
            msg = pynmea2.parse(data)

            if msg.status == 'A':  # Controlla se i dati sono validi (A = Active)
                latitude = msg.latitude
                longitude = msg.longitude
                speed_knots = msg.spd_over_grnd
                return latitude, longitude, speed_knots
        except Exception as e:
            print(f"An error occurred during parsing: {e}")
    return -1, -1, -1

def get_latest_gps_data() -> tuple[str, str, str]:
    """
    Restituisce l'ultima stringa di dati GPS letta.
    :return: Una stringa con i dati GPS più recenti.
    """

    if latest_gps_data is not None:
        return latest_gps_data
    else:
        return None, None, None

def hello_world() -> str:
    return "Hello, World!"
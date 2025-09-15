# GpsHelmet



GPS

&nbsp;   Methods:

&nbsp;    - 1

&nbsp;       sudo apt-get install screen  # Install screen if it's not already installed



&nbsp;       sudo screen /dev/ttyACM0 9600



&nbsp;       This will start reading the GPS data from the USB port. If you want to exit screen, press Ctrl+A, then K, and confirm by pressing Y.



&nbsp;    - 2

&nbsp;       sudo apt-get install minicom

&nbsp;       sudo minicom -b 9600 -o -D /dev/ttyACM0

\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_



For compiling the Cython code

&nbsp;  CFLAGS="-w" python setup.py build\_ext --inplace


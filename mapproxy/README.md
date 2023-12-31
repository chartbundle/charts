Uses mapproxy
https://mapproxy.org/

Needs venv in mapproxy/ with mapproxy installed or paths changed.
chart/ contains configuration files and wsgi.py startup, will need to be fixed for newer Python

mapproxy.conf in this directory is an Apache config for WSGI
Directory and username used to be "wms" 

Cache was in cache/chart see chart/mapproxy.yaml to change. Put it somewhere fast or switch to another backend.



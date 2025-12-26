#!/bin/bash
sudo rm /usr/lib/x86_64-linux-gnu/thunarx-3/thunar-metadata-properties.so
sudo cp Scrivania/thunar-metadata-properties.so /usr/lib/x86_64-linux-gnu/thunarx-3/
thunar -q

#THUNARX_PYTHON_DEBUG=all 
THUNAR_METADATA_DEBUG=true THUNAR_PLUGINS_LOGLEVEL=debug thunar


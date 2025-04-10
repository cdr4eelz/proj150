#!/bin/bash

cat ./map-src.txt |xargs -n 1 -I{} echo \
  'FP={}; diff -q /FPGA/proj150/proj150.srcs/sources_1/imports/${FP} /FPGA/cs150/hardware/${FP}'


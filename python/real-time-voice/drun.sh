#!/bin/bash

docker run --rm -p 5000:5000  --env-file .env  real-time-voice:latest
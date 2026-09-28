#!/bin/bash
tries=0
while [ ! -S "/tmp/ncspot-$(id -u)/ncspot.sock" ] && [ $tries -lt 60 ]; do
    sleep 0.5
    tries=$(( tries + 1 ))
done

if [ -S "/tmp/ncspot-$(id -u)/ncspot.sock" ]; then
    sleep 1
    echo 'play' | nc -U /tmp/ncspot-$(id -u)/ncspot.sock
    sleep 0.5
    skips=$(( RANDOM % 20 + 1 ))
    for i in $(seq 1 $skips); do
        echo 'next' | nc -U /tmp/ncspot-$(id -u)/ncspot.sock
        sleep 0.3
    done
fi

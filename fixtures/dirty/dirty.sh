#!/usr/bin/env bash
name=$1
if [ $name == "x" ]; then
  echo "привет, $name"
fi
for f in $(ls); do
echo $f
done

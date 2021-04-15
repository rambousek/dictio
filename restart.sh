#!/bin/bash
status=`pumactl -F puma.rb status`
if [[ $status =~ "refused" ]]; then
  pumactl -F puma.rb start
else
  pumactl -F puma.rb phased-restart
fi

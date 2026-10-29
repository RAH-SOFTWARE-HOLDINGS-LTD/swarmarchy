#!/bin/bash

# Waybar custom/weather: the condition icon and temperature in the bar, the full
# status (place, temperature, wind) as the hover tooltip.
# swarmarchy-weather-status prints "<icon>    <place>  ·  Temp <t>  ·  Wind <w>".

status=$(swarmarchy-weather-status 2>/dev/null)

if [[ -n $status && $status != "Weather unavailable" ]]; then
  icon=${status%%    *}
  details=${status#*    }
  temperature=${details#*Temp }
  temperature=${temperature%% *}
  jq -cn --arg text "$icon $temperature" --arg tooltip "$details" '{text: $text, tooltip: $tooltip}'
else
  printf '{"text":"","class":"unavailable"}\n'
fi

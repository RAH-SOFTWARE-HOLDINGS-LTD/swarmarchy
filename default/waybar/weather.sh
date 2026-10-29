#!/bin/bash

# Waybar custom/weather: the main city's condition icon and temperature in the bar; the
# hover tooltip lists every city in ~/.config/swarmarchy/weather-location.
# swarmarchy-weather-status prints "<icon>    <place>  ·  Temp <t>  ·  Wind <w>".

status=$(swarmarchy-weather-status 2>/dev/null)

if [[ -n $status && $status != "Weather unavailable" ]]; then
  icon=${status%%    *}
  details=${status#*    }
  temperature=${details#*Temp }
  temperature=${temperature%% *}

  tooltip=$details
  mapfile -t cities < <(swarmarchy-weather-location --all)
  if (( ${#cities[@]} > 1 )); then
    tooltip=""
    for city in "${cities[@]}"; do
      line=$(swarmarchy-weather-status "$city" 2>/dev/null) || continue
      tooltip+="${tooltip:+$'\n'}${line#*    }"
    done
  fi

  jq -cn --arg text "$icon $temperature" --arg tooltip "$tooltip" '{text: $text, tooltip: $tooltip}'
else
  printf '{"text":"","class":"unavailable"}\n'
fi

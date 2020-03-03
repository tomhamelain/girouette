#!/bin/bash

# This script is based on code by Alexander Klimetschek at
# https://unix.stackexchange.com/a/415155/310780 (for bash select_option code)
# and customised by myself to a personal use 
#
# Render a text based list of available docker containers that can be selected by the
# user using up, down and enter keys and launch docker exec on this container.
#

function select_option {

  # little helpers for terminal print control and key input
  ESC=$( printf "\033")
  cursor_blink_on()  { printf "$ESC[?25h"; }
  cursor_blink_off() { printf "$ESC[?25l"; }
  cursor_to()        { printf "$ESC[$1;${2:-1}H"; }
  print_option()     { printf "   $1 "; }
  print_selected()   { printf "  $ESC[7m $1 $ESC[27m"; }
  get_cursor_row()   { IFS=';' read -sdR -p $'\E[6n' ROW COL; echo ${ROW#*[}; }
  key_input()        { read -s -n3 key 2>/dev/null >&2
                       if [[ $key = $ESC[A ]]; then echo up;    fi
                       if [[ $key = $ESC[B ]]; then echo down;  fi
                       if [[ $key = ""     ]]; then echo enter; fi; }

  # initially print empty new lines (scroll down if at bottom of screen)
  for opt; do printf "\n"; done

  # determine current screen position for overwriting the options
  local lastrow=`get_cursor_row`
  local startrow=$(($lastrow - $#))

  # ensure cursor and input echoing back on upon a ctrl+c during read -s
  trap "cursor_blink_on; stty echo; printf '\n'; exit" 2
  cursor_blink_off

  local selected=0
  while true; do
    # print options by overwriting the last lines
    local idx=0
    for opt; do
      cursor_to $(($startrow + $idx))
      if [ $idx -eq $selected ]; then
        print_selected "$opt"
      else
        print_option "$opt"
      fi
      ((idx++))
    done

    # user key control
    case `key_input` in
      enter) break;;
      up)    ((selected--));
      if [ $selected -lt 0 ]; then selected=$(($# - 1)); fi;;
      down)  ((selected++));
      if [ $selected -ge $# ]; then selected=0; fi;;
    esac
  done

  # cursor position back to normal
  cursor_to $lastrow
  printf "\n"
  cursor_blink_on

  return $selected
}

function select_opt {
  select_option "$@" 1>&2
  local result=$?
  return $result
}

# Get all current docker containers "name"
lines=()
for i in $(docker ps --format '{{.Names}}') ; do
  lines+=("${i}")
done
lines+=("Quit")

lines_length=${#lines[@]}

# Launch script here passing our array of containers names
select_opt ${lines[*]}
result_index=$?

# if we select last element (= quit)
if [[ "$(( result_index + 1 ))" -eq $lines_length ]];
then
  exit 1
# else we go to selected container
else
  eval "docker exec -it ${lines[$result_index]} bash"
fi
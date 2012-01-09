#!/bin/bash
if [[ -z $1 ]]; then
    echo "Usage: bbf.sh <foo.bf>"
fi
exec 3<>"$1"

# Load
declare -i pc=0
declare -a code
declare -i sp=0
declare -a stack
declare -A linkage
while read -u 3 -d "" -n 1 op; do
    case "$op" in
	"["|"]")
	    if [[ "$op" == "[" ]]; then
		stack[$sp]=$pc
		((sp++))
	    else
	        if [[ $sp -eq 0 ]]; then
		    echo "mismatched ]" >&2
		    exit 1
		fi
		((sp--))
		linkage[$pc]=${stack[$sp]}
		linkage[${stack[$sp]}]=$((pc + 1))
	    fi
	    ;&
	">"|"<"|"+"|"-"|"."|",")
	    code[$pc]="$op"
	    ((pc++))
	    ;;
    esac
done
if [[ $sp -ne 0 ]]; then
    echo "mismatched ["
    exit 1
fi

# Execute
declare -i ptr=0
declare -A tape
pc=0
while [[ $pc -lt ${#code[@]} ]]; do
    case "${code[$pc]}" in
	">")
	    ((ptr++))
	    ;;
	"<")
	    ((ptr--))
	    ;;
	"+")
	    if [[ -z ${tape[$ptr]} ]]; then
		tape[$ptr]=1
	    else
		((tape[$ptr] = (tape[$ptr] + 1) % 256))
	    fi
	    ;;
	"-")
	    if [[ -z ${tape[$ptr]} ]]; then
		tape[$ptr]=255
	    else
		((tape[$ptr] = (tape[$ptr] + 255) % 256))
	    fi
	    ;;
	".")
	    echo -en "\\x$(printf "%02x" ${tape[$ptr]})"
	    ;;
	",")
	    hex=$(dd bs=1 count=1 2>/dev/null | xxd -ps)
	    if [[ -n "$hex" ]]; then
		tape[$ptr]=$((16#$hex))
	    else
		tape[$ptr]=0
	    fi
	    ;;
	"[")
	    if [[ -z ${tape[$ptr]} || ${tape[$ptr]} -eq 0 ]]; then
		pc=${linkage[$pc]}
		continue
	    fi
	    ;;
	"]")
	    if [[ -n ${tape[$ptr]} && ${tape[$ptr]} -ne 0 ]]; then
		pc=${linkage[$pc]}
		continue
	    fi
	    ;;
    esac
    ((pc++))
done

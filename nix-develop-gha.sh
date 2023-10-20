#!/usr/bin/env bash

set -euo pipefail

# Read the arguments into an array, so they can be added correctly as flags
IFS=" " read -r -a arguments <<<"${@:-./#default}"

with_nix_develop() {
	nix develop --ignore-environment "${arguments[@]}" --command "$@"
}

with_nix_develop true # Exit immediately if build fails

contains() {
	grep "$1" --silent <<<"$2"
}

# Add all environment variables except for PATH to GITHUB_ENV.
while IFS='=' read -r -d '' n v; do
	if [ "$n" == "PATH" ]; then
		continue
	fi
	# Skip if the variable is already in the environment with the same
	# value (treating unset and the empty string as identical states)
	if [ "${!n:-}" == "$v" ]; then
		continue
	fi
	if (("$(wc -l <<<"$v")" > 1)); then
		delimiter=$(openssl rand -base64 18)
		if contains "$delimiter" "$v"; then
			echo "Environment variable $n contains randomly generated string $delimiter, file an issue and buy a lottery ticket."
			exit 1
		fi
		printf "%s<<%s\n%s%s\n" "$n" "$delimiter" "$v" "$delimiter" >>"${GITHUB_ENV:-/dev/stderr}"
		continue
	fi
	printf "%s=%s\n" "$n" "$v" >>"${GITHUB_ENV:-/dev/stderr}"
done < <(with_nix_develop env -0)

# Read the nix environment's $PATH into an array
IFS=":" read -r -a nix_path_array <<<"$(with_nix_develop bash -c "echo \$PATH")"

# Iterate over the PATH array in reverse
#
# Why in reverse?  Appending a directory to $GITHUB_PATH causes that directory
# to be _prepended_ to $PATH in subsequent steps, so if we append in
# first-to-last order, the result will be in last-to-first order.  Order in
# PATH elements is significant, since it determines lookup order, thus we
# preserve their order by reversing them before they are reversed again.
for ((i = ${#nix_path_array[@]} - 1; i >= 0; i--)); do
	nix_path_entry="${nix_path_array[$i]}"
	if contains "$nix_path_entry" "$PATH"; then
		continue
	fi
	if ! [ -d "$nix_path_entry" ]; then
		continue
	fi
	echo "$nix_path_entry" >>"${GITHUB_PATH:-/dev/stderr}"
done

#!/usr/bin/env bash

set -euo pipefail

# Read the arguments into an array, so they can be added correctly as flags
IFS=" " read -r -a arguments <<<"${@:-./#default}"

contains() {
	grep "$1" --silent <<<"$2"
}

envOutput=

# Iterate over the output of `env -0`
# On the last loop, exit with the last value read, which will be the exit
# status of `nix develop`.
while IFS='=' read -r -d '' n v || exit "$n"; do
	# If this variable is empty then we're in the first loop, and $n is the
	# output of the shellHook _before_ `env` is run.
	if ! [ "$envOutput" ]; then
		envOutput=1
		if [ "$v" ]; then
			# There was one or more equals signs in the hook output
			printf "%s=%s" "$n" "$v"
		else
			printf "%s" "$n"
		fi
		continue
	fi
	if [ "$n" == "PATH" ]; then
		# Read PATH elements into an array
		IFS=":" read -r -a nix_path_array <<<"$v"
		# Iterate over PATH elements in reverse.
		#
		# Why in reverse?  Appending a directory to $GITHUB_PATH causes
		# that directory to be _prepended_ to $PATH in subsequent
		# steps, so if we append in first-to-last order, the result
		# will be in last-to-first order.  Order in PATH elements is
		# significant, since it determines lookup order, thus we
		# preserve their order by reversing them before they are
		# reversed again.
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
		continue
	fi
	# Skip if the variable is already in the host environment with the same
	# value (treating unset and the empty string as identical states)
	if [ "${!n:-}" == "$v" ]; then
		continue
	fi
	# Otherwise, echo name=value to $GITHUB_ENV
	# Ref https://docs.github.com/en/actions/writing-workflows/choosing-what-your-workflow-does/workflow-commands-for-github-actions#setting-an-environment-variable
	# Use a random string as a heredoc delimiter for multi-line strings
	if (("$(wc -l <<<"$v")" > 1)); then
		delimiter=$(openssl rand -base64 18)
		if contains "$delimiter" "$v"; then
			echo "Environment variable $n contains randomly generated string $delimiter, file an issue and buy a lottery ticket."
			exit 1
		fi
		printf "%s<<%s\n%s%s\n" "$n" "$delimiter" "$v" "$delimiter" >>"${GITHUB_ENV:-/dev/stderr}"
		continue
	fi
	# Add all environment variables except for PATH to GITHUB_ENV.
	printf "%s=%s\n" "$n" "$v" >>"${GITHUB_ENV:-/dev/stderr}"
done < <(
	set +e # Even if the next line fails, run the line after that
	# Run env -0 in the shell environment, prefixed with an extra
	# delimiter to fence off output from the shellHook.
	nix develop "${arguments[@]}" --command bash -c "echo -ne '\0'; env -0"
	printf '%s' "$?" # Print the exit status of the previous line.  This will always be the last value of the while loop
)

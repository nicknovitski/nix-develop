# nix-develop (for GitHub Actions)

This is the most explicit and compatible way I know of to load the environment of a nix flake devShell into a GitHub Actions job.  It works just like other `setup-*` actions: `use` it in a GitHub Actions job, and in all the following steps of that job, `PATH` will include all the dependencies of your project's default devShell, and the environment will include all variables set in that devShell.

## Usage

You can `use` this repository as a GitHub Action...
```yaml
  - uses: nicknovitski/nix-develop@v1
```
...or `run` it as a nix app...
```yaml
  - run: nix run github:nicknovitski/nix-develop/v1
  # This works even on action runners with nothing besides nix installed!
```
...or for the nixiest possible approach, add it to your flake's `inputs`, expose its `packages.default` output as one of your own `packages`, and `nix run` it that way.
```nix
# flake.nix
{
  inputs = {
    nix-develop-gha.url = "github:nicknovitski/nix-develop";
    nix-develop-gha.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { nixpkgs, nix-develop-gha, ... }:
    in {
      packages.x86_64-linux.nix-develop-gha = nix-develop-gha.packages.x86_64-linux.default;
      devShells.default = let
        pkgs = nixpkgs.legacyPackages.x86_64-linux;
      in pkgs.mkShell {
          packages = [
            # your development dependencies
          ];
        };
      };
    });
}
```
```yaml
  - run: nix run .#nix-develop-gha
```

### Arguments

You can pass arbitrary command-line arguments to the underlying [`nix develop`](https://nix.dev/manual/nix/2.18/command-ref/new-cli/nix3-develop) command.

```yaml 
  - uses: nicknovitski/nix-develop@v1
    with:
      arguments: "github:DeterminateSystems/zero-to-nix#multi"
  - run: nix run github:nicknovitski/nix-develop -- github:DeterminateSystems/zero-to-nix#multi
```

## Why?

Why would you load a nix shell environment into a GitHub Actions job?

If you haven't heard of nix, then you don't need this action.  Nix lets you write succint and reliably reproducible cross-platform shell environments, among [many other things](https://zero-to-nix.com/).  This can help you [manage build dependencies very well](https://determinate.systems/posts/nix-github-actions).

If you have heard about nix, and you already have all your builds and tests expressed as derivations, then you don't need this action.  Your GitHub CI workflows are just checking out the code and running `nix-build` or `nix flake check`!  Only keep reading if you're curious.

I made this action for the people who know the value of specifying shell environments in nix and using `nix develop`, and need to run any commands in GitHub actions _besides_ `nix-build` and `nix flake check`.

Those people can now, instead of doing things like [this](https://github.com/DeterminateSystems/nix-github-actions/blob/main/.github/workflows/nix.yml)...
```yaml
      - run: |
          nix develop --command \
            cargo fmt --check
      - run: |
          nix develop --command \
            cargo-deny check
      - run: |
          nix develop --command \
            eclint \
              -exclude "Cargo.lock"
      - run: |
          nix develop --command \
            codespell \
              --skip target,.git \
              --ignore-words-list crate
```
...or even this...
```yaml
      - run: cargo fmt --check
        shell: nix develop --command bash -e {0}
      - run: cargo-deny check
        shell: nix develop --command bash -e {0}
      - run: eclint \
               -exclude "Cargo.lock"
        shell: nix develop --command bash -e {0}
      - run: codespell \
              --skip target,.git \
              --ignore-words-list crate
        shell: nix develop --command bash -e {0}
```
...can instead do this:
```yaml
      - uses: nicknovitski/nix-develop@v1
      - run: cargo fmt --check
      - run: cargo-deny check
      - run: eclint \
               -exclude "Cargo.lock"
      - run: codespell \
              --skip target,.git \
              --ignore-words-list crate
```

Besides just being less repetitive, only the `nix-develop` action makes the devShell environment available in all subsequent steps in the job, **including ones that `use:` third-party actions**.  So the other approaches aren't fully compatible with the GitHub Actions ecosystem.

(That's originally why I wrote this action: I was working on a project which used [yarn](https://yarnpkg.com/) and GitHub Actions, and I wanted to install node and yarn with nix, but then `use` [the `setup-node` action](https://github.com/actions/setup-node) to handle caching of node modules.  For that to work, `setup-node` needed to have `yarn` in `PATH`.)

## How?

How does the action work?

First it runs `nix develop`. Without additional arguments, this evaluates and if necessary builds the `devShells.default` of the flake in the current working directory, or as a fall-back, the `packages.default`.

For each variable in the build environment of the `nix develop` target besides `PATH`, if the same variable is either unset or set to a different value in the step's current environment, the target's variable value is [echo'd to `GITHUB_ENV`, setting that variable for all subsequent steps in the job](https://docs.github.com/en/actions/using-workflows/workflow-commands-for-github-actions#setting-an-environment-variable). 

For each entry in the build environment's `PATH` variable, starting from the _last_ and ending with the _first_, if the entry is not present in the `PATH` of the step's current environment, it is [echo'd to `GITHUB_PATH`, prepending it to the `PATH` variable in all subsequent steps of the job](https://docs.github.com/en/actions/using-workflows/workflow-commands-for-github-actions#adding-a-system-path).

## Contributing

Feel free!  The script can be run locally with any arguments you want to test, and unsurprisingly, running `nix develop` will give you the same dependencies used to test changes in CI.

If you use [direnv](https://direnv.net), you can also bring those dependencies into your own shell with `nix-direnv-reload`.

# Contributing

Thanks for wanting to help with raster rumble. It is an alpha, built by one person who is also learning 6502 assembly,
so small, clear pull requests are the easiest to review.

## Before you start

- Open an issue first for anything bigger than a small fix, so we can agree on it before you spend time on it.
- The game is a Commodore 64 program in ACME assembly. See the README for the tools, `make test` to try it in the browser
  emulator and the project layout.
- Every line of assembly is commented. Please keep it that way, and keep the code in English.

## Pull requests

- Pull requests go to the `dev` branch. Only `dev` is merged into `main`, and that is the maintainer's job:
  every merge to `main` raises the version in `src/version.asm` and publishes a release.
- Keep a pull request to one change, with a clear commit message.
- Check that `make` builds and that the game runs in the emulator.

## License and ownership of your contribution

The project is licensed under CC BY-NC-SA 4.0 (see `LICENSE`), so it is free to play, share and adapt, but not to sell.

By opening a pull request you agree that:

1. You wrote the contribution yourself, or have the right to hand it in.
2. You assign the copyright in your contribution to Dennis Decoene. Where the law does not allow a full assignment, you give
   him an exclusive, worldwide, perpetual, irrevocable and sublicensable license to use it in any way, including commercially.
3. Your contribution is also available to everyone else under CC BY-NC-SA 4.0, like the rest of the project.

The author has no intention of selling the game, but does not want anyone else to sell it either. With every contribution
under one owner, the project stays free to play and adapt, and protected from commercial use.

If you do not agree, please do not open a pull request. You are still free to fork the project and adapt it under the license.

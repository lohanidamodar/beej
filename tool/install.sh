#!/usr/bin/env bash
# Build beej as a standalone binary and put it on PATH.
#
#   ./tool/install.sh
#
# Why a compiled binary rather than `dart pub global activate`:
#
#   * A path activation re-resolves dependencies on *every* invocation and
#     prints "Resolving dependencies..." to **stdout**, which corrupts the
#     output any agent or script is reading.
#   * It starts in ~3s. The AOT binary starts in ~30ms.
#   * The binary is self-contained: templates are embedded, so it works from
#     anywhere with no package directory.
#
# The cost is that it does not track source edits — re-run this after changing
# beej. Templates are re-embedded here, so you cannot ship a stale one.
set -euo pipefail

cd "$(dirname "$0")/.."

BIN_DIR="${BEEJ_BIN_DIR:-$HOME/.local/bin}"
mkdir -p "$BIN_DIR"

echo "==> embedding templates"
dart run tool/embed_templates.dart

echo "==> compiling"
dart compile exe bin/beej.dart -o "$BIN_DIR/beej"

echo "==> installed: $BIN_DIR/beej"
"$BIN_DIR/beej" --version

case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *) echo "note: $BIN_DIR is not on PATH — add it to ~/.zshenv" ;;
esac

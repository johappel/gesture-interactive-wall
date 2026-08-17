# Repository Guidelines

## Project Structure & Module Organization

This repository is currently a clean starting point: no source, test, asset, or build directories are present yet. Keep the top level focused on project-wide configuration and documentation. As implementation begins, use a predictable layout such as `src/` for application code, `tests/` for automated tests, `public/` for static assets, and `docs/` for design or operational notes. Group related modules by feature rather than by file type when a feature becomes substantial.

## Build, Test, and Development Commands

No package manager, build system, or test runner is configured yet. When adding one, document the canonical commands here and in the project README. Prefer reproducible scripts exposed through the chosen package manifest, for example:

```text
npm run dev      # start the local development server
npm test         # run the complete automated test suite
npm run build    # create the production build
```

Do not commit generated build output unless the project’s deployment workflow explicitly requires it.

## Coding Style & Naming Conventions

Use the formatter and linter selected by the project before submitting changes; keep their configuration in the repository. Default to two-space indentation, UTF-8 files, descriptive names, and small single-purpose modules. Use `PascalCase` for components or classes, `camelCase` for functions and variables, and `kebab-case` for feature folders and URL-facing assets. Avoid hidden global state and document non-obvious interaction or gesture behavior.

## Testing Guidelines

Add tests alongside each meaningful feature, using the test runner adopted by the project. Name files after the behavior they cover (for example, `tests/gesture-navigation.test.*`). Include keyboard and pointer fallbacks for gesture-driven interactions where applicable, and verify both success and cancellation/error paths. Run the full suite before opening a pull request; maintain the repository’s configured coverage threshold once one exists.

## Commit & Pull Request Guidelines

No commit history is available in this checkout, so no established message convention can be inferred. Use concise imperative subjects, optionally scoped by area (for example, `Add gesture canvas prototype`), and keep unrelated changes separate. Pull requests should explain the user-visible effect, list validation commands and results, link the relevant issue, and include screenshots or a short recording for visual or interaction changes.

## Security & Configuration Tips

Keep secrets, local credentials, and device-specific configuration out of Git; provide safe `.env.example` files instead. Treat camera, microphone, and gesture input permissions as explicit user-facing concerns, and validate all externally supplied configuration at startup.

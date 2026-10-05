# Development workflow

Use the project's quality gate for every phase:

1. Implement the phase.
2. Run `flutter analyze`.
3. Run `flutter test`.
4. Push to the feature branch.
5. Inspect every required GitHub Actions job individually.
6. If any job fails: diagnose → fix → push → rerun until green.
7. Merge only after all required checks are green.
8. Recheck merged `main` before starting the next phase.

Do not weaken security, remove validation, or degrade UI/performance to make CI green.

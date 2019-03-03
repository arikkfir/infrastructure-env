# Contributing

The following is a set of guidelines for contributing to this project. These are mostly guidelines, not rules. Use your best judgment, and feel free to propose changes to this document in a pull request.

## Code of Conduct

This project and everyone participating in it is governed by the [Code of Conduct](CODE_OF_CONDUCT.md). By participating, you are expected to uphold this code. Please report unacceptable behavior to [arik@kfirs.com](mailto:arik@kfirs.com).

## Continuous Deployment

We're using [Google Cloud Build](https://console.cloud.google.com/cloud-build/builds?project=arikkfir) for delivery of infrastructure, and a new build will be triggered on new commits. There will be a separate environment for each branch, where the `master` branch represents the production environment.

This enables creating feature branches and test infrastructure changes in an isolated way.

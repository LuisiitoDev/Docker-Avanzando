# AZ-400 Lab 03: Runtime container smoke test

## Gap addressed

Design and implement a pipeline testing strategy. This lab adds a runtime gate after unit and integration tests, instead of treating a successful image build as proof that the containerized application works.

## Scenario

The pipeline already compiles the .NET application, executes xUnit tests, collects coverage, and builds the Docker image. The new gate starts the image on the GitHub-hosted runner and verifies the live `/weatherforecast` endpoint.

## Flow

```text
Pull request
    |
    v
Build and xUnit tests
    |
    v
Coverage artifact
    |
    v
Docker image build
    |
    v
Start isolated container
    |
    v
Poll live HTTP endpoint
    |
    +-- valid JSON array of 5 items --> pass
    |
    +-- timeout or invalid response --> logs + fail
    |
    v
Always remove container
```

## Technical corrections to the class example

- `docker run` proves only that the container process started. A useful smoke test must exercise the application behavior through its public interface.
- Checking only that `ejemplo.txt` exists validates a file, not the deployable service.
- A fixed sleep is fragile. The workflow polls readiness for up to 60 seconds.
- Diagnostics must survive failure. The workflow prints container logs when the smoke test fails.
- Cleanup must run even after failure. The final step uses `if: always()`.
- Alpine uses `sh` by default, but the preferred test here runs from the GitHub runner with `curl`; it does not install test tools inside the production image.

## Exercise

1. Open `.github/workflows/az400-pipeline-testing.yml`.
2. Identify the dependency between `test` and `container`.
3. Find the image build and container startup steps.
4. Explain why `ASPNETCORE_ENVIRONMENT=Testing` is passed to this training container.
5. Follow the readiness loop and identify its timeout.
6. Find the JSON assertion performed by `jq`.
7. Locate failure diagnostics and unconditional cleanup.
8. Review the workflow run and confirm that the runtime gate executes only after the test job succeeds.

## Acceptance criteria

- The .NET test job passes.
- The Docker image builds.
- The container starts as a non-root application image.
- The HTTP endpoint responds within 60 seconds.
- The response is a JSON array with five items.
- Container logs are printed on failure.
- The container is removed regardless of outcome.

## Failure experiments

Use a separate learner branch for each experiment.

1. Change the endpoint to `/missing`; expect the readiness step to fail and logs to run.
2. Change the expected JSON length from `5` to `6`; expect the assertion to fail immediately after a successful HTTP response.
3. Remove `needs: test`; explain why jobs may now run in parallel and why that weakens the intended quality-gate sequence.

## Cleanup

The workflow removes the container automatically. Locally:

```bash
docker rm --force rickandmorty-smoke-test 2>/dev/null || true
docker image rm rickandmorty:local 2>/dev/null || true
```

## Review questions

1. Why is building an image not enough to validate runtime behavior?
2. What is the difference between readiness polling and a fixed delay?
3. Why are logs conditional on failure but cleanup unconditional?
4. Which evidence would you preserve for auditability?
5. How would you extend this smoke test for a protected authenticated endpoint?

## Answers

1. A build validates image assembly; it does not prove that the process stays alive or serves correct responses.
2. Polling proceeds as soon as the service is ready and tolerates variable startup time; a fixed delay can be either wasteful or too short.
3. Logs are most valuable for diagnosis after failure, while cleanup must occur for every outcome.
4. Test results, coverage, workflow logs, image metadata, and deployment or environment evidence.
5. Use a short-lived test identity or token stored as an environment-scoped secret, call the endpoint, verify authorization and response, and never print the credential.

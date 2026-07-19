# AZ-400 Lab 05: Progressive delivery gates

## Objective

Design a canary quality gate that uses telemetry to decide whether a release is promoted or rolled back. This lab addresses the AZ-400 build-and-release pipeline gap without requiring Azure credentials.

## Scenario

A new container revision receives 10% of production traffic. The pipeline observes it for a fixed window and evaluates three service-level indicators:

- Availability must be at least 99.9%.
- Error rate must be at most 1%.
- P95 latency must be at most 500 ms.

All signals must pass. One failed signal causes rollback.

## Flow

```text
Build and test image
        |
        v
Deploy candidate revision
        |
        v
Route 10% traffic to canary
        |
        v
Observe availability, errors, and P95 latency
        |
        v
Evaluate all SLO gates
   /                 \
pass                 fail
 |                    |
 v                    v
Promote to 100%     Roll back to stable
        \             /
         v           v
       Preserve decision evidence
```

## Files

- `evaluate_canary.py`: deterministic policy evaluator.
- `scenarios.json`: healthy, degraded, and boundary telemetry.
- `test_evaluate_canary.py`: unit tests for the policy.
- `.github/workflows/az400-progressive-delivery.yml`: PR validation and evidence artifacts.

## Guided implementation

### 1. Predict the decisions

Before running code, decide whether each scenario should promote or roll back. Defend the decision using the three SLOs.

### 2. Run policy tests

```bash
python -m unittest Labs/AZ400-05-Progressive-Delivery-Gates/test_evaluate_canary.py -v
```

### 3. Evaluate a healthy canary

```bash
python Labs/AZ400-05-Progressive-Delivery-Gates/evaluate_canary.py \
  --input Labs/AZ400-05-Progressive-Delivery-Gates/scenarios.json \
  --scenario healthy_canary \
  --expect promote \
  --output reports/healthy_canary.json
```

### 4. Prove rollback behavior

```bash
python Labs/AZ400-05-Progressive-Delivery-Gates/evaluate_canary.py \
  --input Labs/AZ400-05-Progressive-Delivery-Gates/scenarios.json \
  --scenario degraded_canary \
  --expect rollback \
  --output reports/degraded_canary.json
```

### 5. Inspect the workflow

Explain why:

- `canary-gate` depends on `policy-tests`.
- The matrix includes both promote and rollback paths.
- Decision JSON is uploaded with `if: always()`.
- A rollback decision can be an expected successful test outcome.
- The workflow has `contents: read` only.

### 6. Failure experiments

Run each experiment in a learner branch:

1. Change `healthy_canary.error_rate` to `1.1` but leave `--expect promote`.
2. Change the evaluator so only one signal must pass.
3. Remove the boundary test.
4. Add a fourth signal, `cpu_percent`, with a maximum of 80%.

Use the failure output to explain what risk the original gate prevents.

## Acceptance criteria

- [ ] Unit tests pass.
- [ ] Healthy and boundary scenarios produce `promote`.
- [ ] Degraded telemetry produces `rollback`.
- [ ] Any failed signal blocks promotion.
- [ ] The workflow retains a JSON decision artifact for every scenario.
- [ ] The learner can explain where a manual approval should occur.
- [ ] No secret or cloud credential is required.

## Production extension

Replace `scenarios.json` with telemetry queried from Azure Monitor or Application Insights. A real pipeline should:

1. deploy a candidate Container Apps revision,
2. route a small traffic percentage,
3. wait for an observation window,
4. query KQL-backed health signals,
5. evaluate the same policy,
6. move traffic to 100% or restore the stable revision,
7. retain the query, decision, approver, commit, and deployment identifiers.

Do not treat a workflow success state as proof of a healthy release unless the telemetry gate ran against the deployed candidate.

## Common errors

- **Rollback is treated as a failed workflow:** the policy may correctly choose rollback; the workflow should fail only when the observed decision differs from the expected policy behavior.
- **Only one metric is checked:** availability can look healthy while latency or error rate harms users.
- **No observation window:** too few requests produce noisy decisions.
- **Mutable image tag:** use an immutable digest or commit-based tag so rollback identifies the exact stable artifact.
- **No audit evidence:** preserve metrics, thresholds, decision, approver, commit, and deployment revision.
- **Approval after full rollout:** approval belongs before the risky production exposure or before promotion, according to the control model.

## Cleanup

```bash
rm -rf reports
```

The lab creates no cloud resources.

## Review questions

1. Why is canary safer than sending 100% of traffic immediately?
2. What is the difference between a deployment approval and an automated health gate?
3. Why must thresholds be defined before observing the result?
4. Which identifier makes rollback reproducible?
5. When would blue-green be preferable to canary?
6. What evidence would an auditor expect?

## Solution guide

1. Canary limits the blast radius while collecting evidence from real traffic.
2. Approval records human authorization; a health gate evaluates observable release behavior. Strong pipelines can require both.
3. Predefined thresholds reduce decision bias and make the process repeatable.
4. An immutable image digest or release artifact identifier.
5. When instant traffic switching, environment parity, and rapid full rollback matter more than gradual exposure cost.
6. Commit, immutable artifact, test results, deployment revision, traffic split, observation window, telemetry query/results, thresholds, decision, approver, and rollback outcome.

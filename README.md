[![OpenShift](https://img.shields.io/badge/OpenShift-tested%20on%204.20.28-ee0000)](https://docs.redhat.com/en/documentation/openshift_container_platform/4.20)
[![IBM Fusion](https://img.shields.io/badge/IBM%20Fusion-tested%20on%202.12.2-0f62fe)](https://www.ibm.com/docs/en/fusion-software/2.12.0?topic=recipe-dynamic)
[![Db2uInstance](https://img.shields.io/badge/Db2uInstance-tested%20on%2012.1.4-0530ad)](docs/deployment-guide.md#prerequisites)
[![Last commit](https://img.shields.io/github/last-commit/nick-draper/ibm-backup-restore-db2-recipe)](https://github.com/nick-draper/ibm-backup-restore-db2-recipe/commits/main)

# IBM Fusion Backup & Restore Db2uInstance Recipe

A recipe for protecting and restoring a **Db2uInstance** with IBM Fusion Backup & Restore. It is designed for the requirements of real-world deployments:

- Operator and database instance in separate namespaces
- Targeted backups, with an allow-list of resource types
- Dynamic parent/child recipes using Fusion variables
- A dedicated helper pod runs the recipe hooks, so no hook runs in the operator namespace
- Cross-namespace restore with a Transform, `namespaceMapping` and a target display name
- Inverse operations undo maintenance mode and quiesce steps if a later step fails

The diagram below outlines the recipe architecture:

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/images/architecture-dark.svg">
  <img alt="Recipe architecture. The parent recipe db2u-instance-helper-parent wraps the child recipe; it runs helper-exec in the recipe-helper pod, which patches the Db2uInstance and Db2uEngine, and the child execs manage_snapshots in the db2u pod in db2u-instance. Backup and Restore CRs run the parent; a Restore names the Transform, which rewrites the restored objects in db2u-instance-dev. The policy assignment names the application, the parent recipe and the backup policy, which writes to the backup storage location. The storage location and Fusion Velero in ibm-backup-restore both use S3 object storage; on a restore, Velero reads the data back and restores it into db2u-instance-dev." src="docs/images/architecture-light.svg">
</picture>

## Documentation

Read the pages in this order. The [docs index](docs/README.md) also links to every section of each page.

| Page | Read it to |
| --- | --- |
| [How it works](docs/how-it-works.md) | Understand why the recipe exists, how the parent and child run, cross-namespace restore and failure undo |
| [Deployment guide](docs/deployment-guide.md) | Deploy everything, step by step, with a check after each step |
| [Operations](docs/operations.md) | Back up and restore, from the Fusion UI or the CLI, with screenshots |

## Layout

```text
README.md                         overview and links to the docs
LICENSE                           Apache License 2.0
.githooks/                        pre-commit hook that blocks a filled license or key
docs/                             how it works, deployment guide, object storage, operations, diagrams
.env.example                      your values: namespaces, instance, license, storage, env label, helper image, S3
db2u-instance/                    projects, Db2uInstance, operator scope         (template)
ibm-backup-restore/
├── backend-storage-location/     credentials, CA cert, storage location, policy (template)
├── recipe/                       parent and child recipes                       (apply as is)
├── transform/                    restore transform                              (check JSON paths)
├── policy-assignment/            application + policy + parent recipe           (apply as is)
├── operations/                   Backup and Restore CRs                         (template; name per run)
└── config/                       Velero plugin note, not a manifest
recipe-helper/                    project, service account, RBAC, deployment     (set image)
scripts/                          render (.env to build/), placeholder check (pre-commit), discovery
build/                            rendered manifests you apply (git-ignored)
```

## Disclaimer

Provided as is, without warranty, in line with the [IBM/storage-fusion recipes disclaimer](https://github.com/IBM/storage-fusion/tree/master/backup-restore/recipes#disclaimer). Review and test everything in your own environment before you use it in production.

## License

Copyright 2026 Nick Draper. Licensed under the [Apache License 2.0](LICENSE).

The recipe builds on IBM's [`db2u-instance-backup-restore-recipe.yaml`](https://github.com/IBM/storage-fusion/blob/master/backup-restore/recipes/Db2/db2u-instance-backup-restore-recipe.yaml), also Apache 2.0. [How it works](docs/how-it-works.md#what-changed-from-the-sample) lists what changed from it.

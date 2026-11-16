# Documentation

These pages cover the Db2uInstance recipe for IBM Fusion Backup & Restore: what it does, how to deploy it, and how to run backups and restores with it. The [repository README](../README.md) has the overview and the file layout.

## Contents

Read the pages in this order. Each lists its main sections.

1. **[How it works](how-it-works.md)**: why the recipe exists and what each part does.
   - [Why this recipe exists](how-it-works.md#why-this-recipe-exists)
   - [How the recipes run](how-it-works.md#how-the-recipes-run)
   - [Restoring into another namespace](how-it-works.md#restoring-into-another-namespace)
   - [If a backup step fails](how-it-works.md#if-a-backup-step-fails)
   - [Out of scope](how-it-works.md#out-of-scope)
   - [Further reading](how-it-works.md#further-reading)
2. **[Deployment guide](deployment-guide.md)**: the deployment steps, each with a check.
   - [Prerequisites](deployment-guide.md#prerequisites)
   - [What you deploy](deployment-guide.md#what-you-deploy)
   - [Dry runs](deployment-guide.md#dry-runs)
   - [1. Object storage](deployment-guide.md#1-object-storage)
   - [2. Configure your environment](deployment-guide.md#2-configure-your-environment)
   - [3. Projects, Db2 operator and instance](deployment-guide.md#3-projects-db2-operator-and-instance)
   - [4. IBM Fusion Backup & Restore](deployment-guide.md#4-ibm-fusion-backup--restore)
   - [Ready to back up?](deployment-guide.md#ready-to-back-up)
   - [5. Operations](deployment-guide.md#5-operations)
   - [Failures](deployment-guide.md#failures)
   - [File map](deployment-guide.md#file-map)
3. **[Operations](operations.md)**: back up, restore, and what to check afterwards.
   - [Back up](operations.md#back-up)
   - [Restore into another namespace](operations.md#restore-into-another-namespace)
   - [Slow restores and timeouts](operations.md#slow-restores-and-timeouts)

## Other material

| Folder | Contents |
| --- | --- |
| [`images/`](images/) | The figures, in light, dark and adaptive SVG and PNG, named `<page>-<section>-<what>` like the screenshots |
| [`screenshots/`](screenshots/) | Fusion UI and OpenShift console screenshots, named `<page>-<section>-<what>.png` after where they are used |

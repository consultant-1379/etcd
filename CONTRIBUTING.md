# Contributing to the Distributed Coordinator ED Service

This document describes how to contribute artifacts for the
**Distributed Coordinator ED** service.

## Gerrit Project Details

**Distributed Coordinator ED** artifacts are stored in the following Gerrit
Project: [AIA/microservices/etcd](https://gerrit-gamma.gic.ericsson.se/#/admin/projects/AIA/microservices/etcd)

## Artifacts

### Source Artifacts

- [Docker](https://gerrit-gamma.gic.ericsson.se/plugins/gitiles/AIA/microservices/etcd/+/refs/heads/master/Docker/)
- [Helm](https://gerrit-gamma.gic.ericsson.se/plugins/gitiles/AIA/microservices/etcd/+/refs/heads/master/Helm/eric-data-distributed-coordinator-ed)  

### Documents

- *[Distributed Coordinator ED Service User Guide](https://adp.ericsson.se/marketplace/distributed-coordinator-ed/documentation/development/dpi/service-user-guide)*
  - *Format:* markdown
  - *Git Path:* `doc\user-guide\user_guide.md`

To update documents that are not listed, contact the service guardian mentioned
in the file [README.md](http://adp.ericsson.se/marketplace/distributed-coordinator-ed/documentation/development/inner-source/inner-source-readme)

## Contribution Workflow

- The **contributor** updates the artifact in the local repository.
- The **contributor** pushes the update to Gerrit for review.
- The **contributor** invites to the Gerrit review:
  - the **service guardian** (mandatory)
  - and **other relevant parties** (optional)
  - and makes no further changes to the document until it is reviewed.
- The **service guardian** reviews the document and gives a code-review score.
- The code-review scores and corresponding workflow activities are as follows:
  - Score is +1
    - A **reviewer** is happy with the changes but requires another reviewer.
  - Score is +2
    - The **service guardian** accepts the change
    - The **service guardian** ensures publication to Calstore
    - The **service guardian** ensures publication to the ADP marketplace
  - Score is -1 or -2
    - The **service guardian** and the **contributor** need to align the changes

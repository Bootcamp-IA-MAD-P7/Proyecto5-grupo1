# T2c.2 Required Monitored Account Link Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Require every `monitored_persons` row to reference one unique active `MONITORED` account resolved by email, including a consistent demo seed on a fresh PostgreSQL database.

**Architecture:** Java resolves normalized email server-side and stores only the trusted user UUID. Service-level validation produces the specified 404/400/409 errors; PostgreSQL enforces `NOT NULL`, uniqueness and a restrictive foreign key.

**Tech Stack:** Java 21, Spring Boot 3, Spring Data JPA, JUnit 5, Mockito, Flyway, PostgreSQL.

## Global Constraints

- Client sends `monitoredUserEmail`, never `userId`.
- Email resolution is trimmed and case-insensitive.
- Linked account must exist, be active and have role `MONITORED`.
- One `users.id` can appear in at most one `monitored_persons.user_id`.
- Development PostgreSQL is recreated after adding V6; existing orphan data is not migrated.

---

### Task 1: Define and test account-link validation

**Files:**
- Modify: `backend/src/test/java/com/sentilife/monitored/MonitoredServiceTest.java`
- Modify: `backend/src/main/java/com/sentilife/monitored/MonitoredDtos.java`
- Modify: `backend/src/main/java/com/sentilife/monitored/MonitoredService.java`
- Modify: `backend/src/main/java/com/sentilife/monitored/MonitoredPersonRepository.java`
- Modify: `backend/src/main/java/com/sentilife/users/UserRepository.java`

**Interfaces:**
- Consumes: `UserRepository.findByEmailIgnoreCase(String)`
- Produces: `MonitoredRequest(String monitoredUserEmail, ...)`, `existsByUserId(UUID)`, response `userId` and `userEmail`

- [x] Write failing unit tests for successful normalized lookup and 404/400/409 branches.
- [x] Run `cd backend && mvn -Dtest=MonitoredServiceTest test` and verify failures are caused by missing linkage behavior.
- [x] Add the DTO fields and repository queries.
- [x] Resolve the account, validate active/role/uniqueness and assign `person.userId`.
- [x] Re-run focused tests until green.

### Task 2: Enforce the database invariant and seed

**Files:**
- Create: `backend/src/main/resources/db/migration/V6__link_demo_monitored_user.sql`
- Modify: `backend/src/main/java/com/sentilife/monitored/MonitoredPerson.java`

**Interfaces:**
- Produces: `monitored_persons.user_id UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE RESTRICT`

- [x] Create the demo profile by selecting `caregiver@sentilife.com` and `monitored@sentilife.com` from `users`.
- [x] Replace the nullable `ON DELETE SET NULL` foreign key, set `NOT NULL`, and add uniqueness.
- [x] Align JPA with `@Column(name = "user_id", nullable = false, unique = true)`.

### Task 3: Verify from a clean database

**Files:**
- Modify: `.specify/specs/factoria/4_task.md`

**Interfaces:**
- Produces: clean Flyway V1→V6 database and T2c.2 evidence.

- [x] Run focused Java tests and full `mvn test`.
- [x] Recreate only the local PostgreSQL-backed stack using the repository reset target.
- [x] Verify Flyway reaches V6 and SQL confirms one demo link, zero null `user_id`, and unique linkage.
- [x] Mark T2c.2 complete only after all checks pass.

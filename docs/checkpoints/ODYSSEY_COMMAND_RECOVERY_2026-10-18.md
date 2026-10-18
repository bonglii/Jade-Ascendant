# Odyssey command recovery integer correction

Production symptom: event reads and three login dice work, but a recovered command can show Invalid Command. The native request method returns INVALID_COMMAND before network transport when its strict command contract fails.

Reproduced with Godot 4.7.2: fresh JSON.stringify({revision:1}) emits 1; parsing and re-stringifying emits 1.0 (TYPE_FLOAT). Android org.json decodes this as Double; OdysseyContractV1.whole accepts Int/Long only.

Change: validate and canonicalize commands at creation, journal read and native dispatch. Revision and numeric action fields become integer Variants only after finite/integer/range/membership checks. String route choices remain strings. Request ID, event ID, revision and action semantics stay unchanged. Existing valid journals recover automatically; uncertain journals are never deleted or assigned new request IDs by this fix.

Coverage: all 15 action variants, actual isolated journal read and native-call fixture, identical retry wire/ID, malformed fields/types, fixed purchase packs, mission/milestone memberships. No live purchase, deploy or device verification performed here.

Scope: GDScript client only; native contract, AAR, backend, prices, reward rules and account balances unchanged. No Gradle/native rebuild or backend deploy required. A new Play AAB is required to deliver this client correction; export through export_production.cmd and use a new version code.

/**
 * PRE-DEPLOYMENT Gate 4 entrypoint. Not connected to the Godot client.
 * No Firebase project configuration/deployment was created by this pass.
 * When reviewed and deployed later, this exports ONE read-only callable.
 */
import { createRequire } from "node:module";
const require = createRequire(import.meta.url);
const { HttpsError, onCall } = require("firebase-functions/v2/https");
import { createCallableHandlers } from "./src/callable_factory.mjs";

export const { jadeCloudSaveCapabilities } = createCallableHandlers({
  onCall,
  HttpsError,
});
